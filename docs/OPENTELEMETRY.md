# OpenTelemetry 集成指南

## 概述

本项目已配置 OpenTelemetry 用于分布式追踪。所有微服务都配置了 OpenTelemetry SDK，可以将追踪数据发送到 Jaeger。

## 配置说明

### 环境变量

每个微服务都配置了以下 OpenTelemetry 环境变量：

```yaml
env:
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "http://jaeger-collector.observability.svc.cluster.local:4317"
- name: OTEL_SERVICE_NAME
  value: "user-service"  # 或 product-service, order-service
- name: OTEL_RESOURCE_ATTRIBUTES
  value: "service.name=user-service,service.namespace=microservices"
```

### 在微服务代码中集成 OpenTelemetry

#### Python (FastAPI) 示例

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
import os

# 配置资源
resource = Resource.create({
    "service.name": os.getenv("OTEL_SERVICE_NAME", "unknown-service"),
    "service.namespace": os.getenv("OTEL_RESOURCE_ATTRIBUTES", "").split("service.namespace=")[-1] if "service.namespace=" in os.getenv("OTEL_RESOURCE_ATTRIBUTES", "") else "default"
})

# 创建 TracerProvider
trace.set_tracer_provider(TracerProvider(resource=resource))

# 配置 OTLP Exporter
otlp_exporter = OTLPSpanExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317"),
    insecure=True
)

# 添加 Span Processor
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# 自动检测 FastAPI
FastAPIInstrumentor.instrument_app(app)

# 自动检测 HTTP 客户端
HTTPXClientInstrumentor.instrument()

# 自动检测 SQLAlchemy
SQLAlchemyInstrumentor().instrument(engine=engine)
```

#### 安装依赖

```bash
pip install opentelemetry-api opentelemetry-sdk \
    opentelemetry-exporter-otlp-proto-grpc \
    opentelemetry-instrumentation-fastapi \
    opentelemetry-instrumentation-httpx \
    opentelemetry-instrumentation-sqlalchemy
```

## 验证追踪

### 1. 检查 Jaeger 是否运行

```bash
kubectl get pods -n observability | grep jaeger
```

### 2. 端口转发 Jaeger UI

```bash
kubectl port-forward -n observability svc/jaeger-query 16686:16686
```

### 3. 访问 Jaeger UI

打开浏览器访问: http://localhost:16686

### 4. 生成追踪数据

发送一些请求到微服务：

```bash
# 创建用户
curl -X POST http://localhost:8001/api/users \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "name": "Test User", "password": "123456"}'

# 创建商品
curl -X POST http://localhost:8002/api/products/ \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Product", "description": "Test", "price": 99.99, "stock": 100}'

# 创建订单
curl -X POST http://localhost:8003/api/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "product_id": 1, "quantity": 2}'
```

### 5. 在 Jaeger 中查看追踪

1. 打开 Jaeger UI (http://localhost:16686)
2. 选择服务（如 `order-service`）
3. 点击 "Find Traces"
4. 你应该能看到完整的调用链，包括：
   - order-service 调用 user-service
   - order-service 调用 product-service
   - order-service 发布 RabbitMQ 事件
   - product-service 消费 RabbitMQ 事件

## 追踪数据流

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTP Request
       ▼
┌─────────────────┐     ┌──────────────────┐
│  order-service  │────▶│  user-service    │
│  (TraceID: abc) │     │  (TraceID: abc)  │
└────────┬────────┘     └──────────────────┘
         │
         │ HTTP Request
         ▼
┌─────────────────┐
│ product-service │
│  (TraceID: abc) │
└────────┬────────┘
         │
         │ RabbitMQ Event
         ▼
┌─────────────────┐
│ product-service │
│  (Consumer)     │
│  (TraceID: abc) │
└─────────────────┘
         │
         │ OTLP/gRPC
         ▼
┌─────────────────┐
│ Jaeger Collector│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Jaeger Query   │
│  (UI: 16686)    │
└─────────────────┘
```

## 故障排查

### 问题：追踪数据没有出现在 Jaeger

1. **检查环境变量**
   ```bash
   kubectl exec -n microservices <pod-name> -- env | grep OTEL
   ```

2. **检查 Jaeger Collector 日志**
   ```bash
   kubectl logs -n observability -l app.kubernetes.io/name=jaeger
   ```

3. **检查网络连接**
   ```bash
   kubectl exec -n microservices <pod-name> -- \
     curl -v http://jaeger-collector.observability.svc.cluster.local:4317
   ```

4. **检查微服务日志**
   ```bash
   kubectl logs -n microservices <pod-name> | grep -i otel
   ```

### 问题：追踪数据不完整

确保所有服务都配置了 OpenTelemetry：
- 检查 Deployment 中的环境变量
- 确认代码中正确初始化了 OpenTelemetry SDK
- 验证自动检测器已正确安装

## 高级配置

### 采样率配置

在微服务代码中添加采样配置：

```python
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased

# 50% 采样率
sampler = TraceIdRatioBased(0.5)
trace.set_tracer_provider(TracerProvider(sampler=sampler))
```

### 自定义属性

在代码中添加自定义属性：

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("custom-operation") as span:
    span.set_attribute("custom.key", "custom.value")
    # 你的业务逻辑
```

## 参考资源

- [OpenTelemetry Python Documentation](https://opentelemetry-python.readthedocs.io/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [OpenTelemetry Best Practices](https://opentelemetry.io/docs/specs/otel/)





