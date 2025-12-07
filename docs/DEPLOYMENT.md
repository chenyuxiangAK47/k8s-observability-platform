# 部署指南

## 前置要求

### 1. 安装必要工具

```bash
# 安装 kubectl
# Windows (使用 Chocolatey)
choco install kubernetes-cli

# Mac (使用 Homebrew)
brew install kubectl

# 安装 Helm
# Windows
choco install kubernetes-helm

# Mac
brew install helm

# 安装 kind (用于本地测试)
# Windows
choco install kind

# Mac
brew install kind
```

### 2. 创建本地 Kubernetes 集群

```bash
# 使用 kind 创建集群
kind create cluster --name observability-platform

# 验证集群
kubectl cluster-info --context kind-observability-platform
```

## 部署步骤

### 步骤 1: 创建命名空间

```bash
kubectl apply -f k8s/namespaces/
```

### 步骤 2: 安装 Prometheus Operator

```bash
# 添加 Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 安装 Prometheus Operator
helm install prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin
```

等待 Prometheus Operator 就绪：

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kube-prometheus-operator -n monitoring --timeout=300s
```

### 步骤 3: 部署可观测性平台

```bash
# 添加依赖的 Helm repos
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

# 安装依赖
cd helm/observability-platform
helm dependency update
cd ../..

# 部署可观测性平台
helm install observability-platform ./helm/observability-platform \
  --namespace observability \
  --create-namespace
```

### 步骤 4: 构建和推送 Docker 镜像

首先，你需要从原始项目构建 Docker 镜像：

```bash
# 克隆原始项目（如果还没有）
git clone https://github.com/chenyuxiangAK47/microshop-microservices.git
cd microshop-microservices

# 构建镜像
docker build -t user-service:latest -f user-service/Dockerfile .
docker build -t product-service:latest -f product-service/Dockerfile .
docker build -t order-service:latest -f order-service/Dockerfile .

# 如果是 kind 集群，需要加载镜像到集群
kind load docker-image user-service:latest --name observability-platform
kind load docker-image product-service:latest --name observability-platform
kind load docker-image order-service:latest --name observability-platform
```

### 步骤 5: 部署数据库和消息队列

```bash
# 部署 PostgreSQL
kubectl apply -f k8s/database/postgresql.yaml

# 部署 RabbitMQ
kubectl apply -f k8s/messaging/rabbitmq.yaml

# 等待就绪
kubectl wait --for=condition=ready pod -l app=postgresql -n microservices --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n microservices --timeout=300s
```

### 步骤 6: 创建 Secrets

```bash
# 创建数据库 secrets（请修改密码）
kubectl create secret generic database-secrets \
  --from-literal=user-db-url="postgresql://user:password@postgres.microservices.svc.cluster.local:5432/users_db" \
  --from-literal=product-db-url="postgresql://user:password@postgres.microservices.svc.cluster.local:5432/products_db" \
  --from-literal=order-db-url="postgresql://user:password@postgres.microservices.svc.cluster.local:5432/orders_db" \
  -n microservices

# 创建 RabbitMQ secrets
kubectl create secret generic rabbitmq-secrets \
  --from-literal=url="amqp://guest:guest@rabbitmq.microservices.svc.cluster.local:5672/" \
  -n microservices
```

### 步骤 7: 部署微服务

```bash
# 使用 Helm 部署
helm install microservices ./helm/microservices \
  --namespace microservices \
  --create-namespace

# 或者使用原生 Kubernetes 配置
kubectl apply -f k8s/services/
```

### 步骤 8: 配置监控

```bash
# 创建 ServiceMonitor
kubectl apply -f k8s/monitoring/service-monitor.yaml

# 创建 PrometheusRule
kubectl apply -f k8s/monitoring/prometheus-rule.yaml
```

### 步骤 9: 配置自动扩缩容

```bash
kubectl apply -f k8s/autoscaling/
```

## 验证部署

### 检查 Pod 状态

```bash
# 检查所有命名空间的 Pod
kubectl get pods -A

# 检查特定命名空间
kubectl get pods -n microservices
kubectl get pods -n observability
kubectl get pods -n monitoring
```

### 访问服务

```bash
# 端口转发 Grafana
kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80

# 端口转发 Prometheus
kubectl port-forward -n monitoring svc/prometheus-operator-kube-prom-prometheus 9090:9090

# 端口转发 Jaeger
kubectl port-forward -n observability svc/jaeger-query 16686:16686

# 端口转发微服务
kubectl port-forward -n microservices svc/user-service 8001:8001
kubectl port-forward -n microservices svc/product-service 8002:8002
kubectl port-forward -n microservices svc/order-service 8003:8003
```

### 访问地址

- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090
- Jaeger: http://localhost:16686
- User Service: http://localhost:8001
- Product Service: http://localhost:8002
- Order Service: http://localhost:8003

## 故障排查

### 查看 Pod 日志

```bash
# 查看特定 Pod 的日志
kubectl logs -n microservices <pod-name>

# 查看所有 Pod 的日志
kubectl logs -n microservices -l app=user-service
```

### 查看 Pod 描述

```bash
kubectl describe pod -n microservices <pod-name>
```

### 检查 ServiceMonitor

```bash
kubectl get servicemonitor -n microservices
kubectl describe servicemonitor -n microservices microservices-metrics
```

### 检查 HPA

```bash
kubectl get hpa -n microservices
kubectl describe hpa -n microservices user-service-hpa
```

## 清理

```bash
# 删除 Helm releases
helm uninstall microservices -n microservices
helm uninstall observability-platform -n observability
helm uninstall prometheus-operator -n monitoring

# 删除命名空间
kubectl delete namespace microservices
kubectl delete namespace observability
kubectl delete namespace monitoring

# 删除 kind 集群
kind delete cluster --name observability-platform
```












