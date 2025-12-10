# Docker Desktop 错误修复指南

## 🔴 错误信息

```
An unexpected error occurred
Docker Desktop encountered an unexpected error and needs to close.

com.docker.build: exit status 1
```

## 📋 问题分析

这个错误表示 Docker Desktop 的构建服务（`com.docker.build`）崩溃了。常见原因：

1. **Docker Desktop 内部错误**
   - 缓存损坏
   - 配置文件冲突
   - 资源不足

2. **系统资源问题**
   - 内存不足
   - 磁盘空间不足
   - CPU 过载

3. **Windows 兼容性问题**
   - WSL 2 配置问题
   - Hyper-V 冲突
   - 防火墙/安全软件干扰

---

## ✅ 解决方案（按优先级）

### 方法 1: 重置到出厂设置（最简单，推荐）

1. **完全关闭 Docker Desktop**
   - 右键系统托盘图标 → Quit Docker Desktop
   - 等待 10 秒

2. **重新启动 Docker Desktop**

3. **如果错误仍然出现，执行重置：**
   - 打开 Docker Desktop
   - 点击 **Settings** (设置) ⚙️
   - 点击 **Troubleshoot** (故障排除)
   - 点击 **Reset to factory defaults** (重置到出厂设置)
   - 确认重置

4. **重置后重新创建集群：**
   ```powershell
   # 重新创建 Kind 集群
   kind create cluster --name observability-platform
   
   # 重新部署所有组件
   .\scripts\setup-and-deploy.ps1
   ```

**⚠️ 注意：** 重置会删除所有容器、镜像和数据！

---

### 方法 2: 清理 Docker Desktop 缓存

1. **完全关闭 Docker Desktop**

2. **删除缓存文件夹：**
   ```powershell
   # 删除用户配置
   Remove-Item -Recurse -Force "$env:APPDATA\Docker" -ErrorAction SilentlyContinue
   
   # 删除本地数据
   Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Docker" -ErrorAction SilentlyContinue
   
   # 删除程序数据
   Remove-Item -Recurse -Force "$env:PROGRAMDATA\Docker" -ErrorAction SilentlyContinue
   ```

3. **重新启动 Docker Desktop**

---

### 方法 3: 重新安装 Docker Desktop

1. **卸载 Docker Desktop**
   - 控制面板 → 程序和功能 → 卸载 Docker Desktop

2. **清理残留文件：**
   ```powershell
   # 删除所有 Docker 相关文件夹
   Remove-Item -Recurse -Force "$env:APPDATA\Docker" -ErrorAction SilentlyContinue
   Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Docker" -ErrorAction SilentlyContinue
   Remove-Item -Recurse -Force "$env:PROGRAMDATA\Docker" -ErrorAction SilentlyContinue
   ```

3. **重新下载并安装 Docker Desktop**
   - 从官网下载：https://www.docker.com/products/docker-desktop
   - 安装后重启电脑

4. **重新创建集群：**
   ```powershell
   kind create cluster --name observability-platform
   .\scripts\setup-and-deploy.ps1
   ```

---

### 方法 4: 检查系统资源

```powershell
# 检查内存使用
Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory

# 检查磁盘空间
Get-PSDrive C | Select-Object Used, Free

# 检查 Docker Desktop 资源限制
# Docker Desktop → Settings → Resources
```

**建议：**
- 确保至少有 4GB 可用内存
- 确保至少有 10GB 可用磁盘空间
- 在 Docker Desktop Settings → Resources 中调整资源分配

---

### 方法 5: 使用 WSL 2 后端

1. **确保已安装 WSL 2：**
   ```powershell
   wsl --list --verbose
   # 应该显示 WSL 2 版本
   ```

2. **在 Docker Desktop 中启用 WSL 2：**
   - Docker Desktop → Settings → General
   - 勾选 **"Use the WSL 2 based engine"**
   - 点击 **Apply & Restart**

3. **如果 WSL 2 未安装，安装它：**
   ```powershell
   # 以管理员身份运行 PowerShell
   wsl --install
   # 重启电脑
   ```

---

### 方法 6: 收集诊断信息

如果以上方法都失败：

1. **在错误对话框中点击 "Gather diagnostics"**

2. **将诊断报告发送给：**
   - Docker 支持：https://www.docker.com/support/
   - GitHub Issues：https://github.com/docker/for-win/issues

3. **同时提供以下信息：**
   - Windows 版本：`winver`
   - Docker Desktop 版本
   - 错误发生时的操作
   - 系统资源使用情况

---

## 🔧 快速修复脚本

运行以下脚本进行自动诊断：

```powershell
.\scripts\fix-docker-desktop.ps1
```

---

## 📋 验证修复

修复后，验证 Docker Desktop 是否正常工作：

```powershell
# 1. 检查 Docker 是否运行
docker ps
# 应该能正常执行，不报错

# 2. 检查 Docker 版本
docker --version

# 3. 检查 Kind 集群
kind get clusters

# 4. 如果集群不存在，重新创建
kind create cluster --name observability-platform
```

---

## ⚠️ 重要提示

### 重置/重新安装后的影响

重置或重新安装 Docker Desktop 会删除：
- ✅ 所有容器（包括 Kind 集群）
- ✅ 所有镜像
- ✅ 所有卷和数据
- ✅ 所有网络配置

### 需要重新执行的操作

1. **重新创建集群：**
   ```powershell
   kind create cluster --name observability-platform
   ```

2. **重新部署所有组件：**
   ```powershell
   .\scripts\setup-and-deploy.ps1
   ```

3. **重新加载镜像（如果有本地构建的）：**
   ```powershell
   # 重新构建镜像
   docker build -t user-service:latest ./services/user-service
   docker build -t product-service:latest ./services/product-service
   docker build -t order-service:latest ./services/order-service
   
   # 加载到 Kind
   kind load docker-image user-service:latest --name observability-platform
   kind load docker-image product-service:latest --name observability-platform
   kind load docker-image order-service:latest --name observability-platform
   ```

---

## 💡 预防措施

1. **定期更新 Docker Desktop**
   - 保持最新版本可以避免已知 bug

2. **监控资源使用**
   - 不要同时运行太多容器
   - 定期清理未使用的镜像和容器

3. **备份重要数据**
   - 如果集群中有重要数据，定期备份
   - 使用 `kubectl get all -A -o yaml > backup.yaml` 备份配置

---

## 🆘 如果所有方法都失败

1. **检查 Windows 事件查看器**
   - 查看是否有系统级错误

2. **检查防病毒软件**
   - 某些防病毒软件可能干扰 Docker
   - 尝试临时禁用后测试

3. **联系 Docker 支持**
   - 提供完整的诊断报告
   - 描述所有尝试过的修复方法

---

## 📞 需要帮助？

如果问题持续存在，请提供：

1. Docker Desktop 版本
2. Windows 版本：`winver`
3. 完整的错误信息（截图）
4. 诊断报告（如果已收集）
5. 已尝试的修复方法

