"""
User Service - 用户管理微服务

学习要点：
1. FastAPI 异步 Web 框架的使用
2. OpenTelemetry 分布式追踪集成
3. Prometheus 指标暴露
4. 健康检查端点
5. 数据库连接池管理
"""
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Depends
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
import uvicorn

# ==================== OpenTelemetry 配置 ====================
# 为什么需要 OpenTelemetry？
# 1. 分布式追踪：在微服务架构中，一个请求可能经过多个服务
# 2. 性能分析：识别慢请求和瓶颈服务
# 3. 故障排查：快速定位问题所在的服务
# 4. 服务依赖图：自动生成服务拓扑关系
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

# 配置 OpenTelemetry 资源
# Resource 用于标识服务，包含服务名、命名空间等信息
resource = Resource.create({
    "service.name": os.getenv("OTEL_SERVICE_NAME", "user-service"),
    "service.namespace": os.getenv("OTEL_RESOURCE_ATTRIBUTES", "").split("service.namespace=")[-1] 
                         if "service.namespace=" in os.getenv("OTEL_RESOURCE_ATTRIBUTES", "") 
                         else "default"
})

# 创建 TracerProvider（追踪提供者）
# 这是 OpenTelemetry 的核心组件，负责创建和管理 Span
trace.set_tracer_provider(TracerProvider(resource=resource))

# 配置 OTLP Exporter（OpenTelemetry Protocol Exporter）
# OTLP 是 OpenTelemetry 的标准协议，用于将追踪数据发送到后端（如 Jaeger）
otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")
otlp_exporter = OTLPSpanExporter(
    endpoint=otlp_endpoint,
    insecure=True  # 学习环境使用，生产环境应使用 TLS
)

# BatchSpanProcessor 批量处理 Span，提高性能
# 为什么批量处理？减少网络请求，提高吞吐量
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# 获取 Tracer（追踪器），用于创建 Span
tracer = trace.get_tracer(__name__)

# ==================== Prometheus 指标配置 ====================
# 为什么需要 Prometheus 指标？
# 1. 监控服务健康度：QPS、延迟、错误率
# 2. 容量规划：识别资源瓶颈
# 3. 告警：基于指标触发告警
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY
from fastapi.responses import Response

# 定义指标
# Counter: 累计计数器，用于统计请求总数、错误总数等
# 为什么使用 user_service_http_requests_total？
# 避免与其他服务的指标名称冲突，每个服务使用自己的前缀
# 使用 try-except 避免重复注册（如果代码被重新加载）
def get_or_create_counter(name, description, labels):
    """安全地获取或创建 Counter 指标"""
    # 检查是否已注册（通过尝试获取）
    try:
        # 如果已注册，尝试获取会失败，但我们可以捕获异常
        existing = REGISTRY._names_to_collectors.get(name)
        if existing:
            return existing
    except (AttributeError, KeyError):
        pass
    
    # 如果不存在，尝试创建新指标
    try:
        return Counter(name, description, labels)
    except ValueError:
        # 如果创建失败（重复注册），从注册表获取
        existing = REGISTRY._names_to_collectors.get(name)
        if existing:
            return existing
        # 如果还是找不到，说明有问题，抛出异常
        raise RuntimeError(f"Failed to get or create counter: {name}")

def get_or_create_histogram(name, description, labels):
    """安全地获取或创建 Histogram 指标"""
    # 检查是否已注册（通过尝试获取）
    try:
        # 如果已注册，尝试获取会失败，但我们可以捕获异常
        existing = REGISTRY._names_to_collectors.get(name)
        if existing:
            return existing
    except (AttributeError, KeyError):
        pass
    
    # 如果不存在，尝试创建新指标
    try:
        return Histogram(name, description, labels)
    except ValueError:
        # 如果创建失败（重复注册），从注册表获取
        existing = REGISTRY._names_to_collectors.get(name)
        if existing:
            return existing
        # 如果还是找不到，说明有问题，抛出异常
        raise RuntimeError(f"Failed to get or create histogram: {name}")

# 使用全局变量存储指标，避免重复注册
_user_service_http_requests_total = None
_user_service_http_request_duration_seconds = None

def get_user_service_http_requests_total():
    """获取或创建 user_service_http_requests_total 指标"""
    global _user_service_http_requests_total
    if _user_service_http_requests_total is None:
        _user_service_http_requests_total = get_or_create_counter(
            'user_service_http_requests_total',
            'Total HTTP requests for user service',
            ['method', 'endpoint', 'status']
        )
    return _user_service_http_requests_total

def get_user_service_http_request_duration_seconds():
    """获取或创建 user_service_http_request_duration_seconds 指标"""
    global _user_service_http_request_duration_seconds
    if _user_service_http_request_duration_seconds is None:
        _user_service_http_request_duration_seconds = get_or_create_histogram(
            'user_service_http_request_duration_seconds',
            'HTTP request duration in seconds for user service',
            ['method', 'endpoint']
        )
    return _user_service_http_request_duration_seconds

# 初始化指标
user_service_http_requests_total = get_user_service_http_requests_total()
user_service_http_request_duration_seconds = get_user_service_http_request_duration_seconds()

# ==================== 数据库配置 ====================
# 为什么使用 SQLAlchemy？
# 1. ORM（对象关系映射）：简化数据库操作
# 2. 连接池管理：自动管理数据库连接
# 3. 跨数据库支持：可以轻松切换数据库类型
Base = declarative_base()

