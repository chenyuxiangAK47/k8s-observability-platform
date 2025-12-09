# 测试 CI/CD 完整流程指南

## 🎯 目标

验证从**代码提交 → 自动构建 → 自动部署**的完整 CI/CD 流程。

---

## ✅ 前置检查

### 1. 确认 ArgoCD 已安装并运行

```powershell
# 检查 ArgoCD Applications
kubectl get applications -n argocd

# 应该看到：
# microservices
# observability-platform
```

### 2. 确认当前部署状态

```powershell
# 检查微服务 Pod
kubectl get pods -n microservices

# 检查当前镜像标签
kubectl get deployment user-service -n microservices -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## 🚀 测试方法 1: 修改代码触发自动部署（推荐）

### Step 1: 修改 user-service 代码

```powershell
# 编辑 services/user-service/main.py
# 在文件开头添加一行注释，例如：
# # CI/CD Test - Updated at 2024-12-09
```

或者使用 PowerShell 快速添加：

```powershell
# 在文件开头添加一行注释
$content = Get-Content services/user-service/main.py
$newContent = @"
# CI/CD Test - Updated at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@ + "`n" + ($content -join "`n")
$newContent | Set-Content services/user-service/main.py
```

### Step 2: 提交并推送代码

```powershell
git add services/user-service/main.py
git commit -m "test: Trigger CI/CD for user-service - Test full GitOps flow"
git push
```

### Step 3: 观察 GitHub Actions

1. 打开 GitHub 仓库：https://github.com/chenyuxiangAK47/k8s-observability-platform
2. 点击 **Actions** 标签
3. 找到 **🚀 Deploy User Service (CI/CD Full Flow)** workflow
4. 观察执行过程：
   - ✅ Build & Push Docker Image
   - ✅ GitOps Deploy (Update Helm Values)

### Step 4: 验证 Helm values 更新

```powershell
# 等待 GitHub Actions 完成（约 2-3 分钟）
# 然后检查 Git 仓库中的 values.yaml 是否更新
git pull
cat helm/microservices/values.yaml | Select-String -Pattern "userService" -Context 2,2
```

应该看到新的镜像标签（Git SHA）。

### Step 5: 验证 ArgoCD 自动同步

#### 方法 A: 使用 ArgoCD UI

1. **访问 ArgoCD UI**
   ```powershell
   # 在单独的终端窗口运行
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```

2. **打开浏览器**
   - URL: `https://localhost:8080`
   - 用户名: `admin`
   - 密码: `xP2cKrKAv5awaIUe`（你之前保存的密码）

3. **查看 microservices 应用**
   - 点击 `microservices` 应用
   - 查看 **Sync Status** - 应该显示 `Synced`
   - 查看 **History** - 应该看到最新的同步记录

#### 方法 B: 使用 kubectl

```powershell
# 检查应用状态
kubectl get application microservices -n argocd

# 查看同步状态
kubectl get application microservices -n argocd -o jsonpath='{.status.sync.status}'

# 查看同步历史
kubectl get application microservices -n argocd -o jsonpath='{.status.history[*].revision}'
```

### Step 6: 验证 Pod 使用新镜像

```powershell
# 等待 ArgoCD 同步完成（约 1-2 分钟）
# 然后检查 Pod 是否使用新镜像

# 查看当前镜像
kubectl get deployment user-service -n microservices -o jsonpath='{.spec.template.spec.containers[0].image}'

# 查看 Pod 状态
kubectl get pods -n microservices -l app=user-service

# 查看 Pod 使用的镜像
kubectl get pods -n microservices -l app=user-service -o jsonpath='{.items[0].spec.containers[0].image}'
```

应该看到新的镜像标签（包含 Git SHA）。

### Step 7: 验证服务正常运行

```powershell
# 端口转发
kubectl port-forward -n microservices svc/user-service 8001:8001

# 在另一个终端测试
curl http://localhost:8001/health
```

---

## 🚀 测试方法 2: 手动触发 GitHub Actions

### Step 1: 手动触发 Workflow

1. 打开 GitHub 仓库
2. 点击 **Actions** 标签
3. 选择 **🚀 Deploy User Service (CI/CD Full Flow)**
4. 点击 **Run workflow** 按钮
5. 选择分支（通常是 `main` 或 `master`）
6. 点击 **Run workflow**

### Step 2-7: 同方法 1 的 Step 3-7

---

## 🔍 验证检查清单

完成以下检查，确保 CI/CD 流程正常工作：

