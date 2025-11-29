# 检查所有服务状态脚本

Write-Host "`n📊 服务状态检查" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# 检查 Docker 服务
Write-Host "`n🐳 Docker 服务状态:" -ForegroundColor Yellow
try {
    docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
} catch {
    Write-Host "  ❌ 无法获取 Docker 服务状态" -ForegroundColor Red
}

# 检查微服务
Write-Host "`n🐍 微服务状态:" -ForegroundColor Yellow
$services = @(
    @{Name="Order Service"; Port=8000; Url="http://localhost:8000/health"},
    @{Name="Product Service"; Port=8001; Url="http://localhost:8001/health"},
    @{Name="User Service"; Port=8002; Url="http://localhost:8002/health"}
)

foreach ($service in $services) {
    try {
        $response = Invoke-WebRequest -Uri $service.Url -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        $status = $response.StatusCode
        Write-Host "  ✅ $($service.Name) (端口 $($service.Port)): 运行正常 (HTTP $status)" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ $($service.Name) (端口 $($service.Port)): 未运行" -ForegroundColor Red
    }
}

# 检查进程
Write-Host "`n🔍 Python 进程:" -ForegroundColor Yellow
$pythonProcesses = Get-Process | Where-Object {
    $_.ProcessName -eq "python" -or $_.ProcessName -eq "py"
} | Where-Object {
    $_.Path -like "*services*" -or 
    $_.CommandLine -like "*order_service*" -or
    $_.CommandLine -like "*product_service*" -or
    $_.CommandLine -like "*user_service*"
}

if ($pythonProcesses) {
    $pythonProcesses | Format-Table Id, ProcessName, @{Label="CPU"; Expression={$_.CPU}}, @{Label="Memory(MB)"; Expression={[math]::Round($_.WorkingSet64/1MB, 2)}} -AutoSize
} else {
    Write-Host "  ⚠️  没有找到运行中的微服务进程" -ForegroundColor Yellow
}

Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
Write-Host "`n按任意键退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")