class User(Base):
    """用户模型"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String)
    password = Column(String)  # 生产环境应使用哈希

# 数据库连接
# 为什么从环境变量读取？
# 1. 配置与代码分离：不同环境使用不同配置
# 2. 安全性：敏感信息不硬编码
# 3. 灵活性：Kubernetes 可以通过 ConfigMap/Secret 注入
database_url = os.getenv(
    "DATABASE_URL",
    "postgresql://user:password@localhost:5432/users_db"
)

engine = create_engine(database_url, pool_pre_ping=True)
# pool_pre_ping=True: 连接前检查连接是否有效，避免使用已断开的连接

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 自动检测 SQLAlchemy，自动追踪数据库查询
SQLAlchemyInstrumentor().instrument(engine=engine)

# ==================== FastAPI 应用 ====================
@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时创建表（仅用于学习，生产环境应使用迁移工具）
    Base.metadata.create_all(bind=engine)
    yield
    # 关闭时清理资源

app = FastAPI(
    title="User Service",
    description="用户管理微服务",
    version="1.0.0",
    lifespan=lifespan
)

# 自动检测 FastAPI，自动追踪 HTTP 请求
FastAPIInstrumentor.instrument_app(app)

# ==================== Pydantic 模型 ====================
# 为什么使用 Pydantic 模型？
# 1. 数据验证：自动验证请求体数据格式
# 2. 类型安全：提供类型提示和自动文档生成
# 3. 序列化：自动处理 JSON 序列化/反序列化
class UserCreate(BaseModel):
    """创建用户的请求模型"""
    email: str
    name: str
    password: str

# ==================== 依赖注入 ====================
# 为什么使用依赖注入？
# 1. 代码复用：数据库会话可以在多个路由中复用
# 2. 测试友好：可以轻松 mock 依赖
# 3. 资源管理：自动管理资源生命周期
def get_db():
    """获取数据库会话"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ==================== 路由定义 ====================
@app.get("/health")
async def health_check():
    """
    健康检查端点
    
    为什么需要健康检查？
    1. Kubernetes Liveness Probe: 检测容器是否存活
    2. Kubernetes Readiness Probe: 检测容器是否就绪
    3. 负载均衡器: 判断服务是否可用
    """
    return {"status": "healthy", "service": "user-service"}

@app.get("/metrics")
async def metrics():
    """
    Prometheus 指标端点
    
    为什么暴露 /metrics？
    1. Prometheus 定期抓取指标
    2. ServiceMonitor 自动发现
    3. 统一指标格式
    """
    return Response(content=generate_latest(REGISTRY), media_type="text/plain")

@app.post("/api/users")
async def create_user(user_data: UserCreate, db: Session = Depends(get_db)):
    """
    创建用户
    
    学习要点：
    1. 使用 Pydantic 模型接收请求体数据
    2. 使用 Tracer 创建自定义 Span
    3. 添加 Span 属性（attributes）
    4. 错误处理：捕获异常并记录到追踪中
    """
    # 创建自定义 Span，用于追踪业务逻辑
    with tracer.start_as_current_span("create_user") as span:
        # 添加 Span 属性，便于查询和过滤
        span.set_attribute("user.email", user_data.email)
        span.set_attribute("user.name", user_data.name)
        
        try:
            # 检查用户是否已存在
            existing_user = db.query(User).filter(User.email == user_data.email).first()
            if existing_user:
                span.set_attribute("error", True)
                span.set_attribute("error.type", "UserAlreadyExists")
                raise HTTPException(status_code=400, detail="User already exists")
            
            # 创建新用户
            user = User(email=user_data.email, name=user_data.name, password=user_data.password)
            db.add(user)
            db.commit()
            db.refresh(user)
            
            # 记录成功指标
            user_service_http_requests_total.labels(method="POST", endpoint="/api/users", status="200").inc()
            
            span.set_attribute("user.id", user.id)
            return {"id": user.id, "email": user.email, "name": user.name}
            
        except HTTPException:
            raise
        except Exception as e:
            # 记录错误到 Span
            span.record_exception(e)
            span.set_attribute("error", True)
            user_service_http_requests_total.labels(method="POST", endpoint="/api/users", status="500").inc()
            raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/users/{user_id}")
async def get_user(user_id: int, db: Session = Depends(get_db)):
    """获取用户信息"""
    with tracer.start_as_current_span("get_user") as span:
        span.set_attribute("user.id", user_id)
        
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            span.set_attribute("error", True)
            span.set_attribute("error.type", "UserNotFound")
            user_service_http_requests_total.labels(method="GET", endpoint="/api/users/{user_id}", status="404").inc()
            raise HTTPException(status_code=404, detail="User not found")
        
        user_service_http_requests_total.labels(method="GET", endpoint="/api/users/{user_id}", status="200").inc()
        return {"id": user.id, "email": user.email, "name": user.name}

if __name__ == "__main__":
    # 为什么使用 uvicorn？
    # 1. ASGI 服务器：支持异步请求
    # 2. 高性能：基于 uvloop
    # 3. 生产级特性：自动重载、日志等
    port = int(os.getenv("PORT", 8001))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",  # 监听所有网络接口，Kubernetes 需要
        port=port,
        reload=False  # 生产环境关闭自动重载
    )

