# Emergency Stop: Stop all Kind clusters to free resources
# This script forcefully stops all Kind clusters to prevent Docker Desktop crash

Write-Host "`n=== 🚨 紧急停止集群（释放资源）===" -ForegroundColor Red

# Step 1: List all Kind clusters
Write-Host "`n📋 Step 1: Listing all Kind clusters..." -ForegroundColor Yellow
$clusters = kind get clusters 2>&1
if ($LASTEXITCODE -eq 0 -and $clusters) {
    Write-Host "Found clusters:" -ForegroundColor Cyan
    $clusters | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
} else {
    Write-Host "⚠️  Cannot list clusters (Docker may be down)" -ForegroundColor Yellow
    Write-Host "Trying to find and stop containers directly..." -ForegroundColor Gray
}

# Step 2: Stop all Kind cluster containers
Write-Host "`n📋 Step 2: Stopping all Kind cluster containers..." -ForegroundColor Yellow
$kindContainers = docker ps -a --filter "label=io.x-k8s.kind.cluster" --format "{{.Names}}" 2>&1
if ($LASTEXITCODE -eq 0 -and $kindContainers) {
    $kindContainers | ForEach-Object {
        Write-Host "  Stopping container: $_" -ForegroundColor Gray
        docker stop $_ 2>&1 | Out-Null
        docker rm $_ 2>&1 | Out-Null
    }
    Write-Host "✅ All Kind containers stopped and removed" -ForegroundColor Green
} else {
    Write-Host "⚠️  No Kind containers found or Docker is not accessible" -ForegroundColor Yellow
}

# Step 3: Delete all Kind clusters
Write-Host "`n📋 Step 3: Deleting all Kind clusters..." -ForegroundColor Yellow
if ($clusters) {
    $clusters | ForEach-Object {
        $clusterName = $_.Trim()
        if ($clusterName) {
            Write-Host "  Deleting cluster: $clusterName" -ForegroundColor Gray
            kind delete cluster --name $clusterName 2>&1 | Out-Null
        }
    }
    Write-Host "✅ All Kind clusters deleted" -ForegroundColor Green
} else {
    Write-Host "⚠️  Cannot delete clusters (may already be deleted)" -ForegroundColor Yellow
}

# Step 4: Stop all running containers (optional, be careful)
Write-Host "`n📋 Step 4: Checking running containers..." -ForegroundColor Yellow
$runningContainers = docker ps --format "{{.Names}}" 2>&1
if ($LASTEXITCODE -eq 0 -and $runningContainers) {
    Write-Host "Running containers:" -ForegroundColor Cyan
    $runningContainers | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    Write-Host "`n⚠️  These containers are still running. Stop them manually if needed:" -ForegroundColor Yellow
    Write-Host "   docker stop <container-name>" -ForegroundColor Gray
} else {
    Write-Host "✅ No running containers" -ForegroundColor Green
}

# Step 5: Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✅ Emergency Stop Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n📊 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Wait 30 seconds for resources to free up" -ForegroundColor Gray
Write-Host "2. Check Task Manager - CPU should drop significantly" -ForegroundColor Gray
Write-Host "3. Restart Docker Desktop" -ForegroundColor Gray
Write-Host "4. Adjust Docker Desktop resources:" -ForegroundColor Gray
Write-Host "   Settings → Resources → CPUs: 4, Memory: 4-6GB" -ForegroundColor Gray

Write-Host "`n💡 To recreate cluster with lighter config:" -ForegroundColor Cyan
Write-Host "   .\scripts\setup-lightweight-cluster.ps1" -ForegroundColor Gray

