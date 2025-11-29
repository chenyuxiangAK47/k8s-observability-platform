# 🔍 全链路可观测性平台使用指南

> **Windows 用户专用快速指南**

---

## 🚀 一键启动（最简单）

### 方式1：使用启动脚本（推荐）

```powershell
# 启动所有服务
.\start-all.ps1

# 停止所有服务  
.\stop-all.ps1

# 查看服务状态
.\check-status.ps1
```

就这么简单！脚本会自动：
- ✅ 检查 Docker Desktop 是否运行
- ✅ 启动所有 Docker 服务（Prometheus、Grafana、Loki、Jaeger）
- ✅ 检查并安装 Python 依赖
- ✅ 后台启动所有微服务
- ✅ 检查服务状态

---

## 📋 启动前检查

1. **Docker Desktop 必须运行**
   - 打开 Docker Desktop 应用
   - 等待右下角图标不再闪烁
   - 运行 `docker info` 确认

2. **Python 3.9+ 已安装**
   - 运行 `py --version` 确认

3. **在项目根目录**
   - 确保有 `docker-compose.yml` 文件

---

## 🐛 常见问题

### Q: 启动脚本报错 "Docker Desktop 未运行"

**A:** 
1. 打开 Docker Desktop
2. 等待完全启动（图标不再闪烁）
3. 重新运行 `.\start-all.ps1`

### Q: 微服务启动失败

**A:**
1. 检查 Python 依赖：`cd services; pip install -r requirements.txt`
2. 手动启动一个服务查看错误：`py order_service\main.py`
3. 检查端口是否被占用：`netstat -ano | findstr :8000`

### Q: 端口被占用

**A:**
```powershell
# 查看端口占用
netstat -ano | findstr :3000
netstat -ano | findstr :8000

# 停止占用端口的进程（替换 PID）
taskkill /PID <进程ID> /F
```

### Q: 如何查看微服务日志？

**A:**
- 日志文件：`services\logs\*.log`
- 或者手动启动服务查看控制台输出

---

## 📊 服务说明

### Docker 服务（后台运行）

- **Prometheus**: 指标采集和存储
- **Grafana**: 可视化 Dashboard
- **Loki**: 日志聚合
- **Jaeger**: 分布式追踪
- **Alertmanager**: 告警管理

### 微服务（Python FastAPI）

- **Order Service** (8000): 订单服务
- **Product Service** (8001): 商品服务  
- **User Service** (8002): 用户服务

---

## 🧪 测试服务

```powershell
# 测试健康检查
Invoke-WebRequest http://localhost:8000/health
Invoke-WebRequest http://localhost:8001/health
Invoke-WebRequest http://localhost:8002/health

# 或使用浏览器访问
# http://localhost:8000/health
```

---

## 🛑 停止服务

### 方式1：使用脚本（推荐）

```powershell
.\stop-all.ps1
```

### 方式2：手动停止

```powershell
# 停止 Docker 服务
docker-compose down

# 停止微服务（在任务管理器中结束 Python 进程）
# 或使用 stop-all.ps1
```

---

## 💡 提示

- 首次启动可能需要几分钟下载 Docker 镜像
- 微服务启动后需要几秒才能响应请求
- 如果服务未启动，检查 `services\logs\` 目录的日志文件
- 建议使用 `check-status.ps1` 定期检查服务状态

---

**祝你使用愉快！🎉**


