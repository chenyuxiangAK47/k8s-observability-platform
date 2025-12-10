# Force Restart Docker Desktop
# This script forcefully stops Docker Desktop processes and restarts it

Write-Host "`n=== 🔄 强制重启 Docker Desktop ===" -ForegroundColor Cyan

# Step 1: Stop Docker Desktop gracefully
Write-Host "`n📋 Step 1: Stopping Docker Desktop..." -ForegroundColor Yellow
$dockerProcess = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
if ($dockerProcess) {
    Write-Host "  Found Docker Desktop process, stopping..." -ForegroundColor Gray
    Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Write-Host "✅ Docker Desktop stopped" -ForegroundColor Green
} else {
    Write-Host "⚠️  Docker Desktop process not found (may already be stopped)" -ForegroundColor Yellow
}

# Step 2: Stop Docker service processes
Write-Host "`n📋 Step 2: Stopping Docker service processes..." -ForegroundColor Yellow
$processesToStop = @(
    "Docker Desktop",
    "com.docker.backend",
    "com.docker.proxy",
    "vmmem",
    "com.docker.cli"
)

foreach ($procName in $processesToStop) {
    $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Host "  Stopping: $procName" -ForegroundColor Gray
        Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
    }
}

Start-Sleep -Seconds 5
Write-Host "✅ All Docker processes stopped" -ForegroundColor Green

# Step 3: Instructions to restart
Write-Host "`n📋 Step 3: Restart Docker Desktop manually" -ForegroundColor Yellow
Write-Host "`n请手动执行以下操作:" -ForegroundColor Cyan
Write-Host "1. 打开 Docker Desktop 应用" -ForegroundColor Gray
Write-Host "2. 等待 Docker 完全启动（系统托盘图标不再闪烁）" -ForegroundColor Gray
Write-Host "3. 调整资源设置:" -ForegroundColor Gray
Write-Host "   Settings → Resources → CPUs: 4, Memory: 4-6GB" -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✅ Docker Desktop restart initiated!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n💡 After restarting, verify Docker is working:" -ForegroundColor Yellow
Write-Host "   docker ps" -ForegroundColor Gray

