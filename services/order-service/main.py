"""
Order Service - 订单管理微服务

学习要点：
1. 服务间 HTTP 调用
2. 事件发布（RabbitMQ）
3. 分布式事务处理
4. 容错和重试机制
"""
import os
import json
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Depends
from fastapi.responses import Response
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.sql import func
import pika
import httpx
from tenacity import retry, stop_after_attempt, wait_exponential
import uvicorn

# ==================== OpenTelemetry 配置 ====================
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

resource = Resource.create({
    "service.name": os.getenv("OTEL_SERVICE_NAME", "order-service"),
    "service.namespace": os.getenv("OTEL_RESOURCE_ATTRIBUTES", "").split("service.namespace=")[-1] 
                         if "service.namespace=" in os.getenv("OTEL_RESOURCE_ATTRIBUTES", "") 
                         else "default"
})

trace.set_tracer_provider(TracerProvider(resource=resource))
otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")
otlp_exporter = OTLPSpanExporter(endpoint=otlp_endpoint, insecure=True)
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)
tracer = trace.get_tracer(__name__)

# ==================== Prometheus 指标 ====================
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY

# 使用 try-except 避免重复注册
def get_or_create_counter(name, description, labels):
    try:
        for collector in list(REGISTRY._collector_to_names.keys()):
            if hasattr(collector, '_name') and collector._name == name:
                return collector
        return Counter(name, description, labels)
    except (ValueError, AttributeError):
        try:
            return Counter(name, description, labels)
        except ValueError:
            return None

order_service_http_requests_total = get_or_create_counter(
    'order_service_http_requests_total',
    'Total HTTP requests for order service',
    ['method', 'endpoint', 'status']
)

service_calls_total = get_or_create_counter(
    'service_calls_total',
    'Total service-to-service calls',
    ['target_service', 'status']
)

rabbitmq_messages_published = get_or_create_counter(
    'rabbitmq_messages_published_total',
    'Total RabbitMQ messages published',
    ['exchange', 'routing_key']
)

# ==================== 数据库配置 ====================
Base = declarative_base()

class Order(Base):
    """订单模型"""
    __tablename__ = "orders"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    product_id = Column(Integer, index=True)
    quantity = Column(Integer)
    status = Column(String, default="pending")
    created_at = Column(DateTime, server_default=func.now())

database_url = os.getenv(
    "DATABASE_URL",
    "postgresql://user:password@localhost:5432/orders_db"
)

