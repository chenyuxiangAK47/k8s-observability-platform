# GitOps 配置目录

这个目录包含 ArgoCD Application 配置，实现声明式 GitOps 部署。

## 📁 目录结构

```
gitops/
├── apps/                    # ArgoCD Application 配置
│   ├── microservices-app.yaml      # 微服务应用配置
│   └── observability-app.yaml      # 可观测性平台应用配置
└── README.md                # 本文件
```

## 🎯 什么是 GitOps？

**GitOps** 是一种声明式部署方法，核心思想是：

1. **Git 是唯一真实来源（Single Source of Truth）**
   - 所有配置都在 Git 仓库中
   - 通过 Git 提交来触发部署

2. **声明式配置**
   - 描述"期望状态"（desired state）
   - ArgoCD 自动将集群状态同步到期望状态

3. **自动化同步**
   - Git 仓库变更 → ArgoCD 检测 → 自动部署
   - 无需手动执行 `kubectl apply`

## 🔄 GitOps 工作流程

```
开发者提交代码
    ↓
CI/CD Pipeline:
  - 构建 Docker 镜像
  - 推送到 GHCR
  - 更新 Helm values.yaml（镜像标签）
  - 提交到 Git
    ↓
ArgoCD 检测到 Git 变更
    ↓
ArgoCD 自动同步到 Kubernetes 集群
    ↓
应用自动更新
```

## 📦 ArgoCD Application 说明

### microservices-app.yaml

管理所有微服务（user-service、product-service、order-service）的部署。

**关键配置：**
- `source.repoURL`: Git 仓库地址
- `source.path`: Helm Chart 路径
- `destination.namespace`: 目标命名空间
- `syncPolicy.automated`: 自动同步策略

### observability-app.yaml

管理可观测性平台（Prometheus、Grafana、Loki、Jaeger）的部署。

## 🚀 如何使用

### 1. 安装 ArgoCD

```bash
# 创建 ArgoCD 命名空间
kubectl create namespace argocd

# 安装 ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 等待 ArgoCD 就绪
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### 2. 获取 ArgoCD 管理员密码

```bash
# 获取初始密码
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 或者使用脚本
./scripts/get-argocd-password.sh
```

### 3. 访问 ArgoCD UI

```bash
# 端口转发
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 访问 https://localhost:8080
# 用户名: admin
# 密码: (从步骤 2 获取)
```

### 4. 部署 ArgoCD Applications

```bash
# 应用 ArgoCD Application 配置
kubectl apply -f gitops/apps/microservices-app.yaml
kubectl apply -f gitops/apps/observability-app.yaml

# 查看应用状态
argocd app list
argocd app get microservices
```

### 5. 手动同步（如果需要）

```bash
# 同步应用
argocd app sync microservices

# 查看同步状态
argocd app get microservices
```

## 🔍 监控和调试

### 查看应用状态

```bash
# 使用 kubectl
kubectl get applications -n argocd

# 使用 ArgoCD CLI
argocd app list
argocd app get microservices
```

### 查看同步历史

```bash
argocd app history microservices
```

### 查看应用日志

```bash
# ArgoCD 控制器日志
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# 应用同步日志
argocd app logs microservices
```

## 🎓 学习要点

### 1. GitOps 的优势

- ✅ **可审计性**：所有变更都在 Git 中，有完整的提交历史
- ✅ **可回滚**：通过 Git revert 轻松回滚
- ✅ **一致性**：所有环境使用相同的配置
- ✅ **自动化**：减少人工操作，降低错误率

### 2. ArgoCD 核心概念

- **Application**: 代表一个要部署的应用
- **Sync Policy**: 定义如何同步应用
- **Health Check**: 检查应用健康状态
- **Resource Hook**: 在同步前后执行的操作

### 3. 最佳实践

- ✅ **使用 Helm Charts**：模板化配置，支持多环境
- ✅ **自动同步**：生产环境建议使用手动同步（需要审批）
- ✅ **健康检查**：确保应用正确部署
- ✅ **命名空间隔离**：不同环境使用不同命名空间

## 🔗 相关资源

- [ArgoCD 官方文档](https://argo-cd.readthedocs.io/)
- [GitOps 最佳实践](https://www.gitops.tech/)
- [ArgoCD 示例](https://github.com/argoproj/argocd-example-apps)

## 💡 面试话术

**当被问到"你了解 GitOps 吗？"时：**

> "我在项目中实现了完整的 GitOps 部署流程。使用 ArgoCD 实现声明式部署，所有配置都在 Git 仓库中，通过 CI/CD Pipeline 自动构建镜像并更新配置，ArgoCD 自动检测 Git 变更并同步到 Kubernetes 集群。这种方式实现了可审计、可回滚的生产级部署流程，大大提高了部署效率和可靠性。"

