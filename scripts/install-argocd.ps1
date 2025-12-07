# 安装 ArgoCD 脚本 (Windows PowerShell)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Installing ArgoCD..." -ForegroundColor Green

# 检查 kubectl
try {
    kubectl version --client | Out-Null
} catch {
    Write-Host "❌ kubectl is not installed" -ForegroundColor Red
    exit 1
}

# 创建命名空间
Write-Host "📦 Creating argocd namespace..." -ForegroundColor Yellow
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# 安装 ArgoCD
Write-Host "📥 Installing ArgoCD manifests..." -ForegroundColor Yellow
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 等待 ArgoCD 就绪
Write-Host "⏳ Waiting for ArgoCD to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$maxRetries = 30
$retryCount = 0
$ready = $false

while ($retryCount -lt $maxRetries -and -not $ready) {
    try {
        $server = kubectl get deployment argocd-server -n argocd -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>$null
        $repoServer = kubectl get deployment argocd-repo-server -n argocd -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>$null
        $controller = kubectl get deployment argocd-application-controller -n argocd -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>$null
        
        if ($server -eq "True" -and $repoServer -eq "True" -and $controller -eq "True") {
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
    Write-Host "⚠️  ArgoCD may still be starting. Please check manually." -ForegroundColor Yellow
}

# 获取初始密码
Write-Host ""
Write-Host "🔑 ArgoCD Initial Admin Password:" -ForegroundColor Cyan
$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>$null
if ($password) {
    $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
    Write-Host $decoded -ForegroundColor Green
} else {
    Write-Host "⚠️  Password not available yet. Please wait a few minutes and run:" -ForegroundColor Yellow
    Write-Host "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }" -ForegroundColor Yellow
}
Write-Host ""

# 显示访问信息
Write-Host "✅ ArgoCD installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 To access ArgoCD UI:" -ForegroundColor Cyan
Write-Host "   1. Port forward: kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor White
Write-Host "   2. Open browser: https://localhost:8080" -ForegroundColor White
Write-Host "   3. Username: admin" -ForegroundColor White
Write-Host "   4. Password: (see above)" -ForegroundColor White
Write-Host ""
Write-Host "📝 To install ArgoCD CLI:" -ForegroundColor Cyan
Write-Host "   - Download from: https://github.com/argoproj/argo-cd/releases" -ForegroundColor White
Write-Host "   - Or use: winget install ArgoCD" -ForegroundColor White
Write-Host ""

