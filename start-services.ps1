# Windows PowerShell 启动脚本
# 全链路可观测性平台启动脚本

Write-Host "🚀 启动全链路可观测性平台..." -ForegroundColor Green

# 检查 Docker 是否运行
Write-Host "`n📦 检查 Docker Desktop..." -ForegroundColor Yellow
try {
    docker info | Out-Null
    Write-Host "✅ Docker Desktop 正在运行" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker Desktop 未运行！" -ForegroundColor Red
    Write-Host "请先启动 Docker Desktop，然后重新运行此脚本" -ForegroundColor Yellow
    pause
    exit 1
}

# 检查是否在项目根目录
if (-not (Test-Path "docker-compose.yml")) {
    Write-Host "❌ 未找到 docker-compose.yml，请确保在项目根目录运行此脚本" -ForegroundColor Red
    pause
    exit 1
}

# 创建必要的目录
Write-Host "`n📁 创建必要的目录..." -ForegroundColor Yellow
if (-not (Test-Path "services\logs")) {
    New-Item -ItemType Directory -Path "services\logs" | Out-Null
}
if (-not (Test-Path "grafana\dashboards")) {
    New-Item -ItemType Directory -Path "grafana\dashboards" | Out-Null
}

# 启动 Docker Compose 服务
Write-Host "`n🐳 启动 Docker Compose 服务..." -ForegroundColor Yellow
docker-compose up -d

# 等待服务启动
Write-Host "`n⏳ 等待服务启动（10秒）..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# 检查服务状态
Write-Host "`n🔍 检查服务状态..." -ForegroundColor Yellow
docker-compose ps

Write-Host "`n✅ 基础设施启动完成！" -ForegroundColor Green
Write-Host "`n📊 访问地址：" -ForegroundColor Cyan
Write-Host "  - Grafana:     http://localhost:3000 (admin/admin)" -ForegroundColor White
Write-Host "  - Prometheus:  http://localhost:9090" -ForegroundColor White
Write-Host "  - Jaeger:      http://localhost:16686" -ForegroundColor White
Write-Host "  - Loki:        http://localhost:3100" -ForegroundColor White

Write-Host "`n💡 下一步：" -ForegroundColor Yellow
Write-Host "  1. 安装 Python 依赖: cd services; pip install -r requirements.txt" -ForegroundColor White
Write-Host "  2. 启动微服务（在新的 PowerShell 窗口中）:" -ForegroundColor White
Write-Host "     - python services\order_service\main.py" -ForegroundColor Gray
Write-Host "     - python services\product_service\main.py" -ForegroundColor Gray
Write-Host "     - python services\user_service\main.py" -ForegroundColor Gray
Write-Host "  3. 在 Grafana 中查看 Dashboard" -ForegroundColor White

Write-Host "`n按任意键退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")


