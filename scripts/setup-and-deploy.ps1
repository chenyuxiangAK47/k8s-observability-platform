# 完整的设置和部署脚本 (Windows PowerShell)
# 
# 这个脚本做了什么？
# 1. 检查前置条件
# 2. 创建 Kubernetes 集群
# 3. 构建 Docker 镜像
# 4. 部署所有组件
# 5. 验证部署

$ErrorActionPreference = "Stop"

$CLUSTER_NAME = "observability-platform"

Write-Host "🚀 开始完整的设置和部署流程..." -ForegroundColor Blue

# ==================== 步骤 1: 检查前置条件 ====================
Write-Host "📋 步骤 1: 检查前置条件..." -ForegroundColor Yellow

function Test-Command {
    param($CommandName)
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Host "✅ $CommandName 已安装" -ForegroundColor Green
        return $true
    } else {
        Write-Host "错误: $CommandName 未安装" -ForegroundColor Red
        Write-Host "请安装 $CommandName 后重试"
        exit 1
    }
}

Test-Command "docker"
Test-Command "kubectl"
Test-Command "helm"
Test-Command "kind"

# 检查 Docker 是否运行
try {
    docker info | Out-Null
    Write-Host "✅ Docker 正在运行" -ForegroundColor Green
} catch {
    Write-Host "错误: Docker 未运行" -ForegroundColor Red
    exit 1
}

# ==================== 步骤 2: 创建 Kubernetes 集群 ====================
Write-Host "📦 步骤 2: 创建 Kubernetes 集群..." -ForegroundColor Yellow

$clusters = kind get clusters 2>$null
if ($clusters -contains $CLUSTER_NAME) {
    Write-Host "集群 $CLUSTER_NAME 已存在，跳过创建" -ForegroundColor Yellow
} else {
    Write-Host "创建 kind 集群: $CLUSTER_NAME..." -ForegroundColor Blue
    kind create cluster --name $CLUSTER_NAME
    Write-Host "✅ 集群创建完成" -ForegroundColor Green
}

# 设置 kubectl context
kubectl cluster-info --context "kind-$CLUSTER_NAME"

# ==================== 步骤 3: 构建 Docker 镜像 ====================
Write-Host "🐳 步骤 3: 构建 Docker 镜像..." -ForegroundColor Yellow
.\scripts\build-images.ps1

# ==================== 步骤 4: 部署基础设施 ====================
Write-Host "🏗️  步骤 4: 部署基础设施..." -ForegroundColor Yellow

# 创建命名空间
Write-Host "创建命名空间..." -ForegroundColor Blue
kubectl apply -f k8s/namespaces/

# 安装 Prometheus Operator
Write-Host "安装 Prometheus Operator..." -ForegroundColor Blue
$prometheusInstalled = helm list -n monitoring 2>$null | Select-String "prometheus-operator"
if ($prometheusInstalled) {
    Write-Host "Prometheus Operator 已安装，跳过..." -ForegroundColor Yellow
} else {
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm install prometheus-operator prometheus-community/kube-prometheus-stack `
        --namespace monitoring `
        --create-namespace `
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false `
        --set grafana.adminPassword=admin `
        --wait
    
    Write-Host "✅ Prometheus Operator 安装完成" -ForegroundColor Green
}

# 部署数据库和消息队列
Write-Host "部署数据库和消息队列..." -ForegroundColor Blue
kubectl apply -f k8s/database/postgresql.yaml
kubectl apply -f k8s/messaging/rabbitmq.yaml

Write-Host "等待数据库和消息队列就绪..." -ForegroundColor Blue
Start-Sleep -Seconds 10

# 创建 Secrets
Write-Host "创建 Secrets..." -ForegroundColor Blue
$dbSecret = kubectl get secret database-secrets -n microservices 2>$null
if (-not $dbSecret) {
    kubectl create secret generic database-secrets `
        --from-literal=user-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/users_db" `
        --from-literal=product-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/products_db" `
        --from-literal=order-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/orders_db" `
        -n microservices
}

$rmqSecret = kubectl get secret rabbitmq-secrets -n microservices 2>$null
if (-not $rmqSecret) {
    kubectl create secret generic rabbitmq-secrets `
        --from-literal=url="amqp://guest:guest@rabbitmq.microservices.svc.cluster.local:5672/" `
        -n microservices
}

# ==================== 步骤 5: 部署可观测性平台 ====================
Write-Host "📊 步骤 5: 部署可观测性平台..." -ForegroundColor Yellow

helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

Set-Location helm/observability-platform
helm dependency update
Set-Location ../..

$obsInstalled = helm list -n observability 2>$null | Select-String "observability-platform"
if ($obsInstalled) {
    Write-Host "可观测性平台已安装，跳过..." -ForegroundColor Yellow
} else {
    helm install observability-platform .\helm\observability-platform `
        --namespace observability `
        --create-namespace `
        --wait
}

# ==================== 步骤 6: 部署微服务 ====================
Write-Host "🚀 步骤 6: 部署微服务..." -ForegroundColor Yellow

$microInstalled = helm list -n microservices 2>$null | Select-String "microservices"
if ($microInstalled) {
    Write-Host "微服务已安装，跳过..." -ForegroundColor Yellow
} else {
    helm install microservices .\helm\microservices `
        --namespace microservices `
        --create-namespace `
        --wait
}

# ==================== 步骤 7: 配置监控和自动扩缩容 ====================
Write-Host "📈 步骤 7: 配置监控和自动扩缩容..." -ForegroundColor Yellow

kubectl apply -f k8s/monitoring/
kubectl apply -f k8s/autoscaling/

# ==================== 步骤 8: 验证部署 ====================
Write-Host "✅ 步骤 8: 验证部署..." -ForegroundColor Yellow

Write-Host "检查 Pod 状态..." -ForegroundColor Blue
kubectl get pods -A

Write-Host "等待所有 Pod 就绪..." -ForegroundColor Blue
Start-Sleep -Seconds 10

Write-Host "检查关键服务..." -ForegroundColor Blue
kubectl get pods -n microservices
kubectl get pods -n observability
kubectl get pods -n monitoring

Write-Host "✅ 部署完成！" -ForegroundColor Green
Write-Host ""
Write-Host "📊 访问服务:" -ForegroundColor Blue
Write-Host "  Grafana:     kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80"
Write-Host "  Prometheus:  kubectl port-forward -n monitoring svc/prometheus-operator-kube-prom-prometheus 9090:9090"
Write-Host "  Jaeger:      kubectl port-forward -n observability svc/jaeger-query 16686:16686"
Write-Host ""
Write-Host "🔍 测试微服务:" -ForegroundColor Blue
Write-Host "  User Service:    kubectl port-forward -n microservices svc/user-service 8001:8001"
Write-Host "  Product Service: kubectl port-forward -n microservices svc/product-service 8002:8002"
Write-Host "  Order Service:   kubectl port-forward -n microservices svc/order-service 8003:8003"









