# 安装高级自动扩缩容组件（Prometheus Adapter, VPA, KEDA） - Windows PowerShell

$ErrorActionPreference = "Stop"

Write-Host "🚀 Installing Advanced Autoscaling Components..." -ForegroundColor Green

# 检查 kubectl
try {
    kubectl version --client | Out-Null
} catch {
    Write-Host "❌ kubectl is not installed" -ForegroundColor Red
    exit 1
}

# 1. 安装 Prometheus Adapter
Write-Host "📦 Installing Prometheus Adapter..." -ForegroundColor Yellow
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install prometheus-adapter prometheus-community/prometheus-adapter `
  --namespace kube-system `
  --set prometheus.url=http://prometheus.observability.svc.cluster.local `
  --set prometheus.port=9090 `
  --set logLevel=4 `
  --wait

Write-Host "✅ Prometheus Adapter installed" -ForegroundColor Green

# 2. 安装 VPA
Write-Host "📦 Installing VPA (Vertical Pod Autoscaler)..." -ForegroundColor Yellow
Write-Host "⚠️  VPA requires manual installation on Windows" -ForegroundColor Yellow
Write-Host "   See: https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler" -ForegroundColor Cyan

# 3. 安装 KEDA
Write-Host "📦 Installing KEDA..." -ForegroundColor Yellow
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm upgrade --install keda kedacore/keda `
  --namespace kube-system `
  --wait

Write-Host "✅ KEDA installed" -ForegroundColor Green

# 4. 应用配置
Write-Host "📝 Applying autoscaling configurations..." -ForegroundColor Yellow
kubectl apply -f k8s/autoscaling/prometheus-adapter.yaml
kubectl apply -f k8s/autoscaling/prometheus-metrics-hpa.yaml
kubectl apply -f k8s/autoscaling/vpa.yaml
kubectl apply -f k8s/autoscaling/keda-redis-scaler.yaml

Write-Host ""
Write-Host "✅ Advanced Autoscaling Components installed!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Verify installation:" -ForegroundColor Cyan
Write-Host "   kubectl get pods -n kube-system | Select-String 'prometheus-adapter|vpa|keda'" -ForegroundColor White
Write-Host "   kubectl get hpa -n microservices" -ForegroundColor White
Write-Host "   kubectl get vpa -n microservices" -ForegroundColor White
Write-Host "   kubectl get scaledobject -n microservices" -ForegroundColor White
Write-Host ""


