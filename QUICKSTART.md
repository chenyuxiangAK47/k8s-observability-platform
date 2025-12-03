# 快速开始指南

## 🚀 5分钟快速部署

### 前置要求

- Docker Desktop 运行中
- kubectl 已安装
- Helm 3.x 已安装

### 一键部署（推荐）

```bash
# 1. 创建本地 Kubernetes 集群（使用 kind）
kind create cluster --name observability-platform

# 2. 运行部署脚本
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

### 手动部署步骤

如果一键部署失败，可以按照以下步骤手动部署：

#### 步骤 1: 创建命名空间

```bash
kubectl apply -f k8s/namespaces/
```

#### 步骤 2: 安装 Prometheus Operator

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin
```

#### 步骤 3: 部署基础设施

```bash
# 部署数据库
kubectl apply -f k8s/database/postgresql.yaml

# 部署消息队列
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

#### 步骤 6: 配置监控和自动扩缩容

```bash
kubectl apply -f k8s/monitoring/
kubectl apply -f k8s/autoscaling/
```

## 📊 访问服务

### 端口转发

在单独的终端窗口中运行：

```bash
# Grafana
kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-operator-kube-prom-prometheus 9090:9090

# Jaeger
kubectl port-forward -n observability svc/jaeger-query 16686:16686

# 微服务
kubectl port-forward -n microservices svc/user-service 8001:8001
kubectl port-forward -n microservices svc/product-service 8002:8002
kubectl port-forward -n microservices svc/order-service 8003:8003
```

### 访问地址

- **Grafana**: http://localhost:3000 (用户名: `admin`, 密码: `admin`)
- **Prometheus**: http://localhost:9090
- **Jaeger**: http://localhost:16686
- **User Service**: http://localhost:8001
- **Product Service**: http://localhost:8002
- **Order Service**: http://localhost:8003

## ✅ 验证部署

### 检查 Pod 状态

```bash
kubectl get pods -A
```

所有 Pod 应该显示 `Running` 状态。

### 测试微服务

```bash
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

1. 打开 Jaeger UI: http://localhost:16686
2. 选择服务 `order-service`
3. 点击 "Find Traces"
4. 你应该能看到完整的调用链

## 🔧 故障排查

### Pod 无法启动

```bash
# 查看 Pod 日志
kubectl logs -n microservices <pod-name>

# 查看 Pod 描述
kubectl describe pod -n microservices <pod-name>
```

### 服务无法连接

```bash
# 检查 Service
kubectl get svc -n microservices

# 检查 Endpoints
kubectl get endpoints -n microservices
```

### 监控数据缺失

```bash
# 检查 ServiceMonitor
kubectl get servicemonitor -n microservices

# 检查 Prometheus Targets
# 在 Prometheus UI 中访问: http://localhost:9090/targets
```

## 🧹 清理

```bash
# 删除 Helm releases
helm uninstall microservices -n microservices
helm uninstall observability-platform -n observability
helm uninstall prometheus-operator -n monitoring

# 删除命名空间
kubectl delete namespace microservices observability monitoring

# 删除 kind 集群
kind delete cluster --name observability-platform
```

## 📚 下一步

### 🎯 立即行动

1. **运行部署脚本**
   ```bash
   # Windows
   .\scripts\setup-and-deploy.ps1
   
   # Linux/Mac
   ./scripts/setup-and-deploy.sh
   ```

2. **验证部署**
   ```bash
   # Windows
   .\scripts\verify-deployment.ps1
   
   # Linux/Mac
   ./scripts/verify-deployment.sh
   ```

3. **测试微服务功能**（参考 [NEXT_STEPS.md](NEXT_STEPS.md)）

### 📖 深入学习

- 查看 [NEXT_STEPS.md](NEXT_STEPS.md) - 详细的下一步行动指南
- 查看 [BUILD_AND_DEPLOY.md](BUILD_AND_DEPLOY.md) - 构建和部署详解
- 查看 [LEARNING_NOTES.md](LEARNING_NOTES.md) - 学习笔记（为什么这么做）
- 查看 [部署文档](docs/DEPLOYMENT.md) - 详细部署步骤
- 查看 [OpenTelemetry 集成指南](docs/OPENTELEMETRY.md) - 追踪配置
- 查看 [README](README.md) - 项目架构

