# 构建和部署指南

## 📋 概述

本文档详细说明如何构建 Docker 镜像、集成 OpenTelemetry 并部署到 Kubernetes。

## 🎯 学习目标

通过这个项目，你将学习到：

1. **Docker 镜像构建**
   - 多阶段构建优化镜像大小
   - 健康检查配置
   - 最佳实践

2. **OpenTelemetry 集成**
   - 分布式追踪配置
   - 自动检测（Auto-instrumentation）
   - 自定义 Span 和属性

3. **Kubernetes 部署**
   - Helm Chart 使用
   - 服务发现
   - 自动扩缩容

## 🐳 构建 Docker 镜像

### 为什么需要构建镜像？

1. **容器化应用**: Kubernetes 需要容器镜像来运行应用
2. **环境一致性**: 确保开发、测试、生产环境一致
3. **可移植性**: 可以在任何支持 Docker 的环境运行

### 构建步骤

#### Windows (PowerShell)

```powershell
# 构建所有镜像
.\scripts\build-images.ps1

# 或者指定镜像标签
$env:IMAGE_TAG="v1.0.0"
.\scripts\build-images.ps1
```

#### Linux/Mac (Bash)

```bash
# 添加执行权限
chmod +x scripts/build-images.sh

# 构建所有镜像
./scripts/build-images.sh

# 或者指定镜像标签
IMAGE_TAG=v1.0.0 ./scripts/build-images.sh
```

### 镜像构建详解

#### 多阶段构建

```dockerfile
# 阶段 1: 构建阶段
FROM python:3.11-slim as builder
# 安装构建依赖和 Python 包

# 阶段 2: 运行阶段
FROM python:3.11-slim
# 只复制运行时需要的文件
```

**为什么使用多阶段构建？**
- ✅ 减小镜像大小（不包含构建工具）
- ✅ 提高安全性（不包含源代码和构建工具）
- ✅ 更好的缓存利用

#### 健康检查

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8001/health')" || exit 1
```

**为什么需要健康检查？**
- ✅ Kubernetes Liveness Probe: 检测容器是否存活
- ✅ Kubernetes Readiness Probe: 检测容器是否就绪
- ✅ 自动重启: 如果健康检查失败，Kubernetes 会重启容器

## 🔍 OpenTelemetry 集成

### 为什么需要 OpenTelemetry？

1. **分布式追踪**: 在微服务架构中追踪请求的完整路径
2. **性能分析**: 识别慢请求和瓶颈服务
3. **故障排查**: 快速定位问题所在的服务
4. **服务依赖图**: 自动生成服务拓扑关系

### 配置说明

#### 1. 环境变量配置

在 Kubernetes Deployment 中配置：

```yaml
env:
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "http://jaeger-collector.observability.svc.cluster.local:4317"
- name: OTEL_SERVICE_NAME
  value: "user-service"
- name: OTEL_RESOURCE_ATTRIBUTES
  value: "service.name=user-service,service.namespace=microservices"
```

**为什么使用环境变量？**
- ✅ 配置与代码分离
- ✅ 不同环境使用不同配置
- ✅ Kubernetes 可以通过 ConfigMap/Secret 注入

#### 2. 代码集成

```python
# 配置 OpenTelemetry
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource

# 创建 Resource（标识服务）
resource = Resource.create({
    "service.name": "user-service",
    "service.namespace": "microservices"
})

# 创建 TracerProvider
trace.set_tracer_provider(TracerProvider(resource=resource))

# 配置 OTLP Exporter
otlp_exporter = OTLPSpanExporter(
    endpoint="http://jaeger-collector:4317",
    insecure=True
)

# 添加 Span Processor
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# 自动检测 FastAPI
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
FastAPIInstrumentor.instrument_app(app)
```

**为什么使用自动检测？**
- ✅ 零代码侵入: 自动追踪 HTTP 请求
- ✅ 标准化: 使用标准的追踪格式
- ✅ 易于维护: 不需要手动添加追踪代码

#### 3. 自定义 Span

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

# 创建自定义 Span
with tracer.start_as_current_span("create_user") as span:
    # 添加属性
    span.set_attribute("user.email", email)
    span.set_attribute("user.name", name)
    
    # 业务逻辑
    user = create_user(...)
    
    # 记录结果
    span.set_attribute("user.id", user.id)
```

**为什么需要自定义 Span？**
- ✅ 追踪业务逻辑: 不仅仅是 HTTP 请求
- ✅ 添加上下文信息: 便于查询和过滤
- ✅ 错误追踪: 记录异常信息