engine = create_engine(database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
SQLAlchemyInstrumentor().instrument(engine=engine)

# ==================== 服务间调用配置 ====================
# 为什么从环境变量读取服务 URL？
# 1. Kubernetes Service Discovery: 使用 DNS 名称
# 2. 环境隔离: 不同环境使用不同地址
# 3. 配置管理: 通过 ConfigMap 注入
user_service_url = os.getenv("USER_SERVICE_URL", "http://localhost:8001")
product_service_url = os.getenv("PRODUCT_SERVICE_URL", "http://localhost:8002")

# 创建 HTTP 客户端
# 为什么使用 httpx？
# 1. 异步支持: 提高并发性能
# 2. HTTP/2 支持: 更高效的协议
# 3. 自动追踪: OpenTelemetry 可以自动追踪
http_client = httpx.Client(timeout=5.0)  # 5秒超时
HTTPXClientInstrumentor.instrument_client(http_client)

# ==================== RabbitMQ 配置 ====================
rabbitmq_url = os.getenv(
    "RABBITMQ_URL",
    "amqp://guest:guest@localhost:5672/"
)

def get_rabbitmq_channel():
    """获取 RabbitMQ Channel"""
    params = pika.URLParameters(rabbitmq_url)
    connection = pika.BlockingConnection(params)
    channel = connection.channel()
    channel.exchange_declare(exchange='order_events', exchange_type='fanout')
    return channel, connection

# ==================== 服务间调用函数 ====================
@retry(
    stop=stop_after_attempt(3),  # 最多重试3次
    wait=wait_exponential(multiplier=1, min=2, max=10)  # 指数退避：2s, 4s, 8s
)
def call_user_service(user_id: int):
    """
    调用用户服务验证用户存在
    
    为什么需要重试？
    1. 网络抖动: 临时网络问题
    2. 服务重启: 服务可能正在重启
    3. 提高可用性: 减少因临时故障导致的失败
    """
    with tracer.start_as_current_span("call_user_service") as span:
        span.set_attribute("user.id", user_id)
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.url", f"{user_service_url}/api/users/{user_id}")
        
        try:
            response = http_client.get(f"{user_service_url}/api/users/{user_id}")
            span.set_attribute("http.status_code", response.status_code)
            
            if response.status_code == 200:
                service_calls_total.labels(target_service="user-service", status="200").inc()
                return response.json()
            elif response.status_code == 404:
                span.set_attribute("error", True)
                span.set_attribute("error.type", "UserNotFound")
                service_calls_total.labels(target_service="user-service", status="404").inc()
                raise HTTPException(status_code=404, detail="User not found")
            else:
                span.set_attribute("error", True)
                service_calls_total.labels(target_service="user-service", status=str(response.status_code)).inc()
                raise HTTPException(status_code=500, detail="User service error")
        except httpx.TimeoutException:
            span.set_attribute("error", True)
            span.set_attribute("error.type", "Timeout")
            service_calls_total.labels(target_service="user-service", status="timeout").inc()
            raise HTTPException(status_code=504, detail="User service timeout")
        except Exception as e:
            span.record_exception(e)
            span.set_attribute("error", True)
            service_calls_total.labels(target_service="user-service", status="error").inc()
            raise

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=10)
)
def call_product_service(product_id: int, quantity: int):
    """调用商品服务验证库存"""
    with tracer.start_as_current_span("call_product_service") as span:
        span.set_attribute("product.id", product_id)
        span.set_attribute("product.quantity", quantity)
        
        try:
            # 先获取商品信息
            response = http_client.get(f"{product_service_url}/api/products/{product_id}")
            span.set_attribute("http.status_code", response.status_code)
            
            if response.status_code == 200:
                product = response.json()
                if product["stock"] >= quantity:
                    service_calls_total.labels(target_service="product-service", status="200").inc()
                    return product
                else:
                    span.set_attribute("error", True)
                    span.set_attribute("error.type", "InsufficientStock")
                    service_calls_total.labels(target_service="product-service", status="400").inc()
                    raise HTTPException(status_code=400, detail="Insufficient stock")
            elif response.status_code == 404:
                span.set_attribute("error", True)
                span.set_attribute("error.type", "ProductNotFound")
                service_calls_total.labels(target_service="product-service", status="404").inc()
                raise HTTPException(status_code=404, detail="Product not found")
            else:
                span.set_attribute("error", True)
                service_calls_total.labels(target_service="product-service", status=str(response.status_code)).inc()
                raise HTTPException(status_code=500, detail="Product service error")
        except httpx.TimeoutException:
            span.set_attribute("error", True)
            span.set_attribute("error.type", "Timeout")
            service_calls_total.labels(target_service="product-service", status="timeout").inc()
            raise HTTPException(status_code=504, detail="Product service timeout")
        except HTTPException:
            raise
        except Exception as e:
            span.record_exception(e)
            span.set_attribute("error", True)
            service_calls_total.labels(target_service="product-service", status="error").inc()
            raise

def publish_order_created_event(order_id: int, product_id: int, quantity: int):
    """
    发布订单创建事件
    
    为什么使用事件驱动？
    1. 解耦: 订单服务不需要等待库存扣减完成
    2. 最终一致性: 即使商品服务暂时不可用，订单已创建
    3. 可扩展: 可以轻松添加其他消费者（如通知服务、统计服务）
    """
    with tracer.start_as_current_span("publish_order_created_event") as span:
        span.set_attribute("order.id", order_id)
        span.set_attribute("product.id", product_id)
        span.set_attribute("quantity", quantity)
        
        try:
            channel, connection = get_rabbitmq_channel()
            
            message = {
                "order_id": order_id,
                "product_id": product_id,
                "quantity": quantity,
                "event_type": "order.created"
            }
            
            # 发布消息到 Exchange
            channel.basic_publish(
                exchange='order_events',
                routing_key='',  # fanout exchange 不需要 routing_key
                body=json.dumps(message),
                properties=pika.BasicProperties(
                    delivery_mode=2,  # 消息持久化
                )
            )
            
            connection.close()
            
            rabbitmq_messages_published.labels(
                exchange='order_events',
                routing_key='order.created'
            ).inc()
            
            span.set_attribute("message.published", True)
            print(f"订单创建事件已发布: {message}")
            
        except Exception as e:
            span.record_exception(e)
            span.set_attribute("error", True)
            print(f"发布事件失败: {e}")

