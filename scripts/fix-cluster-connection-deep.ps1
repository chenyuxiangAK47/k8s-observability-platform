# Deep Fix: Cluster Connection Issues
# This script performs comprehensive diagnosis and repair

Write-Host "`n=== 深度修复：集群连接问题 ===" -ForegroundColor Cyan

$ErrorActionPreference = "Continue"

# Step 1: Check Docker Desktop
Write-Host "`n📋 Step 1: Checking Docker Desktop..." -ForegroundColor Yellow
$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Docker Desktop is running" -ForegroundColor Green
} else {
    Write-Host "❌ Docker Desktop is not running or not accessible" -ForegroundColor Red
    Write-Host "   请启动 Docker Desktop 并等待完全启动" -ForegroundColor Yellow
    exit 1
}

# Step 2: Check Kind clusters
Write-Host "`n📋 Step 2: Checking Kind clusters..." -ForegroundColor Yellow
$clusters = kind get clusters 2>&1
if ($LASTEXITCODE -eq 0 -and $clusters -match "observability-platform") {
    Write-Host "✅ Kind cluster 'observability-platform' exists" -ForegroundColor Green
} else {
    Write-Host "❌ Kind cluster not found" -ForegroundColor Red
    Write-Host "   运行: kind create cluster --name observability-platform" -ForegroundColor Yellow
    exit 1
}

# Step 3: Check Kind container status
Write-Host "`n📋 Step 3: Checking Kind container status..." -ForegroundColor Yellow
$kindContainer = docker ps -a --filter "name=observability-platform-control-plane" --format "{{.Status}}" 2>&1
if ($kindContainer) {
    Write-Host "   容器状态: $kindContainer" -ForegroundColor Cyan
    
    if ($kindContainer -match "Exited") {
        Write-Host "⚠️  Kind 容器已退出，正在重启..." -ForegroundColor Yellow
        docker start observability-platform-control-plane 2>&1 | Out-Null
        Write-Host "   等待容器启动..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    } elseif ($kindContainer -match "Up") {
        Write-Host "✅ Kind 容器正在运行" -ForegroundColor Green
    }
} else {
    Write-Host "❌ 找不到 Kind 容器" -ForegroundColor Red
    exit 1
}

# Step 4: Wait for API server to be ready
Write-Host "`n📋 Step 4: Waiting for API server to be ready..." -ForegroundColor Yellow
$maxRetries = 30
$retryCount = 0
$apiReady = $false

while ($retryCount -lt $maxRetries -and -not $apiReady) {
    $retryCount++
    Write-Host "   尝试 $retryCount/$maxRetries..." -ForegroundColor Gray
    
    $nodes = kubectl get nodes --request-timeout=5s 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ API server is ready!" -ForegroundColor Green
        $apiReady = $true
        break
    }
    
    if (-not $apiReady) {
        Start-Sleep -Seconds 2
    }
}

if (-not $apiReady) {
    Write-Host "`n❌ API server 无法响应" -ForegroundColor Red
    Write-Host "`n尝试修复方法..." -ForegroundColor Yellow
    
    # Method 1: Restart Kind container
    Write-Host "`n方法 1: 重启 Kind 容器..." -ForegroundColor Cyan
    docker restart observability-platform-control-plane 2>&1 | Out-Null
    Write-Host "   等待 15 秒..." -ForegroundColor Gray
    Start-Sleep -Seconds 15
    
    # Try again
    $nodes = kubectl get nodes --request-timeout=10s 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 重启后 API server 已就绪" -ForegroundColor Green
        $apiReady = $true
    } else {
        Write-Host "⚠️  重启后仍无法连接" -ForegroundColor Yellow
        
        # Method 2: Recreate kubeconfig
        Write-Host "`n方法 2: 重新配置 kubeconfig..." -ForegroundColor Cyan
        kind export kubeconfig --name observability-platform 2>&1 | Out-Null
        
        Start-Sleep -Seconds 5
        $nodes = kubectl get nodes --request-timeout=10s 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ kubeconfig 重新配置后已连接" -ForegroundColor Green
            $apiReady = $true
        }
    }
}

if (-not $apiReady) {
    Write-Host "`n❌ 所有修复方法都失败了" -ForegroundColor Red
    Write-Host "`n建议操作:" -ForegroundColor Yellow
    Write-Host "   1. 完全重启 Docker Desktop" -ForegroundColor Gray
    Write-Host "   2. 删除并重新创建集群:" -ForegroundColor Gray
    Write-Host "      kind delete cluster --name observability-platform" -ForegroundColor Gray
    Write-Host "      kind create cluster --name observability-platform" -ForegroundColor Gray
    Write-Host "   3. 重新运行部署脚本" -ForegroundColor Gray
    exit 1
}

# Step 5: Verify connection
Write-Host "`n📋 Step 5: Verifying connection..." -ForegroundColor Yellow
$nodes = kubectl get nodes 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 成功连接到集群!" -ForegroundColor Green
    Write-Host "`n集群节点:" -ForegroundColor Cyan
    $nodes | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
} else {
    Write-Host "❌ 连接验证失败" -ForegroundColor Red
    exit 1
}

# Step 6: Check ArgoCD Applications
Write-Host "`n📋 Step 6: Checking ArgoCD Applications..." -ForegroundColor Yellow
$apps = kubectl get applications -n argocd 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ ArgoCD Applications:" -ForegroundColor Green
    $apps | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    
    # Check sync status
    $syncStatus = kubectl get application microservices -n argocd -o jsonpath='{.status.sync.status}' 2>&1
    if ($syncStatus) {
        Write-Host "`n   microservices 同步状态: $syncStatus" -ForegroundColor Cyan
    }
} else {
    Write-Host "⚠️  无法获取 ArgoCD Applications（可能 ArgoCD 未安装）" -ForegroundColor Yellow
}

# Step 7: Check Deployment images
Write-Host "`n📋 Step 7: Checking Deployment images..." -ForegroundColor Yellow
$userImage = kubectl get deployment user-service -n microservices -o jsonpath='{.spec.template.spec.containers[0].image}' 2>&1
if ($LASTEXITCODE -eq 0 -and $userImage) {
    Write-Host "   user-service 镜像: $userImage" -ForegroundColor Cyan
    if ($userImage -match "ghcr.io") {
        Write-Host "✅ 正在使用 GHCR 镜像" -ForegroundColor Green
    } else {
        Write-Host "⚠️  仍在使用本地镜像，可能需要 ArgoCD 同步" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  无法获取 Deployment 信息（可能未部署）" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✅ 集群连接修复完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n现在可以运行:" -ForegroundColor Yellow
Write-Host "   kubectl get pods -A" -ForegroundColor Gray
Write-Host "   kubectl get applications -n argocd" -ForegroundColor Gray
Write-Host "   kubectl get deployment user-service -n microservices" -ForegroundColor Gray
