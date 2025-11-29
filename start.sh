#!/bin/bash

# 全链路可观测性平台启动脚本

echo "🚀 启动全链路可观测性平台..."

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker 未运行，请先启动 Docker"
    exit 1
fi

# 创建必要的目录
mkdir -p services/logs
mkdir -p grafana/dashboards

# 启动 Docker Compose 服务
echo "📦 启动 Prometheus, Grafana, Loki, Jaeger..."
docker-compose up -d

# 等待服务启动
echo "⏳ 等待服务启动..."
sleep 10

# 检查服务状态
echo "🔍 检查服务状态..."
docker-compose ps

echo ""
echo "✅ 服务启动完成！"
echo ""
echo "📊 访问地址："
echo "  - Grafana:     http://localhost:3000 (admin/admin)"
echo "  - Prometheus:  http://localhost:9090"
echo "  - Jaeger:      http://localhost:16686"
echo "  - Loki:        http://localhost:3100"
echo ""
echo "💡 下一步："
echo "  1. 安装 Python 依赖: cd services && pip install -r requirements.txt"
echo "  2. 启动微服务: python order_service/main.py &"
echo "  3. 在 Grafana 中查看 Dashboard"
echo ""