- [ ] **GitHub Actions 成功执行**
  - [ ] Build & Push Docker Image 成功
  - [ ] GitOps Deploy 成功
  - [ ] Helm values.yaml 已更新

- [ ] **Git 仓库已更新**
  - [ ] `helm/microservices/values.yaml` 包含新的镜像标签
  - [ ] 提交信息包含 `[skip ci]`

- [ ] **ArgoCD 检测到变更**
  - [ ] ArgoCD UI 显示 `OutOfSync` 或自动同步
  - [ ] 同步历史包含新的记录

- [ ] **Kubernetes 集群已更新**
  - [ ] Deployment 使用新镜像
  - [ ] Pod 已重新创建
  - [ ] 新 Pod 状态为 `Running`

- [ ] **服务正常运行**
  - [ ] 健康检查通过
  - [ ] API 可以访问

---

## 🐛 故障排查

### 问题 1: GitHub Actions 失败

**检查：**
- 查看 Actions 日志
- 检查错误信息

**常见原因：**
- 权限问题：确保仓库有 `contents: write` 权限
- yq 安装失败：网络问题
- Git push 失败：检查 `GITHUB_TOKEN` 权限

### 问题 2: ArgoCD 未同步

**检查：**
```powershell
# 查看应用状态
kubectl get application microservices -n argocd -o yaml

# 查看 ArgoCD 日志
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50
```

**解决方案：**
- 在 ArgoCD UI 中手动点击 `Sync`
- 或使用 CLI：`argocd app sync microservices`

### 问题 3: Pod 未更新

**检查：**
```powershell
# 查看 Deployment 状态
kubectl describe deployment user-service -n microservices

# 查看 Pod 事件
kubectl describe pod -n microservices -l app=user-service
```

**解决方案：**
- 检查镜像是否存在：`docker pull ghcr.io/chenyuxiangAK47/user-service:latest`
- 检查 Helm values 中的镜像配置

### 问题 4: 镜像拉取失败

**检查：**
```powershell
# 查看 Pod 事件
kubectl get events -n microservices --sort-by='.lastTimestamp' | Select-Object -Last 20
```

**解决方案：**
- 确保镜像已推送到 GHCR
- 检查镜像标签是否正确
- 如果是私有镜像，配置 `imagePullSecrets`

---

## 📊 监控 CI/CD 流程

### 1. GitHub Actions 状态

在 GitHub 仓库首页可以看到最新的 workflow 状态。

### 2. ArgoCD 同步状态

在 ArgoCD UI 中：
- **Synced** = 已同步
- **OutOfSync** = 需要同步
- **Unknown** = 状态未知

### 3. Kubernetes 部署状态

```powershell
# 查看 Deployment 状态
kubectl get deployment user-service -n microservices

# 查看 ReplicaSet（可以看到镜像版本）
kubectl get rs -n microservices -l app=user-service

# 查看 Pod 事件
kubectl describe pod -n microservices -l app=user-service
```

---

## 🎉 成功标志

如果看到以下情况，说明 CI/CD 流程完全成功：

1. ✅ GitHub Actions 显示所有步骤成功
2. ✅ `helm/microservices/values.yaml` 包含新的 Git SHA 标签
3. ✅ ArgoCD UI 显示应用已同步
4. ✅ Kubernetes Pod 使用新镜像标签
5. ✅ 服务正常运行，可以访问

---

## 💡 下一步

完成 CI/CD 测试后，你可以：

1. **测试其他服务**：修改 `product-service` 或 `order-service`
2. **查看监控**：在 Grafana 中查看部署指标
3. **查看追踪**：在 Jaeger 中查看服务调用链路
4. **准备 AWS 迁移**：将同一套流程迁移到 AWS EKS

---

## 📝 面试话术

**当被问到"你如何测试 CI/CD 流程？"时：**

> "我通过修改代码并推送到 Git 仓库来触发完整的 CI/CD 流程。GitHub Actions 自动构建 Docker 镜像并推送到 GitHub Container Registry，然后更新 Helm Chart 的 values.yaml 文件并提交回 Git。ArgoCD 检测到 Git 变更后，自动将新版本同步到 Kubernetes 集群。我通过 ArgoCD UI 和 kubectl 验证了部署状态，确认 Pod 使用了新的镜像标签，服务正常运行。整个过程完全自动化，无需人工干预。"

---

## 🔗 相关资源

- [完整 CI/CD 指南](COMPLETE_CICD_GUIDE.md)
- [GitOps 文档](../gitops/README.md)
- [ArgoCD 官方文档](https://argo-cd.readthedocs.io/)

---

**现在开始测试吧！** 🚀

