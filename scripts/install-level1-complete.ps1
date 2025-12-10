# Level 1 完整安装脚本 - Windows PowerShell
# 安装所有 Level 1 功能：高级自动扩缩容 + Service Mesh

$ErrorActionPreference = "Stop"

Write-Host "🚀 Installing Level 1 Complete Features..." -ForegroundColor Green
Write-Host "   - Advanced Autoscaling (Prometheus HPA, VPA, KEDA)" -ForegroundColor White
Write-Host "   - Service Mesh (Istio with mTLS and Canary)" -ForegroundColor White
Write-Host ""

# 检查前置条件
try {
    kubectl version --client | Out-Null
} catch {
    Write-Host "❌ kubectl is not installed" -ForegroundColor Red
    exit 1
}

try {
    helm version | Out-Null
} catch {
    Write-Host "❌ helm is not installed" -ForegroundColor Red
    exit 1
}

# 1. 安装高级自动扩缩容
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📦 Step 1: Installing Advanced Autoscaling" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
.\scripts\install-advanced-autoscaling.ps1

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📦 Step 2: Installing Istio Service Mesh" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
.\scripts\install-istio.ps1

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Level 1 Complete Installation Finished!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "📊 Verify all components:" -ForegroundColor Cyan
Write-Host "   # Autoscaling" -ForegroundColor White
Write-Host "   kubectl get hpa -n microservices" -ForegroundColor Gray
Write-Host "   kubectl get vpa -n microservices" -ForegroundColor Gray
Write-Host "   kubectl get scaledobject -n microservices" -ForegroundColor Gray
Write-Host ""
Write-Host "   # Service Mesh" -ForegroundColor White
Write-Host "   kubectl get pods -n istio-system" -ForegroundColor Gray
Write-Host "   kubectl get peerauthentication -n microservices" -ForegroundColor Gray
Write-Host "   kubectl get destinationrule -n microservices" -ForegroundColor Gray
Write-Host "   kubectl get virtualservice -n microservices" -ForegroundColor Gray
Write-Host ""
Write-Host "📚 Next steps:" -ForegroundColor Cyan
Write-Host "   - Read docs/LEVEL1_COMPLETE.md for usage guide" -ForegroundColor White
Write-Host "   - Test canary deployment: .\scripts\canary-deployment.sh user-service" -ForegroundColor White
Write-Host ""




