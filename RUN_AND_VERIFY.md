# 🚀 运行和验证指南

这个文档告诉你如何运行和验证整个项目。

---

## ✅ 前置条件检查

在开始之前，确保你已经安装了以下工具：

```bash
# 检查 Docker
docker --version
# 应该显示: Docker version 20.x 或更高

# 检查 kubectl
kubectl version --client
# 应该显示: Client Version: v1.x

# 检查 Helm
helm version
# 应该显示: version.BuildInfo{Version:"v3.x"}

# 检查 kind
kind version
# 应该显示: kind v0.x
```

### 安装缺失的工具

#### Windows
```powershell
# Docker Desktop
# 下载: https://www.docker.com/products/docker-desktop

# kubectl
# 下载: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/

# Helm
# 使用 Chocolatey: choco install kubernetes-helm
# 或下载: https://helm.sh/docs/intro/install/

# kind
# 下载: https://kind.sigs.k8s.io/docs/user/quick-start/#installation
```

#### Linux/Mac
```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

---

## 🚀 快速运行（推荐）

### Windows (PowerShell)

```powershell
# 1. 确保 Docker Desktop 正在运行
docker ps

# 2. 一键部署（自动完成所有步骤）
.\scripts\setup-and-deploy.ps1

# 3. 验证部署
.\scripts\verify-deployment.ps1

# 4. 测试 API
.\scripts\test-api.ps1
```

### Linux/Mac (Bash)

```bash
# 1. 确保 Docker 正在运行
docker ps

# 2. 添加执行权限
chmod +x scripts/*.sh

# 3. 一键部署
./scripts/setup-and-deploy.sh

# 4. 验证部署
./scripts/verify-deployment.sh

# 5. 测试 API
./scripts/test-api.sh
```

---

## 📋 分步运行（如果一键部署失败）

### 步骤 1: 创建 Kubernetes 集群

```bash
# 创建 kind 集群
kind create cluster --name observability-platform

# 验证集群
kubectl cluster-info
kubectl get nodes
```

### 步骤 2: 构建 Docker 镜像

```bash
# Windows
.\scripts\build-images.ps1

# Linux/Mac
./scripts/build-images.sh
```

### 步骤 3: 部署基础设施

```bash
# 创建命名空间
kubectl apply -f k8s/namespaces/namespaces.yaml

# 部署数据库
kubectl apply -f k8s/database/postgresql.yaml

# 部署消息队列
kubectl apply -f k8s/messaging/rabbitmq.yaml

# 等待就绪
kubectl wait --for=condition=ready pod -l app=postgresql -n microservices --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n microservices --timeout=300s
```

### 步骤 4: 部署可观测性平台

```bash
# 添加 Helm 仓库
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

# 安装 Prometheus Operator
helm install prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin

# 安装可观测性平台
cd helm/observability-platform
helm dependency update
cd ../..
helm install observability-platform ./helm/observability-platform \
  --namespace observability \
  --create-namespace
```

### 步骤 5: 部署微服务

```bash
# 使用 Helm 部署
helm install microservices ./helm/microservices \
  --namespace microservices \
  --create-namespace

# 或使用原生 YAML
kubectl apply -f k8s/services/
```

### 步骤 6: 配置监控和自动扩缩容

```bash
# 部署 ServiceMonitor
kubectl apply -f k8s/monitoring/

# 部署 HPA
kubectl apply -f k8s/autoscaling/hpa.yaml
```

---

## ✅ 验证部署

### 1. 检查 Pod 状态

```bash
# 查看所有 Pod
kubectl get pods -A

# 应该看到：
# - microservices 命名空间：user-service, product-service, order-service
# - observability 命名空间：loki, jaeger
# - monitoring 命名空间：prometheus, grafana
```

所有 Pod 应该显示 `Running` 状态。

### 2. 检查服务

```bash
# 查看服务
kubectl get svc -A

# 应该看到所有服务都有 ClusterIP
```

### 3. 测试微服务 API

```bash
# 端口转发（在单独的终端）
kubectl port-forward -n microservices svc/user-service 8001:8001 &
kubectl port-forward -n microservices svc/product-service 8002:8002 &
kubectl port-forward -n microservices svc/order-service 8003:8003 &

# 测试健康检查
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health

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

### 4. 查看监控

```bash
# 端口转发 Grafana
kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80

# 打开浏览器: http://localhost:3000
# 用户名: admin
# 密码: admin
```

### 5. 查看分布式追踪

```bash
# 端口转发 Jaeger
kubectl port-forward -n observability svc/jaeger-query 16686:16686

# 打开浏览器: http://localhost:16686
# 选择服务 order-service，查看完整的调用链
```

---

## 🔧 常见问题

### 问题 1: Docker 未运行

**错误信息：**
```
Cannot connect to the Docker daemon
```

**解决方案：**
```bash
# Windows: 启动 Docker Desktop
# Linux: 启动 Docker 服务
sudo systemctl start docker
```

### 问题 2: kind 集群创建失败

**错误信息：**
```
ERROR: failed to create cluster
```

**解决方案：**
```bash
# 删除旧集群
kind delete cluster --name observability-platform

# 重新创建
kind create cluster --name observability-platform
```

### 问题 3: Pod 无法启动

**检查：**
```bash
# 查看 Pod 状态
kubectl get pods -n microservices

# 查看 Pod 日志
kubectl logs -n microservices <pod-name>

# 查看 Pod 描述
kubectl describe pod -n microservices <pod-name>
```

**常见原因：**
- 镜像拉取失败 → 检查镜像是否存在
- 资源不足 → 检查 Docker Desktop 资源设置
- 配置错误 → 检查 YAML 文件

### 问题 4: 服务无法访问

**检查：**
```bash
# 检查 Service
kubectl get svc -n microservices

# 检查 Endpoints
kubectl get endpoints -n microservices

# 测试服务内部连接
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://user-service.microservices.svc.cluster.local:8001/health
```

---

## 🧹 清理环境

### 完全清理

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

### 部分清理

```bash
# 只删除微服务
helm uninstall microservices -n microservices

# 只删除可观测性平台
helm uninstall observability-platform -n observability
```

---

## 📊 验证清单

完成以下检查项，确保一切正常：

- [ ] 所有 Pod 状态为 `Running`
- [ ] 所有 Service 都有 ClusterIP
- [ ] 微服务健康检查返回 200
- [ ] 可以创建用户、商品、订单
- [ ] Grafana 可以访问
- [ ] Prometheus 可以访问
- [ ] Jaeger 可以访问并看到追踪数据
- [ ] HPA 已创建并正常工作

---

## 🎯 下一步

完成验证后，你可以：

1. **测试 Level 1 功能**
   ```bash
   # 安装高级自动扩缩容
   ./scripts/install-advanced-autoscaling.sh
   
   # 安装 Istio
   ./scripts/install-istio.sh
   ```

2. **阅读文档**
   - [Level 1 完整功能指南](docs/LEVEL1_COMPLETE.md)
   - [GitOps 部署指南](docs/GITOPS_DEPLOYMENT.md)

3. **探索功能**
   - 测试金丝雀发布
   - 测试自动扩缩容
   - 查看监控和追踪

---

**现在就开始运行吧！** 🚀