## 🚀 完整部署流程

### 一键部署（推荐）

#### Windows (PowerShell)

```powershell
# 完整设置和部署
.\scripts\setup-and-deploy.ps1
```

#### Linux/Mac (Bash)

```bash
# 添加执行权限
chmod +x scripts/setup-and-deploy.sh

# 完整设置和部署
./scripts/setup-and-deploy.sh
```

### 手动部署步骤

#### 步骤 1: 创建 Kubernetes 集群

```bash
# 使用 kind 创建本地集群
kind create cluster --name observability-platform

# 验证集群
kubectl cluster-info --context kind-observability-platform
```

**为什么使用 kind？**
- ✅ 本地开发: 不需要云环境
- ✅ 快速启动: 几秒钟就能启动集群
- ✅ 完全兼容: 与真实 Kubernetes 集群兼容

#### 步骤 2: 构建镜像

```bash
# Windows
.\scripts\build-images.ps1

# Linux/Mac
./scripts/build-images.sh
```

#### 步骤 3: 部署基础设施

```bash
# 创建命名空间
kubectl apply -f k8s/namespaces/

# 安装 Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin

# 部署数据库和消息队列
kubectl apply -f k8s/database/postgresql.yaml
kubectl apply -f k8s/messaging/rabbitmq.yaml

# 创建 Secrets
kubectl create secret generic database-secrets \
  --from-literal=user-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/users_db" \
  --from-literal=product-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/products_db" \
  --from-literal=order-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/orders_db" \
  -n microservices

kubectl create secret generic rabbitmq-secrets \
  --from-literal=url="amqp://guest:guest@rabbitmq.microservices.svc.cluster.local:5672/" \
  -n microservices
```

#### 步骤 4: 部署可观测性平台

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

cd helm/observability-platform
helm dependency update
cd ../..

helm install observability-platform ./helm/observability-platform \
  --namespace observability \
  --create-namespace
```

#### 步骤 5: 部署微服务

```bash
helm install microservices ./helm/microservices \
  --namespace microservices \
  --create-namespace
```

#### 步骤 6: 配置监控

```bash
kubectl apply -f k8s/monitoring/
kubectl apply -f k8s/autoscaling/
```

## ✅ 验证部署

### 检查 Pod 状态

```bash
kubectl get pods -A
```

所有 Pod 应该显示 `Running` 状态。

### 测试微服务

```bash
# 端口转发
kubectl port-forward -n microservices svc/user-service 8001:8001 &
kubectl port-forward -n microservices svc/product-service 8002:8002 &
kubectl port-forward -n microservices svc/order-service 8003:8003 &

# 创建用户
curl -X POST http://localhost:8001/api/users \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "name": "Test User", "password": "123456"}'

# 创建商品
curl -X POST http://localhost:8002/api/products/ \
  -H "Content-Type: application/json" \
  -d '{"name": "MacBook Pro", "description": "Laptop", "price": 12999.0, "stock": 50}'

# 创建订单
curl -X POST http://localhost:8003/api/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "product_id": 1, "quantity": 3}'
```

### 查看追踪

1. 端口转发 Jaeger UI:
   ```bash
   kubectl port-forward -n observability svc/jaeger-query 16686:16686
   ```

2. 打开浏览器: http://localhost:16686

3. 选择服务 `order-service`，点击 "Find Traces"

4. 你应该能看到完整的调用链:
   - order-service 调用 user-service
   - order-service 调用 product-service
   - order-service 发布 RabbitMQ 事件
   - product-service 消费 RabbitMQ 事件

## 🔧 故障排查

### 镜像构建失败

```bash
# 查看构建日志
docker build -t user-service:latest services/user-service/

# 检查 Dockerfile 语法
docker build --no-cache -t user-service:latest services/user-service/
```

### Pod 无法启动

```bash
# 查看 Pod 日志
kubectl logs -n microservices <pod-name>

# 查看 Pod 描述
kubectl describe pod -n microservices <pod-name>

# 检查镜像是否存在
docker images | grep user-service
```

### 追踪数据缺失

```bash
# 检查环境变量
kubectl exec -n microservices <pod-name> -- env | grep OTEL

# 检查 Jaeger Collector 日志
kubectl logs -n observability -l app.kubernetes.io/name=jaeger

# 检查网络连接
kubectl exec -n microservices <pod-name> -- \
  curl -v http://jaeger-collector.observability.svc.cluster.local:4317
```

## 📚 参考资源

- [OpenTelemetry Python Documentation](https://opentelemetry-python.readthedocs.io/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)














