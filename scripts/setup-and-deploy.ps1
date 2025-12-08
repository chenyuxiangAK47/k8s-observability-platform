# Complete Setup and Deployment Script (Windows PowerShell)
# 
# What does this script do?
# 1. Check prerequisites
# 2. Create Kubernetes cluster
# 3. Build Docker images
# 4. Deploy all components
# 5. Verify deployment

$ErrorActionPreference = "Continue"

$CLUSTER_NAME = "observability-platform"

Write-Host "🚀 Starting complete setup and deployment process..." -ForegroundColor Blue

# ==================== Step 1: Check Prerequisites ====================
Write-Host "📋 Step 1: Checking prerequisites..." -ForegroundColor Yellow

function Test-Command {
    param($CommandName)
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Host "✅ $CommandName is installed" -ForegroundColor Green
        return $true
    } else {
        Write-Host "Error: $CommandName is not installed" -ForegroundColor Red
        Write-Host "Please install $CommandName and try again"
        exit 1
    }
}

function Test-KubectlResource {
    param($ResourceType, $ResourceName, $Namespace)
    $ErrorActionPreference = "SilentlyContinue"
    $result = kubectl get $ResourceType $ResourceName -n $Namespace 2>&1
    $ErrorActionPreference = "Continue"
    return $LASTEXITCODE -eq 0
}

Test-Command "docker"
Test-Command "kubectl"
Test-Command "helm"
Test-Command "kind"

# Check if Docker is running
try {
    docker info | Out-Null
    Write-Host "✅ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "Error: Docker is not running" -ForegroundColor Red
    exit 1
}

# ==================== Step 2: Create Kubernetes Cluster ====================
Write-Host "📦 Step 2: Creating Kubernetes cluster..." -ForegroundColor Yellow

$clusters = kind get clusters 2>&1
if ($clusters -contains $CLUSTER_NAME) {
    Write-Host "Cluster $CLUSTER_NAME already exists, skipping creation" -ForegroundColor Yellow
} else {
    Write-Host "Creating kind cluster: $CLUSTER_NAME..." -ForegroundColor Blue
    kind create cluster --name $CLUSTER_NAME
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Cluster created successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Cluster creation may have issues, but continuing..." -ForegroundColor Yellow
    }
}

# Set kubectl context
kubectl cluster-info --context "kind-$CLUSTER_NAME"

# ==================== Step 3: Build Docker Images ====================
Write-Host "🐳 Step 3: Building Docker images..." -ForegroundColor Yellow
.\scripts\build-images.ps1

# ==================== Step 4: Deploy Infrastructure ====================
Write-Host "🏗️  Step 4: Deploying infrastructure..." -ForegroundColor Yellow

# Create namespaces
Write-Host "Creating namespaces..." -ForegroundColor Blue
kubectl apply -f k8s/namespaces/

# Install Prometheus Operator
Write-Host "Installing Prometheus Operator..." -ForegroundColor Blue
$prometheusInstalled = helm list -n monitoring 2>&1 | Select-String "prometheus-operator"
if ($prometheusInstalled) {
    Write-Host "Prometheus Operator already installed, skipping..." -ForegroundColor Yellow
} else {
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm install prometheus-operator prometheus-community/kube-prometheus-stack `
        --namespace monitoring `
        --create-namespace `
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false `
        --set grafana.adminPassword=admin `
        --wait
    
    Write-Host "✅ Prometheus Operator installed successfully" -ForegroundColor Green
}

# Deploy database and message queue
Write-Host "Deploying database and message queue..." -ForegroundColor Blue
kubectl apply -f k8s/database/postgresql.yaml
kubectl apply -f k8s/messaging/rabbitmq.yaml

Write-Host "Waiting for database and message queue to be ready..." -ForegroundColor Blue
Start-Sleep -Seconds 10

# Create Secrets
Write-Host "Creating Secrets..." -ForegroundColor Blue
if (-not (Test-KubectlResource -ResourceType "secret" -ResourceName "database-secrets" -Namespace "microservices")) {
    kubectl create secret generic database-secrets `
        --from-literal=user-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/users_db" `
        --from-literal=product-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/products_db" `
        --from-literal=order-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/orders_db" `
        -n microservices
    Write-Host "✅ Database secrets created" -ForegroundColor Green
} else {
    Write-Host "Database secrets already exist, skipping..." -ForegroundColor Yellow
}

