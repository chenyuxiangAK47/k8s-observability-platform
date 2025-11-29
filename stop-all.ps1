# 停止所有服务脚本

Write-Host "`n🛑 停止所有服务..." -ForegroundColor Yellow

# 停止微服务
Write-Host "`n🐍 停止微服务..." -ForegroundColor Cyan
if (Test-Path ".service-pids.txt") {
    $pids = Get-Content ".service-pids.txt" | Where-Object { $_ -match '^\d+$' }
    foreach ($pid in $pids) {
        try {
            Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            Write-Host "  ✅ 已停止进程 PID: $pid" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠️  进程 PID $pid 不存在或已停止" -ForegroundColor Yellow
        }
    }
    Remove-Item ".service-pids.txt" -ErrorAction SilentlyContinue
} else {
    # 尝试通过进程名停止
    $processes = Get-Process | Where-Object {
        ($_.ProcessName -eq "python" -or $_.ProcessName -eq "py") -and
        ($_.CommandLine -like "*order_service*" -or 
         $_.CommandLine -like "*product_service*" -or 
         $_.CommandLine -like "*user_service*")
    }
    if ($processes) {
        $processes | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host "  ✅ 已停止微服务进程" -ForegroundColor Green
    } else {
        Write-Host "  ✓ 没有运行中的微服务" -ForegroundColor Gray
    }
}

# 停止 Docker 服务
Write-Host "`n🐳 停止 Docker 服务..." -ForegroundColor Cyan
try {
    docker-compose down
    Write-Host "  ✅ Docker 服务已停止" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  Docker 服务停止失败或未运行" -ForegroundColor Yellow
}

Write-Host "`n✅ 所有服务已停止" -ForegroundColor Green
Write-Host "`n按任意键退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

