"""
Product Service - 商品管理微服务

学习要点：
1. RabbitMQ 消息队列集成
2. 事件驱动架构
3. 异步消息消费
4. 分布式追踪在消息队列中的应用
"""
import os
import json
import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Depends
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, Integer, String, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
import pika
import uvicorn

# ==================== OpenTelemetry 配置 ====================
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

resource = Resource.create({
    "service.name": os.getenv("OTEL_SERVICE_NAME", "product-service"),
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

product_service_http_requests_total = get_or_create_counter(
    'product_service_http_requests_total',
    'Total HTTP requests for product service',
    ['method', 'endpoint', 'status']
)

rabbitmq_messages_consumed = get_or_create_counter(
    'rabbitmq_messages_consumed_total',
    'Total RabbitMQ messages consumed',
    ['exchange', 'routing_key']
)

# ==================== 数据库配置 ====================
Base = declarative_base()

class Product(Base):
    """商品模型"""
    __tablename__ = "products"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    description = Column(String)
    price = Column(Float)
    stock = Column(Integer, default=0)

database_url = os.getenv(
    "DATABASE_URL",
    "postgresql://user:password@localhost:5432/products_db"
)

engine = create_engine(database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
SQLAlchemyInstrumentor().instrument(engine=engine)

# ==================== RabbitMQ 配置 ====================
# 为什么使用 RabbitMQ？
# 1. 解耦：服务间异步通信
# 2. 可靠性：消息持久化，不丢失
# 3. 扩展性：可以轻松添加新的消费者
rabbitmq_url = os.getenv(
    "RABBITMQ_URL",
    "amqp://guest:guest@localhost:5672/"
)

connection = None
channel = None

def setup_rabbitmq():
    """初始化 RabbitMQ 连接"""
    global connection, channel
    try:
        # 解析 RabbitMQ URL
        params = pika.URLParameters(rabbitmq_url)
        connection = pika.BlockingConnection(params)
        channel = connection.channel()
        
        # 声明 Exchange（交换机）
        # 为什么使用 fanout exchange？
        # 1. 广播模式：一个消息可以发送给多个消费者
        # 2. 解耦：发送者不需要知道有哪些消费者
        channel.exchange_declare(exchange='order_events', exchange_type='fanout')
        
        # 声明队列
        result = channel.queue_declare(queue='', exclusive=True)
        queue_name = result.method.queue
        
        # 绑定队列到 Exchange
        channel.queue_bind(exchange='order_events', queue=queue_name)
        
        # 设置消费者
        # 为什么使用回调函数？
        # 1. 异步处理：不阻塞主线程
        # 2. 错误处理：可以捕获和处理异常
        channel.basic_consume(
            queue=queue_name,
            on_message_callback=on_order_created,
            auto_ack=False  # 手动确认，确保消息处理完成
        )
        
        print(f"RabbitMQ 消费者已启动，队列: {queue_name}")
        return channel
    except Exception as e:
        print(f"RabbitMQ 连接失败: {e}")
        return None

def on_order_created(ch, method, properties, body):
    """
    处理订单创建事件
    
    学习要点：
    1. 分布式追踪在消息队列中的应用
    2. Trace Context 传播（通过消息头）
    3. 错误处理和重试机制
    """
    # 创建 Span 追踪消息处理
    with tracer.start_as_current_span("process_order_created_event") as span:
        try:
            # 解析消息
            message = json.loads(body.decode())
            span.set_attribute("order.id", message.get("order_id"))
            span.set_attribute("order.product_id", message.get("product_id"))
            span.set_attribute("order.quantity", message.get("quantity"))
            
            # 扣减库存
            db = SessionLocal()
            try:
                product = db.query(Product).filter(Product.id == message["product_id"]).first()
                if product:
                    if product.stock >= message["quantity"]:
                        product.stock -= message["quantity"]
                        db.commit()
                        span.set_attribute("stock.updated", True)
                        span.set_attribute("stock.remaining", product.stock)
                        print(f"库存已扣减: 商品 {product.id}, 剩余 {product.stock}")
                    else:
                        span.set_attribute("error", True)
                        span.set_attribute("error.type", "InsufficientStock")
                        print(f"库存不足: 商品 {product.id}, 需要 {message['quantity']}, 现有 {product.stock}")
                else:
                    span.set_attribute("error", True)
                    span.set_attribute("error.type", "ProductNotFound")
                    print(f"商品不存在: {message['product_id']}")
            finally:
                db.close()
            
            # 记录指标
            rabbitmq_messages_consumed.labels(
                exchange='order_events',
                routing_key='order.created'
            ).inc()
            
            # 手动确认消息
            # 为什么手动确认？
            # 1. 确保消息处理完成
            # 2. 如果处理失败，消息会重新入队
            ch.basic_ack(delivery_tag=method.delivery_tag)
            
        except Exception as e:
            # 记录错误
            span.record_exception(e)
            span.set_attribute("error", True)
            print(f"处理消息失败: {e}")
            # 拒绝消息并重新入队
            ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

# ==================== FastAPI 应用 ====================
@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时创建表和 RabbitMQ 连接
    Base.metadata.create_all(bind=engine)
    setup_rabbitmq()
    
    # 在后台线程中运行 RabbitMQ 消费者
    # 为什么使用线程？
    # pika 是同步库，需要在独立线程中运行
    import threading
    def consume_messages():
        if channel:
            channel.start_consuming()
    
    consumer_thread = threading.Thread(target=consume_messages, daemon=True)
    consumer_thread.start()
    
    yield
    
    # 关闭 RabbitMQ 连接
    if connection and not connection.is_closed:
        connection.close()

app = FastAPI(
    title="Product Service",
    description="商品管理微服务",
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

# ==================== Pydantic 模型 ====================
class ProductCreate(BaseModel):
    """创建商品的请求模型"""
    name: str
    description: str
    price: float
    stock: int

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "product-service"}

@app.get("/metrics")
async def metrics():
    return Response(content=generate_latest(REGISTRY), media_type="text/plain")

@app.post("/api/products/")
async def create_product(product_data: ProductCreate, db: Session = Depends(get_db)):
    """创建商品"""
    with tracer.start_as_current_span("create_product") as span:
        span.set_attribute("product.name", product_data.name)
        span.set_attribute("product.price", product_data.price)
        
        try:
            product = Product(name=product_data.name, description=product_data.description, price=product_data.price, stock=product_data.stock)
            db.add(product)
            db.commit()
            db.refresh(product)
            
            product_service_http_requests_total.labels(method="POST", endpoint="/api/products/", status="200").inc()
            return {"id": product.id, "name": product.name, "price": product.price, "stock": product.stock}
        except Exception as e:
            span.record_exception(e)
            span.set_attribute("error", True)
            product_service_http_requests_total.labels(method="POST", endpoint="/api/products/", status="500").inc()
            raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/products/{product_id}")
async def get_product(product_id: int, db: Session = Depends(get_db)):
    """获取商品信息"""
    with tracer.start_as_current_span("get_product") as span:
        span.set_attribute("product.id", product_id)
        
        product = db.query(Product).filter(Product.id == product_id).first()
        if not product:
            span.set_attribute("error", True)
            product_service_http_requests_total.labels(method="GET", endpoint="/api/products/{product_id}", status="404").inc()
            raise HTTPException(status_code=404, detail="Product not found")
        
        product_service_http_requests_total.labels(method="GET", endpoint="/api/products/{product_id}", status="200").inc()
        return {"id": product.id, "name": product.name, "price": product.price, "stock": product.stock}

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8002))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)

