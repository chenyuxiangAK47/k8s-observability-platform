@echo off
REM 全链路可观测性平台启动脚本 (Windows)

echo 🚀 启动全链路可观测性平台...

REM 检查 Docker 是否运行
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker 未运行，请先启动 Docker Desktop
    pause
    exit /b 1
)

REM 创建必要的目录
if not exist "services\logs" mkdir services\logs
if not exist "grafana\dashboards" mkdir grafana\dashboards

REM 启动 Docker Compose 服务
echo 📦 启动 Prometheus, Grafana, Loki, Jaeger...
docker-compose up -d

REM 等待服务启动
echo ⏳ 等待服务启动...
timeout /t 10 /nobreak >nul

REM 检查服务状态
echo 🔍 检查服务状态...
docker-compose ps

echo.
echo ✅ 服务启动完成！
echo.
echo 📊 访问地址：
echo   - Grafana:     http://localhost:3000 (admin/admin)
echo   - Prometheus:  http://localhost:9090
echo   - Jaeger:      http://localhost:16686
echo   - Loki:        http://localhost:3100
echo.
echo 💡 下一步：
echo   1. 安装 Python 依赖: cd services ^&^& pip install -r requirements.txt
echo   2. 启动微服务: python order_service\main.py
echo   3. 在 Grafana 中查看 Dashboard
echo.

pause



