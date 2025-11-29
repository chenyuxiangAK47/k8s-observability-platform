# 🚀 快速开始指南

> **5 分钟启动全链路可观测性平台**

---

## 📋 前置要求

- ✅ Docker Desktop（Windows/Mac）或 Docker Engine（Linux）
- ✅ Python 3.9+
- ✅ 8GB+ 内存（推荐）
- ✅ 10GB+ 磁盘空间

---

## 🎯 快速启动（3 步）

### Step 1: 启动基础设施

**Windows:**
```bash
start.bat
```

**Linux/Mac:**
```bash
chmod +x start.sh
./start.sh
```

**或者手动启动:**
```bash
docker-compose up -d
```

### Step 2: 安装 Python 依赖

```bash
cd services
pip install -r requirements.txt
```

### Step 3: 启动微服务

**终端 1 - 订单服务:**
```bash
cd services
python order_service/main.py
```

**终端 2 - 商品服务:**
```bash
cd services
python product_service/main.py
```

**终端 3 - 用户服务:**
```bash
cd services
python user_service/main.py
```

---

## 🌐 访问服务

| 服务 | 地址 | 默认账号 |
|------|------|---------|
| **Grafana** | http://localhost:3000 | admin/admin |
| **Prometheus** | http://localhost:9090 | - |
| **Jaeger** | http://localhost:16686 | - |
| **Loki** | http://localhost:3100 | - |

---

## 🧪 测试系统

### 1. 生成一些流量

```bash
# 使用 curl 或 Python requests
curl http://localhost:8000/orders/123
curl http://localhost:8001/products/1
curl http://localhost:8002/users/1

# 创建订单（会触发跨服务调用）
curl -X POST http://localhost:8000/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "product_id": 1}'
```

### 2. 查看 Grafana Dashboard

1. 访问 http://localhost:3000
2. 登录（admin/admin）
3. 进入 **Dashboards** → **Observability** → **Services Overview**

### 3. 查看 Jaeger 追踪

1. 访问 http://localhost:16686
2. 选择服务：`order-service`
3. 点击 **Find Traces**
4. 查看完整的调用链

### 4. 查看 Prometheus 指标

1. 访问 http://localhost:9090
2. 在查询框输入：`http_requests_total`
3. 点击 **Execute**

---

## 🔍 验证清单

- [ ] Docker 容器都在运行：`docker-compose ps`
- [ ] 微服务可以访问：`curl http://localhost:8000/health`
- [ ] Prometheus 能采集指标：访问 http://localhost:9090，查询 `up`
- [ ] Grafana 能显示 Dashboard
- [ ] Jaeger 能显示追踪
- [ ] 日志文件生成：`ls services/logs/`

---

## 🐛 常见问题

### Q: Docker 容器启动失败

**A:** 检查端口是否被占用：
```bash
# Windows
netstat -ano | findstr :3000

# Linux/Mac
lsof -i :3000
```

### Q: 微服务无法连接 Prometheus

**A:** 确保 Prometheus 容器已启动，检查网络配置：
```bash
docker network ls
docker network inspect observability-platform_observability
```

### Q: Grafana 显示 "No Data"

**A:** 
1. 检查 Prometheus 数据源配置
2. 确保微服务已启动并生成指标
3. 等待 1-2 分钟让数据采集

### Q: TraceID 无法关联

**A:** 确保 OpenTelemetry 配置正确，检查环境变量：
```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
```

---

## 📚 下一步

1. **阅读 README.md** - 了解项目架构
2. **阅读 INTERVIEW_TALKING_POINTS.md** - 准备面试话术
3. **阅读 PROJECT_ROADMAP.md** - 了解扩展计划
4. **自定义 Dashboard** - 在 Grafana 中创建自己的 Dashboard
5. **添加告警** - 配置告警规则和通知

---

## 💡 提示

- **首次启动**：等待 1-2 分钟让所有服务完全启动
- **查看日志**：`docker-compose logs -f [service_name]`
- **重启服务**：`docker-compose restart [service_name]`
- **停止所有**：`docker-compose down`

---

**祝你使用愉快！🎉**