if (-not (Test-KubectlResource -ResourceType "secret" -ResourceName "rabbitmq-secrets" -Namespace "microservices")) {
    kubectl create secret generic rabbitmq-secrets `
        --from-literal=url="amqp://guest:guest@rabbitmq.microservices.svc.cluster.local:5672/" `
        -n microservices
    Write-Host "✅ RabbitMQ secrets created" -ForegroundColor Green
} else {
    Write-Host "RabbitMQ secrets already exist, skipping..." -ForegroundColor Yellow
}

# ==================== Step 5: Deploy Observability Platform ====================
Write-Host "📊 Step 5: Deploying observability platform..." -ForegroundColor Yellow

helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

Set-Location helm/observability-platform
helm dependency update
Set-Location ../..

$obsInstalled = helm list -n observability 2>&1 | Select-String "observability-platform"
if ($obsInstalled) {
    Write-Host "Observability platform already installed, skipping..." -ForegroundColor Yellow
} else {
    helm install observability-platform .\helm\observability-platform `
        --namespace observability `
        --create-namespace `
        --wait
}

# ==================== Step 6: Deploy Microservices ====================
Write-Host "🚀 Step 6: Deploying microservices..." -ForegroundColor Yellow

$microInstalled = helm list -n microservices 2>&1 | Select-String "microservices"
if ($microInstalled) {
    Write-Host "Microservices already installed, skipping..." -ForegroundColor Yellow
} else {
    helm install microservices .\helm\microservices `
        --namespace microservices `
        --create-namespace `
        --wait
}

# ==================== Step 7: Configure Monitoring and Autoscaling ====================
Write-Host "📈 Step 7: Configuring monitoring and autoscaling..." -ForegroundColor Yellow

kubectl apply -f k8s/monitoring/

# Note: Advanced autoscaling (KEDA, VPA) requires additional setup
# Skip autoscaling resources that require CRDs for now
# To enable: run .\scripts\install-advanced-autoscaling.ps1 first
Write-Host "Skipping advanced autoscaling resources (KEDA, VPA) - requires CRD installation" -ForegroundColor Yellow
Write-Host "To enable: run .\scripts\install-advanced-autoscaling.ps1 after deployment" -ForegroundColor Cyan
# kubectl apply -f k8s/autoscaling/

# ==================== Step 8: Verify Deployment ====================
Write-Host "✅ Step 8: Verifying deployment..." -ForegroundColor Yellow

Write-Host "Checking Pod status..." -ForegroundColor Blue
kubectl get pods -A

Write-Host "Waiting for all Pods to be ready..." -ForegroundColor Blue
Start-Sleep -Seconds 10

Write-Host "Checking key services..." -ForegroundColor Blue
kubectl get pods -n microservices
kubectl get pods -n observability
kubectl get pods -n monitoring

Write-Host "✅ Deployment completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Access services:" -ForegroundColor Blue
Write-Host '  Grafana:     kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80' -ForegroundColor White
Write-Host '  Prometheus:  kubectl port-forward -n monitoring svc/prometheus-operator-kube-prom-prometheus 9090:9090' -ForegroundColor White
Write-Host '  Jaeger:      kubectl port-forward -n observability svc/jaeger-query 16686:16686' -ForegroundColor White
Write-Host ""
Write-Host "🔍 Test microservices:" -ForegroundColor Blue
Write-Host '  User Service:    kubectl port-forward -n microservices svc/user-service 8001:8001' -ForegroundColor White
Write-Host '  Product Service: kubectl port-forward -n microservices svc/product-service 8002:8002' -ForegroundColor White
Write-Host '  Order Service:   kubectl port-forward -n microservices svc/order-service 8003:8003' -ForegroundColor White
