# 完整 CI/CD 全流程指南

## 🎯 目标

实现从**代码提交 → 自动构建 → 自动部署 → 可观测性验证**的完整 CI/CD 流程。

```
开发者提交代码
    ↓
GitHub Actions: 构建 Docker 镜像
    ↓
推送到 GHCR (GitHub Container Registry)
    ↓
更新 Helm values.yaml (镜像标签)
    ↓
提交到 Git
    ↓
ArgoCD 自动检测 Git 变更
    ↓
自动同步到 Kubernetes 集群
    ↓
应用自动更新
    ↓
Grafana/Prometheus 监控验证
```

---

## 📋 前置要求

### 1. 本地环境
- ✅ Kubernetes 集群（Kind 或 Minikube）
- ✅ kubectl 已配置
- ✅ Helm 3.x 已安装
- ✅ Docker 已安装

### 2. GitHub 配置
- ✅ GitHub 仓库已创建
- ✅ GitHub Actions 已启用
- ✅ 仓库设置为公开（或配置了 GHCR 访问权限）

---

## 🚀 完整部署步骤

### Step 1: 安装 ArgoCD

#### Windows (PowerShell)
```powershell
.\scripts\install-argocd.ps1
```

#### Linux/Mac (Bash)
```bash
chmod +x scripts/install-argocd.sh
./scripts/install-argocd.sh
```

**预期输出：**
- ✅ ArgoCD 安装完成
- ✅ 显示管理员密码
- ✅ ArgoCD Applications 已创建

**保存管理员密码！** 稍后需要用它访问 ArgoCD UI。

---

### Step 2: 访问 ArgoCD UI

```bash
# 端口转发（在单独的终端窗口运行）
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

然后打开浏览器：
- URL: `https://localhost:8080`
- 用户名: `admin`
- 密码: (从 Step 1 获取)

**注意：** 浏览器可能会显示安全警告，点击"高级" → "继续访问"。

---

### Step 3: 验证 ArgoCD Applications

在 ArgoCD UI 中，你应该看到：
- `microservices` - 微服务应用
- `observability-platform` - 可观测性平台应用

如果应用状态是 `OutOfSync` 或 `Unknown`，点击 `Sync` 按钮手动同步。

---

### Step 4: 测试 CI/CD 流程

#### 方法 1: 修改代码触发自动部署

1. **修改 user-service 代码**
   ```bash
   # 编辑 services/user-service/main.py
   # 添加一行注释或修改代码
   ```

2. **提交并推送**
   ```bash
   git add services/user-service/
   git commit -m "test: Trigger CI/CD for user-service"
   git push
   ```

3. **观察 GitHub Actions**
   - 打开 GitHub 仓库 → Actions 标签
   - 查看 `🚀 Deploy User Service (CI/CD Full Flow)` workflow
   - 等待所有步骤完成

4. **验证部署**
   ```bash
   # 检查 Pod 是否更新
   kubectl get pods -n microservices -l app=user-service
   
   # 查看 Pod 日志
   kubectl logs -n microservices -l app=user-service --tail=50
   ```

#### 方法 2: 手动触发 Workflow

1. 打开 GitHub 仓库
2. 点击 `Actions` 标签
3. 选择 `🚀 Deploy User Service (CI/CD Full Flow)`
4. 点击 `Run workflow` → `Run workflow`

---

## 🔍 验证完整流程

### 1. 检查 GitHub Actions

```bash
# 在 GitHub 上查看 Actions 标签
# 应该看到：
# ✅ Build & Push Docker Image - 成功
# ✅ GitOps Deploy (Update Helm Values) - 成功
```

### 2. 检查 ArgoCD

在 ArgoCD UI 中：
- 点击 `microservices` 应用
- 查看 `Sync Status` - 应该是 `Synced`
- 查看 `Health Status` - 应该是 `Healthy`
- 查看 `History` - 应该看到最新的同步记录

### 3. 检查 Kubernetes 集群

```bash
# 检查 Pod 是否使用新镜像
kubectl get pods -n microservices -l app=user-service -o jsonpath='{.items[0].spec.containers[0].image}'

# 应该看到类似：
# ghcr.io/chenyuxiangAK47/user-service:abc123...
```

### 4. 检查 Grafana 监控

1. 访问 Grafana: `http://localhost:3000` (admin/admin)
2. 查看 `user-service` 的指标
3. 应该看到新的请求和指标数据

---

## 🐛 故障排查

### 问题 1: ArgoCD 无法同步

**症状：** ArgoCD 显示 `OutOfSync` 或 `Unknown`

**解决方案：**
```bash
# 检查 ArgoCD 日志
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50

# 手动同步
kubectl get application microservices -n argocd
# 或者在 ArgoCD UI 中点击 Sync
```

