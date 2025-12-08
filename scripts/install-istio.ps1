# 安装 Istio Service Mesh - Windows PowerShell

$ErrorActionPreference = "Stop"

Write-Host "🚀 Installing Istio Service Mesh..." -ForegroundColor Green

# 检查 kubectl
try {
    kubectl version --client | Out-Null
} catch {
    Write-Host "❌ kubectl is not installed" -ForegroundColor Red
    exit 1
}

# 检查 istioctl
try {
    istioctl version | Out-Null
    Write-Host "✅ istioctl already installed" -ForegroundColor Green
} catch {
    Write-Host "📥 Installing istioctl..." -ForegroundColor Yellow
    Write-Host "   Please download from: https://istio.io/latest/docs/setup/getting-started/#download" -ForegroundColor Cyan
    Write-Host "   Or use: winget install Istio.Istio" -ForegroundColor Cyan
    exit 1
}

# 安装 Istio
Write-Host "📦 Installing Istio..." -ForegroundColor Yellow
istioctl install --set profile=default -y

# 等待 Istio 就绪
Write-Host "⏳ Waiting for Istio to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$maxRetries = 30
$retryCount = 0
$ready = $false

while ($retryCount -lt $maxRetries -and -not $ready) {
    try {
        $istiod = kubectl get pods -l app=istiod -n istio-system -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>$null
        $gateway = kubectl get pods -l app=istio-ingressgateway -n istio-system -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>$null
        
        if ($istiod -eq "True" -and $gateway -eq "True") {
            $ready = $true
        } else {
            Start-Sleep -Seconds 10
            $retryCount++
        }
    } catch {
        Start-Sleep -Seconds 10
        $retryCount++
    }
}

if (-not $ready) {
    Write-Host "⚠️  Istio may still be starting. Please check manually." -ForegroundColor Yellow
}

# 启用命名空间自动注入
Write-Host "📝 Enabling sidecar auto-injection for microservices namespace..." -ForegroundColor Yellow
kubectl label namespace microservices istio-injection=enabled --overwrite

# 应用 Istio 配置
Write-Host "📝 Applying Istio configurations..." -ForegroundColor Yellow
kubectl apply -f k8s/service-mesh/mtls-policy.yaml
kubectl apply -f k8s/service-mesh/destination-rules.yaml
kubectl apply -f k8s/service-mesh/virtual-services.yaml
kubectl apply -f k8s/service-mesh/gateway.yaml

Write-Host ""
Write-Host "✅ Istio installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Verify installation:" -ForegroundColor Cyan
Write-Host "   kubectl get pods -n istio-system" -ForegroundColor White
Write-Host "   kubectl get peerauthentication -n microservices" -ForegroundColor White
Write-Host "   kubectl get destinationrule -n microservices" -ForegroundColor White
Write-Host "   kubectl get virtualservice -n microservices" -ForegroundColor White
Write-Host ""
Write-Host "🌐 Access services via Istio Gateway:" -ForegroundColor Cyan
Write-Host "   kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80" -ForegroundColor White
Write-Host "   curl http://localhost:8080/api/users/health" -ForegroundColor White
Write-Host ""

