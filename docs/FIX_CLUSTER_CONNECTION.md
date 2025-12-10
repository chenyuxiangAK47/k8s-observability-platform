# 修复集群连接问题指南

## 🔍 问题诊断

如果遇到 `TLS handshake timeout` 或 `Unable to connect to the server` 错误，按以下步骤诊断：

### 1. 检查 Docker Desktop 状态

```powershell
# 检查 Docker 是否运行
docker ps

# 如果失败，说明 Docker Desktop 未启动或有问题
```

**解决方案：**
- 完全关闭 Docker Desktop（右键系统托盘图标 → Quit Docker Desktop）
- 等待 10 秒
- 重新启动 Docker Desktop
- 等待 Docker 完全启动（系统托盘图标不再闪烁）

### 2. 检查 Kind 集群容器

```powershell
# 检查容器状态
docker ps -a | Select-String "observability-platform"

# 如果容器状态是 "Exited"，需要启动它
docker start observability-platform-control-plane

# 等待 10-15 秒让容器完全启动
Start-Sleep -Seconds 15
```

### 3. 重新配置 kubeconfig

```powershell
# 重新导出 kubeconfig
kind export kubeconfig --name observability-platform

# 验证连接
kubectl get nodes
```

### 4. 如果以上都失败，重启集群

```powershell
# 删除集群
kind delete cluster --name observability-platform

# 重新创建集群（这会丢失所有数据）
kind create cluster --name observability-platform

# 然后重新运行部署脚本
.\scripts\setup-and-deploy.ps1
```

---

## 🚨 常见错误和解决方案

### 错误 1: `TLS handshake timeout`

**原因：** Kubernetes API server 未响应

**解决：**
1. 重启 Docker Desktop
2. 重启 Kind 容器：`docker restart observability-platform-control-plane`
3. 等待 15-30 秒
4. 重新配置 kubeconfig：`kind export kubeconfig --name observability-platform`

### 错误 2: `500 Internal Server Error` (Docker API)

**原因：** Docker Desktop 内部错误

**解决：**
1. 完全关闭 Docker Desktop
2. 等待 30 秒
3. 重新启动 Docker Desktop
4. 等待完全启动后重试

### 错误 3: `Unable to connect to the server: dial tcp 127.0.0.1:51411`

**原因：** kubeconfig 中的端口已失效

**解决：**
```powershell
# 重新导出 kubeconfig
kind export kubeconfig --name observability-platform

# 验证
kubectl get nodes
```

### 错误 4: `container not found` 或 `cluster not found`

**原因：** 集群容器被删除或未创建

**解决：**
```powershell
# 检查是否存在
kind get clusters

# 如果不存在，重新创建
kind create cluster --name observability-platform
```

---

## ✅ 快速修复脚本

如果上述步骤都失败，使用以下一键修复：

```powershell
# 1. 重启 Docker Desktop（手动操作）
# 右键系统托盘 → Quit Docker Desktop
# 等待 10 秒后重新启动

# 2. 等待 Docker 完全启动后运行
.\scripts\quick-fix-cluster.ps1

# 3. 如果还是失败，重新创建集群
kind delete cluster --name observability-platform
kind create cluster --name observability-platform
.\scripts\setup-and-deploy.ps1
```

---

## 📋 验证清单

修复后，运行以下命令验证：

```powershell
# 1. 检查集群连接
kubectl get nodes
# 应该显示：observability-platform-control-plane   Ready

# 2. 检查 ArgoCD
kubectl get applications -n argocd
# 应该显示：microservices 和 observability-platform

# 3. 检查 Pods
kubectl get pods -A
# 应该显示所有运行的 Pods

# 4. 检查 Deployment
kubectl get deployment user-service -n microservices
# 应该显示：user-service 部署信息
```

---

## 💡 预防措施

1. **保持 Docker Desktop 运行**
   - 不要频繁关闭 Docker Desktop
   - 如果必须关闭，确保先停止所有容器

2. **定期检查集群状态**
   ```powershell
   kubectl get nodes
   ```

3. **备份重要配置**
   - 如果重新创建集群，需要重新部署所有应用
   - 考虑使用 `kubectl get all -A -o yaml > backup.yaml` 备份

---

## 🆘 如果所有方法都失败

1. **完全重启电脑**（有时 Windows 的网络栈需要重置）

2. **检查 Windows 防火墙**
   - 确保 Docker Desktop 和 kubectl 有网络权限

3. **检查端口占用**
   ```powershell
   netstat -ano | Select-String "51411"
   # 如果端口被占用，可能需要重启 Docker Desktop
   ```

4. **重新安装 Kind**（最后手段）
   ```powershell
   # 卸载
   choco uninstall kind
   # 或
   scoop uninstall kind
   
   # 重新安装
   choco install kind
   # 或
   scoop install kind
   ```

---

## 📞 需要帮助？

如果以上方法都无法解决问题，请提供以下信息：

1. Docker Desktop 版本
2. Kind 版本：`kind version`
3. kubectl 版本：`kubectl version --client`
4. 完整的错误信息
5. `docker ps -a` 的输出
6. `kind get clusters` 的输出