### 问题 2: 镜像拉取失败

**症状：** Pod 状态为 `ImagePullBackOff`

**解决方案：**
```bash
# 检查镜像是否存在
docker pull ghcr.io/chenyuxiangAK47/user-service:latest

# 检查 Helm values.yaml 中的镜像配置
cat helm/microservices/values.yaml | grep -A 2 "userService:"

# 确保 imageRegistry 设置正确
# 应该为: imageRegistry: "ghcr.io"
```

### 问题 3: GitHub Actions 失败

**症状：** Workflow 在某个步骤失败

**解决方案：**
1. 查看 GitHub Actions 日志
2. 检查错误信息
3. 常见问题：
   - **权限问题**: 确保仓库有 `contents: write` 权限
   - **yq 安装失败**: 检查网络连接
   - **Git push 失败**: 检查 `GITHUB_TOKEN` 权限

### 问题 4: Helm values 未更新

**症状：** 代码已推送，但 Helm values.yaml 未更新

**解决方案：**
```bash
# 检查 Git 历史
git log --oneline helm/microservices/values.yaml

# 手动更新（如果需要）
yq eval '.userService.image.tag = "your-sha"' -i helm/microservices/values.yaml
git add helm/microservices/values.yaml
git commit -m "Update image tag"
git push
```

---

## 📊 监控 CI/CD 流程

### 1. GitHub Actions 状态

在 GitHub 仓库首页，可以看到最新的 workflow 状态：
- ✅ 绿色 = 成功
- ❌ 红色 = 失败
- 🟡 黄色 = 进行中

### 2. ArgoCD 同步状态

在 ArgoCD UI 中：
- **Synced** = 已同步
- **OutOfSync** = 需要同步
- **Unknown** = 状态未知

### 3. Kubernetes 部署状态

```bash
# 查看 Deployment 状态
kubectl get deployment user-service -n microservices

# 查看 ReplicaSet（可以看到镜像版本）
kubectl get rs -n microservices -l app=user-service

# 查看 Pod 事件
kubectl describe pod -n microservices -l app=user-service
```

---

## 🎓 学习要点

### 1. GitOps 工作流程

1. **Git 是唯一真实来源**
   - 所有配置都在 Git 中
   - 通过 Git 提交触发部署

2. **声明式配置**
   - 描述"期望状态"
   - ArgoCD 自动同步

3. **自动化同步**
   - Git 变更 → ArgoCD 检测 → 自动部署

### 2. CI/CD Pipeline 阶段

1. **Build**: 构建 Docker 镜像
2. **Push**: 推送到镜像仓库
3. **Update**: 更新 Helm values
4. **Commit**: 提交到 Git
5. **Sync**: ArgoCD 自动同步

### 3. 最佳实践

- ✅ **使用语义化版本**: 使用 Git SHA 作为镜像标签
- ✅ **自动化测试**: 在部署前运行测试
- ✅ **安全扫描**: 扫描镜像漏洞
- ✅ **回滚机制**: 通过 Git revert 回滚

---

## 💡 面试话术

**当被问到"你如何实现 CI/CD？"时：**

> "我实现了一个完整的 GitOps CI/CD 流程。当开发者提交代码到 GitHub 时，GitHub Actions 自动触发构建流程：首先进行代码检查和测试，然后构建 Docker 镜像并推送到 GitHub Container Registry。接着，CI/CD Pipeline 自动更新 Helm Chart 的 values.yaml 文件，将新的镜像标签提交回 Git 仓库。ArgoCD 检测到 Git 变更后，自动将新版本同步到 Kubernetes 集群。整个过程完全自动化，无需人工干预，并且所有变更都有完整的审计日志。"

---

## 🔗 相关资源

- [GitOps 文档](gitops/README.md)
- [ArgoCD 官方文档](https://argo-cd.readthedocs.io/)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [Helm 文档](https://helm.sh/docs/)

---

## ✅ 检查清单

完成以下步骤，确保 CI/CD 流程正常工作：

- [ ] ArgoCD 已安装并运行
- [ ] ArgoCD Applications 已创建
- [ ] GitHub Actions workflow 已配置
- [ ] 测试代码提交触发自动部署
- [ ] 验证镜像已推送到 GHCR
- [ ] 验证 Helm values 已更新
- [ ] 验证 ArgoCD 自动同步
- [ ] 验证 Pod 使用新镜像
- [ ] 验证 Grafana 监控正常

---

## 🎉 完成！

恭喜！你已经实现了完整的 CI/CD 全流程！

现在你可以在简历上写：

> **"Implemented end-to-end CI/CD pipeline from code commit to Kubernetes deployment with GitOps & observability, achieving 100% automation from development to production."**

这是 SRE/DevOps 岗位的核心技能！🚀

