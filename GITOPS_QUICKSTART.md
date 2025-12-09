# 🚀 GitOps + CI/CD 快速开始指南

这是 GitOps + CI/CD 功能的快速开始指南，让你在 10 分钟内完成部署。

---

## ⚡ 5 分钟快速部署

### 前置要求检查

```bash
# 检查 Docker
docker --version

# 检查 kubectl
kubectl version --client

# 检查 Helm
helm version

# 检查 kind（用于本地集群）
kind version
```

### 步骤 1: 创建 Kubernetes 集群

```bash
# 创建 kind 集群
kind create cluster --name observability-platform

# 验证集群
kubectl cluster-info
```

### 步骤 2: 安装 ArgoCD

#### Windows (PowerShell)

```powershell
.\scripts\install-argocd.ps1
```

#### Linux/Mac (Bash)

```bash
chmod +x scripts/install-argocd.sh
./scripts/install-argocd.sh
```

**获取 ArgoCD 密码：**

```bash
# Linux/Mac
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Windows PowerShell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

**访问 ArgoCD UI：**

```bash
# 端口转发
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 打开浏览器
# https://localhost:8080
# 用户名: admin
# 密码: (从上面获取)
```

### 步骤 3: 部署 GitOps Applications

#### Windows (PowerShell)

```powershell
.\scripts\deploy-gitops.ps1
```

#### Linux/Mac (Bash)

```bash
chmod +x scripts/deploy-gitops.sh
./scripts/deploy-gitops.sh
```

### 步骤 4: 验证部署

```bash
# 查看 ArgoCD Applications
kubectl get applications -n argocd

# 查看应用状态
argocd app list  # 如果安装了 ArgoCD CLI

# 查看 Pods
kubectl get pods -n microservices
kubectl get pods -n observability
```

---

## 🎯 下一步

### 1. 配置 CI/CD Pipeline

1. **推送代码到 GitHub**
   ```bash
   git add .
   git commit -m "Add GitOps + CI/CD"
   git push origin main
   ```

2. **查看 GitHub Actions**
   - 进入 GitHub 仓库
   - 点击 "Actions" 标签
   - 查看 Pipeline 运行状态

3. **观察自动部署**
   - Pipeline 完成后，ArgoCD 会自动检测 Git 变更
   - 在 ArgoCD UI 中查看同步状态

### 2. 测试 GitOps 流程

1. **修改代码**
   ```bash
   # 修改任意服务代码
   echo "# Test change" >> services/user-service/main.py
   ```

2. **提交并推送**
   ```bash
   git add .
   git commit -m "Test GitOps deployment"
   git push origin main
   ```

3. **观察自动部署**
   - CI/CD Pipeline 自动运行
   - 构建新镜像
   - 更新 Helm values
   - ArgoCD 自动同步

### 3. 在 ArgoCD UI 中操作

1. **查看应用状态**
   - 打开 ArgoCD UI
   - 查看 `microservices` 和 `observability-platform` 应用
   - 查看同步历史和健康状态

2. **手动同步（如果需要）**
   - 点击应用
   - 点击 "Sync" 按钮
   - 选择要同步的资源

3. **查看应用详情**
   - 查看资源树
   - 查看 Pod 日志
   - 查看事件历史

---

## 🔧 常见问题

### Q1: ArgoCD 无法访问 Git 仓库

**解决方案：**

```bash
# 如果仓库是私有的，需要配置访问
argocd repo add https://github.com/chenyuxiangAK47/k8s-observability-platform \
  --type git \
  --name k8s-observability-platform \
  --username <username> \
  --password <token>
```

### Q2: CI/CD Pipeline 失败

**检查点：**

1. 查看 GitHub Actions 日志
2. 检查 Docker 镜像构建是否成功
3. 检查 Helm values 更新是否正确

### Q3: 镜像拉取失败

**解决方案：**

```bash
# 如果使用私有镜像，需要创建 pull secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<username> \
  --docker-password=<token> \
  -n microservices

# 更新 Helm values
# 在 values.yaml 中添加：
# global:
#   imagePullSecrets:
#     - name: ghcr-secret
```

---

## 📚 相关文档

- [完整部署指南](docs/GITOPS_DEPLOYMENT.md)
- [GitOps 说明](gitops/README.md)
- [简历话术](docs/RESUME_TALKING_POINTS.md)

---

## 🎉 完成！

恭喜！你已经成功部署了 GitOps + CI/CD 平台。

现在你可以：
- ✅ 通过 Git 提交自动触发部署
- ✅ 在 ArgoCD UI 中查看和管理应用
- ✅ 享受完全自动化的部署流程

**下一步建议：**
1. 尝试修改代码，观察自动部署
2. 在 ArgoCD UI 中探索各种功能
3. 阅读完整文档，深入了解 GitOps

---

**有问题？** 查看 [故障排查指南](docs/GITOPS_DEPLOYMENT.md#故障排查)



