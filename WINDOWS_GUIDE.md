# 🪟 Windows 使用指南

> **Windows PowerShell 专用指南**

---

## ⚠️ 常见问题

### 1. Docker Desktop 未启动

**错误信息：**
```
ERROR: error during connect: Get "http://%2F%2F.%2Fpipe%2FdockerDesktopLinuxEngine/v1.48/info"
```

**解决方法：**
1. 打开 **Docker Desktop** 应用
2. 等待 Docker 完全启动（右下角图标不再闪烁）
3. 重新运行命令

---

### 2. PowerShell 语法问题

**问题：** PowerShell 不支持 `&&` 和 `&` 语法

**错误示例：**
```powershell
cd services && pip install -r requirements.txt  # ❌ 不支持 &&
python main.py &  # ❌ 不支持 &
```

**正确写法：**
```powershell
# 方法1：分两行
cd services
pip install -r requirements.txt

# 方法2：使用分号
cd services; pip install -r requirements.txt

# 方法3：使用 Start-Process（后台运行）
Start-Process python -ArgumentList "main.py"
```

---

## 🚀 快速启动（Windows 方式）

### 方法1：使用 PowerShell 脚本（推荐）

**Step 1: 启动基础设施**
```powershell
# 右键点击 start-services.ps1，选择"使用 PowerShell 运行"
# 或者：
.\start-services.ps1
```

**Step 2: 安装 Python 依赖**
```powershell
cd services
pip install -r requirements.txt
```

**Step 3: 启动微服务**
```powershell
# 回到项目根目录
cd ..

# 使用脚本启动（会在新窗口中打开）
.\start-microservices.ps1

# 或者手动启动（每个服务需要新窗口）
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\services'; python order_service\main.py"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\services'; python product_service\main.py"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\services'; python user_service\main.py"
```

---

### 方法2：手动启动（一步步来）

**Step 1: 检查 Docker Desktop**
```powershell
docker info
# 如果报错，先启动 Docker Desktop
```

**Step 2: 启动 Docker Compose**
```powershell
docker-compose up -d
```

**Step 3: 检查服务状态**
```powershell
docker-compose ps
```

**Step 4: 安装 Python 依赖**
```powershell
cd services
pip install -r requirements.txt
cd ..
```

**Step 5: 启动微服务（需要3个 PowerShell 窗口）**

**窗口1 - Order Service:**
```powershell
cd services
python order_service\main.py
```

**窗口2 - Product Service:**
```powershell
cd services
python product_service\main.py
```

**窗口3 - User Service:**
```powershell
cd services
python user_service\main.py
```

---

## 🧪 测试服务

### 使用 PowerShell 测试

```powershell
# 测试健康检查
Invoke-WebRequest -Uri http://localhost:8000/health
Invoke-WebRequest -Uri http://localhost:8001/health
Invoke-WebRequest -Uri http://localhost:8002/health

# 或者使用 curl（如果安装了）
curl http://localhost:8000/health
```

### 使用浏览器测试

直接访问：
- Order Service: http://localhost:8000/health
- Product Service: http://localhost:8001/health
- User Service: http://localhost:8002/health

---

## 📊 访问监控服务

| 服务 | 地址 | 账号 |
|------|------|------|
| Grafana | http://localhost:3000 | admin/admin |
| Prometheus | http://localhost:9090 | - |
| Jaeger | http://localhost:16686 | - |

---

## 🛑 停止服务

### 停止 Docker 服务
```powershell
docker-compose down
```

### 停止微服务
在每个微服务的 PowerShell 窗口中按 `Ctrl+C`

---

## 🔧 故障排查

### 问题1: 端口被占用

**检查端口：**
```powershell
netstat -ano | findstr :3000
netstat -ano | findstr :8000
```

**解决方法：**
- 修改 `docker-compose.yml` 中的端口映射
- 或者停止占用端口的程序

### 问题2: Python 模块未找到

**错误：**
```
ModuleNotFoundError: No module named 'fastapi'
```

**解决方法：**
```powershell
cd services
pip install -r requirements.txt
```

### 问题3: 无法连接到 Docker

**检查 Docker Desktop：**
1. 打开 Docker Desktop
2. 查看状态是否显示 "Running"
3. 尝试重启 Docker Desktop

---

## 💡 PowerShell 常用命令

```powershell
# 查看当前目录
Get-Location
# 或
pwd

# 切换目录
Set-Location services
# 或
cd services

# 列出文件
Get-ChildItem
# 或
ls

# 检查文件是否存在
Test-Path "docker-compose.yml"

# 创建目录
New-Item -ItemType Directory -Path "logs"

# 后台运行程序（新窗口）
Start-Process python -ArgumentList "main.py"
```

---

## ✅ 检查清单

启动前确保：
- [ ] Docker Desktop 已启动并运行
- [ ] 在项目根目录（有 docker-compose.yml）
- [ ] Python 3.9+ 已安装
- [ ] 端口 3000, 8000, 8001, 8002 未被占用

---

**祝你使用愉快！🎉**



