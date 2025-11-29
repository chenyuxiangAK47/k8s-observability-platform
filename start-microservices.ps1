# Windows PowerShell 启动微服务脚本
# 在三个独立的 PowerShell 窗口中启动微服务

Write-Host "🚀 启动微服务..." -ForegroundColor Green

# 检查是否在项目根目录
if (-not (Test-Path "services\order_service\main.py")) {
    Write-Host "❌ 未找到微服务文件，请确保在项目根目录运行此脚本" -ForegroundColor Red
    pause
    exit 1
}

# 检查 Python 依赖
Write-Host "`n📦 检查 Python 依赖..." -ForegroundColor Yellow
$requirementsPath = "services\requirements.txt"
if (-not (Test-Path $requirementsPath)) {
    Write-Host "❌ 未找到 requirements.txt" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "💡 提示：如果还没安装依赖，请先运行: cd services; pip install -r requirements.txt" -ForegroundColor Yellow

# 创建日志目录
if (-not (Test-Path "services\logs")) {
    New-Item -ItemType Directory -Path "services\logs" | Out-Null
}

Write-Host "`n🌐 启动微服务（每个服务会在新窗口中打开）..." -ForegroundColor Yellow

# 启动订单服务
Write-Host "  启动 Order Service (端口 8000)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\services'; python order_service\main.py"

Start-Sleep -Seconds 2

# 启动商品服务
Write-Host "  启动 Product Service (端口 8001)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\services'; python product_service\main.py"

Start-Sleep -Seconds 2

# 启动用户服务
Write-Host "  启动 User Service (端口 8002)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\services'; python user_service\main.py"

Write-Host "`n✅ 所有微服务已启动！" -ForegroundColor Green
Write-Host "`n📊 服务地址：" -ForegroundColor Cyan
Write-Host "  - Order Service:   http://localhost:8000" -ForegroundColor White
Write-Host "  - Product Service: http://localhost:8001" -ForegroundColor White
Write-Host "  - User Service:    http://localhost:8002" -ForegroundColor White

Write-Host "`n💡 测试服务：" -ForegroundColor Yellow
Write-Host "  curl http://localhost:8000/health" -ForegroundColor Gray
Write-Host "  curl http://localhost:8001/health" -ForegroundColor Gray
Write-Host "  curl http://localhost:8002/health" -ForegroundColor Gray

Write-Host "`n按任意键退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")



