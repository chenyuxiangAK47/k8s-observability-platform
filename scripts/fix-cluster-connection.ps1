# Fix Kubernetes Cluster Connection Issues - Windows PowerShell

Write-Host "🔧 Diagnosing and fixing Kubernetes cluster connection issues..." -ForegroundColor Yellow
Write-Host ""

# Step 1: Check Docker status
Write-Host "Step 1: Checking Docker status..." -ForegroundColor Cyan
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Docker is running" -ForegroundColor Green
    } else {
        Write-Host "❌ Docker is not responding properly" -ForegroundColor Red
        Write-Host "   Please restart Docker Desktop and try again" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "❌ Docker is not accessible" -ForegroundColor Red
    Write-Host "   Please ensure Docker Desktop is running" -ForegroundColor Yellow
    exit 1
}

# Step 2: Check cluster container
Write-Host "`nStep 2: Checking cluster container..." -ForegroundColor Cyan
$clusterContainer = docker ps -a --filter "name=observability-platform-control-plane" --format "{{.Names}} {{.Status}}" 2>&1
if ($clusterContainer -match "observability-platform") {
    Write-Host "✅ Cluster container found: $clusterContainer" -ForegroundColor Green
    
    # Check if container is running
    if ($clusterContainer -match "Up") {
        Write-Host "✅ Container is running" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Container is not running, attempting to start..." -ForegroundColor Yellow
        docker start observability-platform-control-plane 2>&1 | Out-Null
        Start-Sleep -Seconds 10
    }
} else {
    Write-Host "❌ Cluster container not found" -ForegroundColor Red
    Write-Host "   You may need to recreate the cluster:" -ForegroundColor Yellow
    Write-Host "   kind create cluster --name observability-platform" -ForegroundColor White
    exit 1
}

# Step 3: Wait for API server to be ready
Write-Host "`nStep 3: Waiting for API server to be ready..." -ForegroundColor Cyan
$maxAttempts = 10
$attempt = 0
$apiReady = $false

while ($attempt -lt $maxAttempts -and -not $apiReady) {
    $attempt++
    Write-Host "   Attempt $attempt/$maxAttempts..." -ForegroundColor Gray
    
    try {
        $result = kubectl get nodes --request-timeout=5s 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ API server is responding!" -ForegroundColor Green
            $apiReady = $true
            break
        }
    } catch {
        # Continue trying
    }
    
    if (-not $apiReady) {
        Start-Sleep -Seconds 5
    }
}

if (-not $apiReady) {
    Write-Host "`n⚠️  API server is still not responding" -ForegroundColor Yellow
    Write-Host "   This might be due to:" -ForegroundColor Yellow
    Write-Host "   1. Docker Desktop resource constraints" -ForegroundColor White
    Write-Host "   2. System resource exhaustion" -ForegroundColor White
    Write-Host "   3. Network issues" -ForegroundColor White
    Write-Host ""
    Write-Host "   Recommended actions:" -ForegroundColor Cyan
    Write-Host "   1. Restart Docker Desktop" -ForegroundColor White
    Write-Host "   2. Increase Docker Desktop memory allocation (Settings > Resources)" -ForegroundColor White
    Write-Host "   3. Close other resource-intensive applications" -ForegroundColor White
    Write-Host "   4. Recreate the cluster if problem persists:" -ForegroundColor White
    Write-Host "      kind delete cluster --name observability-platform" -ForegroundColor Gray
    Write-Host "      .\scripts\setup-and-deploy.ps1" -ForegroundColor Gray
    exit 1
}

# Step 4: Verify cluster connectivity
Write-Host "`nStep 4: Verifying cluster connectivity..." -ForegroundColor Cyan
kubectl cluster-info --request-timeout=10s 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Cluster is accessible" -ForegroundColor Green
} else {
    Write-Host "⚠️  Cluster info check failed, but API server is responding" -ForegroundColor Yellow
}

# Step 5: Check node status
Write-Host "`nStep 5: Checking node status..." -ForegroundColor Cyan
kubectl get nodes --request-timeout=10s 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Nodes are accessible" -ForegroundColor Green
    kubectl get nodes
} else {
    Write-Host "⚠️  Could not get node status" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ Connection fix completed!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 If you still experience issues:" -ForegroundColor Cyan
Write-Host "   - Try: kubectl get pods -A --request-timeout=30s" -ForegroundColor White
Write-Host "   - Check Docker Desktop resource usage" -ForegroundColor White
Write-Host "   - Consider restarting Docker Desktop" -ForegroundColor White

