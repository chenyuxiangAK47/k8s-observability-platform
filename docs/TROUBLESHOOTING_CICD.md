# CI/CD 故障排查指南

## 🚨 常见问题

### 问题 1: Docker Desktop 未运行

**症状：**
```
Unable to connect to the server: dial tcp 127.0.0.1:51411: connectex: No connection could be made
TLS handshake timeout
```

**解决方案：**
1. 打开 Docker Desktop 应用
2. 等待完全启动（系统托盘图标不再转动）
3. 运行修复脚本：
   ```powershell
   .\scripts\quick-fix-cluster.ps1
   ```

---

### 问题 2: GitHub Actions Workflow 失败

#### 2.1 yq 命令失败

**症状：**
```
Error: yq: command not found
或
Error: yq eval: invalid syntax
```

**解决方案：**
- 已修复：yq 命令语法已更新
- 如果仍然失败，检查 yq 版本：
  ```yaml
  # 在 workflow 中添加版本检查
  - name: Install yq
    run: |
      wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
      chmod +x /usr/local/bin/yq
      yq --version  # 应该显示 v4.x 或更高
  ```

#### 2.2 Git Push 权限失败

**症状：**
```
Error: Permission denied (publickey)
或
Error: fatal: could not read Username
```

**解决方案：**
1. 检查 workflow 权限：
   ```yaml
   permissions:
     contents: write  # 必须要有
   ```

2. 检查 checkout 配置：
   ```yaml
   - name: Checkout code
     uses: actions/checkout@v4
     with:
       token: ${{ secrets.GITHUB_TOKEN }}
       persist-credentials: true  # 必须要有
   ```

#### 2.3 镜像构建失败

**症状：**
```
Error: failed to solve: failed to fetch
或
Error: unauthorized
```

**解决方案：**
1. 检查 Docker 登录：
   ```yaml
   - name: Log in to GitHub Container Registry
     uses: docker/login-action@v3
     with:
       registry: ghcr.io
       username: ${{ github.actor }}
       password: ${{ secrets.GITHUB_TOKEN }}
   ```

2. 确保仓库是公开的，或配置了 GHCR 访问权限

---

### 问题 3: ArgoCD 未同步

**症状：**
- ArgoCD UI 显示 `OutOfSync`
- Pod 未更新为新镜像

**解决方案：**

#### 方法 1: 手动同步
```powershell
# 在 ArgoCD UI 中点击 Sync 按钮
# 或使用 CLI
argocd app sync microservices
```

#### 方法 2: 检查 Git 仓库连接
```powershell
# 查看应用状态
kubectl get application microservices -n argocd -o yaml

# 查看错误信息
kubectl describe application microservices -n argocd
```

#### 方法 3: 检查 ArgoCD 日志
```powershell
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50
```

---

### 问题 4: Pod 未更新

**症状：**
- Helm values 已更新
- ArgoCD 显示已同步
- 但 Pod 仍使用旧镜像

**解决方案：**

1. **检查 Deployment 镜像**
   ```powershell
   kubectl get deployment user-service -n microservices -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```

2. **强制重新部署**
   ```powershell
   kubectl rollout restart deployment/user-service -n microservices
   ```

3. **检查 Pod 事件**
   ```powershell
   kubectl describe pod -n microservices -l app=user-service
   ```

---

## 🔍 调试步骤

### Step 1: 检查 GitHub Actions 日志

1. 打开 GitHub 仓库 → Actions
2. 点击失败的 workflow
3. 查看具体错误信息

### Step 2: 检查本地集群

```powershell
# 检查 Docker
docker ps

# 检查集群
kubectl get nodes

# 检查 Pod
kubectl get pods -A
```

### Step 3: 检查 ArgoCD

```powershell
# 检查 ArgoCD Pod
kubectl get pods -n argocd

# 检查应用状态
kubectl get applications -n argocd

# 查看应用详情
kubectl get application microservices -n argocd -o yaml
```

### Step 4: 验证镜像

```powershell
# 检查镜像是否存在
docker pull ghcr.io/chenyuxiangAK47/user-service:latest

# 检查 Helm values
cat helm/microservices/values.yaml | grep -A 2 "userService:"
```

---

## 📝 检查清单

完成以下检查，确保 CI/CD 流程正常：

- [ ] Docker Desktop 正在运行
- [ ] Kubernetes 集群可访问
- [ ] GitHub Actions workflow 配置正确
- [ ] yq 命令语法正确
- [ ] Git 权限配置正确
- [ ] ArgoCD 已安装并运行
- [ ] ArgoCD Applications 已创建
- [ ] Helm values.yaml 格式正确

---

## 💡 快速修复命令

```powershell
# 1. 修复集群连接
.\scripts\quick-fix-cluster.ps1

# 2. 重新安装 ArgoCD（如果需要）
.\scripts\install-argocd.ps1

# 3. 检查所有服务状态
kubectl get pods -A

# 4. 查看 ArgoCD 应用
kubectl get applications -n argocd
```

---

## 🔗 相关资源

- [完整 CI/CD 指南](COMPLETE_CICD_GUIDE.md)
- [测试 CI/CD 流程](TEST_CICD_FLOW.md)
- [GitOps 文档](../gitops/README.md)