# ==================== FastAPI 应用 ====================
@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield
    http_client.close()

app = FastAPI(
    title="Order Service",
    description="订单管理微服务",
    version="1.0.0",
    lifespan=lifespan
)

FastAPIInstrumentor.instrument_app(app)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "order-service"}

@app.get("/metrics")
async def metrics():
    return Response(content=generate_latest(REGISTRY), media_type="text/plain")

# ==================== Pydantic 模型 ====================
class OrderCreate(BaseModel):
    """创建订单的请求模型"""
    user_id: int
    product_id: int
    quantity: int

@app.post("/api/orders")
async def create_order(order_data: OrderCreate, db: Session = Depends(get_db)):
    """
    创建订单
    
    学习要点：
    1. 分布式事务处理（Saga 模式）
    2. 服务间调用和容错
    3. 事件发布
    4. 完整的追踪链路
    """
    with tracer.start_as_current_span("create_order") as span:
        span.set_attribute("order.user_id", order_data.user_id)
        span.set_attribute("order.product_id", order_data.product_id)
        span.set_attribute("order.quantity", order_data.quantity)
        
        try:
            # 步骤 1: 验证用户存在
            # 为什么先验证用户？
            # 1. 快速失败: 如果用户不存在，立即返回错误
            # 2. 减少资源浪费: 不创建无效订单
            user = call_user_service(order_data.user_id)
            span.set_attribute("user.verified", True)
            
            # 步骤 2: 验证商品和库存
            product = call_product_service(order_data.product_id, order_data.quantity)
            span.set_attribute("product.verified", True)
            
            # 步骤 3: 创建订单（本地事务）
            # 为什么先创建订单再发布事件？
            # 1. 保证订单已创建: 即使后续步骤失败，订单也已存在
            # 2. 最终一致性: 库存稍后扣减，但订单已创建
            order = Order(user_id=order_data.user_id, product_id=order_data.product_id, quantity=order_data.quantity, status="created")
            db.add(order)
            db.commit()
            db.refresh(order)
            
            span.set_attribute("order.id", order.id)
            span.set_attribute("order.created", True)
            
            # 步骤 4: 发布订单创建事件
            # 为什么异步发布事件？
            # 1. 提高响应速度: 不需要等待库存扣减完成
            # 2. 解耦: 订单服务和商品服务解耦
            publish_order_created_event(order.id, order_data.product_id, order_data.quantity)
            
            order_service_http_requests_total.labels(method="POST", endpoint="/api/orders", status="200").inc()
            
            return {
                "id": order.id,
                "user_id": order.user_id,
                "product_id": order.product_id,
                "quantity": order.quantity,
                "status": order.status
            }
            
        except HTTPException:
            raise
        except Exception as e:
            span.record_exception(e)
            span.set_attribute("error", True)
            db.rollback()
            order_service_http_requests_total.labels(method="POST", endpoint="/api/orders", status="500").inc()
            raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/orders/{order_id}")
async def get_order(order_id: int, db: Session = Depends(get_db)):
    """获取订单信息"""
    with tracer.start_as_current_span("get_order") as span:
        span.set_attribute("order.id", order_id)
        
        order = db.query(Order).filter(Order.id == order_id).first()
        if not order:
            span.set_attribute("error", True)
            order_service_http_requests_total.labels(method="GET", endpoint="/api/orders/{order_id}", status="404").inc()
            raise HTTPException(status_code=404, detail="Order not found")
        
        order_service_http_requests_total.labels(method="GET", endpoint="/api/orders/{order_id}", status="200").inc()
        return {
            "id": order.id,
            "user_id": order.user_id,
            "product_id": order.product_id,
            "quantity": order.quantity,
            "status": order.status
        }

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8003))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)

