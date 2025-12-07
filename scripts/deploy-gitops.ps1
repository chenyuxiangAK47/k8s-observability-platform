# 部署 GitOps Applications 脚本 (Windows PowerShell)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Deploying GitOps Applications..." -ForegroundColor Green

# 检查 kubectl
try {
    kubectl version --client | Out-Null
} catch {
    Write-Host "❌ kubectl is not installed" -ForegroundColor Red
    exit 1
}

# 检查 ArgoCD 是否运行
try {
    kubectl get namespace argocd | Out-Null
} catch {
    Write-Host "❌ ArgoCD namespace not found. Please install ArgoCD first:" -ForegroundColor Red
    Write-Host "   .\scripts\install-argocd.ps1" -ForegroundColor Yellow
    exit 1
}

# 部署 Applications
Write-Host "📦 Deploying microservices application..." -ForegroundColor Yellow
kubectl apply -f gitops/apps/microservices-app.yaml

Write-Host "📦 Deploying observability platform application..." -ForegroundColor Yellow
kubectl apply -f gitops/apps/observability-app.yaml

# 等待 Applications 创建
Write-Host "⏳ Waiting for applications to be created..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# 显示状态
Write-Host ""
Write-Host "✅ Applications deployed!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Application status:" -ForegroundColor Cyan
kubectl get applications -n argocd

Write-Host ""
Write-Host "📝 To view detailed status:" -ForegroundColor Cyan
Write-Host "   kubectl get application microservices -n argocd -o yaml" -ForegroundColor White
Write-Host ""
Write-Host "📝 To sync manually (if needed):" -ForegroundColor Cyan
Write-Host "   argocd app sync microservices" -ForegroundColor White
Write-Host "   argocd app sync observability-platform" -ForegroundColor White
Write-Host ""

