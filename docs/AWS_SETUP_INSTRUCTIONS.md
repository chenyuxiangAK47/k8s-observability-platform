# AWS EKS 设置完整指南

## 📋 前置要求

### 1. AWS 账号

如果你还没有 AWS 账号：
1. 访问 https://aws.amazon.com/
2. 点击 "Create an AWS Account"
3. 完成注册（需要信用卡，但新用户有免费额度）

### 2. 安装 AWS CLI

**Windows (PowerShell):**
```powershell
# 使用 Chocolatey
choco install awscli

# 或下载安装包
# https://aws.amazon.com/cli/
```

**验证安装:**
```powershell
aws --version
```

### 3. 配置 AWS 凭证

```powershell
aws configure
```

输入以下信息：
- **AWS Access Key ID**: 从 AWS IAM 获取
- **AWS Secret Access Key**: 从 AWS IAM 获取
- **Default region**: `us-east-1` (或其他区域)
- **Default output format**: `json`

**如何获取 Access Key:**
1. 登录 AWS Console
2. 点击右上角用户名 → "Security credentials"
3. 展开 "Access keys"
4. 点击 "Create access key"
5. 选择 "Command Line Interface (CLI)"
6. 下载或复制 Access Key ID 和 Secret Access Key

### 4. 安装 Terraform

```powershell
choco install terraform
```

**验证安装:**
```powershell
terraform --version
```

### 5. 安装 kubectl

```powershell
choco install kubernetes-cli
```

**验证安装:**
```powershell
kubectl version --client
```

---

## 🚀 快速开始

### Step 1: 运行设置脚本

```powershell
.\scripts\setup-aws-eks.ps1
```

这个脚本会：
- ✅ 检查所有前置要求
- ✅ 验证 AWS 凭证
- ✅ 初始化 Terraform
- ✅ 创建 EKS 集群
- ✅ 配置 kubectl

**预计时间：** 15-20 分钟

---

### Step 2: 配置 GitHub Secrets

在 GitHub 仓库设置中添加以下 Secrets：

1. 进入仓库 → **Settings** → **Secrets and variables** → **Actions**
2. 点击 **New repository secret**
3. 添加以下 secrets：

| Secret Name | Value | 说明 |
|------------|-------|------|
| `AWS_ACCOUNT_ID` | `123456789012` | 你的 AWS 账号 ID |
| `AWS_ACCESS_KEY_ID` | `AKIA...` | AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | `...` | AWS Secret Access Key |

**如何获取 AWS Account ID:**
```powershell
aws sts get-caller-identity --query Account --output text
```

---

### Step 3: 更新 Helm values.yaml

Terraform 创建 ECR 仓库后，更新 Helm values：

```yaml
global:
  imageRegistry: <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

userService:
  image:
    repository: user-service
    tag: latest
```

---

## 📊 创建的资源

运行 Terraform 后，会创建：

### 网络
- ✅ VPC (10.0.0.0/16)
- ✅ 2 个 Public Subnets (ALB)
- ✅ 2 个 Private Subnets (EKS 节点)
- ✅ Internet Gateway
- ✅ 2 个 NAT Gateways
- ✅ Route Tables

### EKS
- ✅ EKS Cluster (控制平面)
- ✅ Node Group (2x t3.medium 实例)
- ✅ IAM Roles (集群和节点)

### ECR
- ✅ user-service 仓库
- ✅ product-service 仓库
- ✅ order-service 仓库

### 监控
- ✅ CloudWatch Log Group

---

## 💰 成本估算

| 资源 | 月成本 |
|------|--------|
| EKS 控制平面 | ~$72 |
| EC2 节点 (2x t3.medium) | ~$60 |
| NAT Gateways (2x) | ~$65 |
| ECR | 免费 (前 500MB) |
| CloudWatch | ~$5-10 |
| **总计** | **~$200-210/月** |

**省钱技巧：**
- 使用单个 NAT Gateway（节省 ~$32/月）
- 使用 Fargate 而不是 EC2（按需付费）
- 停止集群（不使用时）

---

## 🔧 手动步骤（如果脚本失败）

### 1. 初始化 Terraform

```powershell
cd terraform/eks
terraform init
```

### 2. 查看计划

```powershell
terraform plan
```

### 3. 应用配置

```powershell
terraform apply
```

输入 `yes` 确认。

### 4. 配置 kubectl

```powershell
aws eks update-kubeconfig --region us-east-1 --name observability-platform
```

### 5. 验证集群

```powershell
kubectl get nodes
kubectl get pods -A
```

---

## 📝 后续步骤

### 1. 更新 GitHub Actions

工作流文件已创建：`.github/workflows/cicd-aws-ecr.yml`

确保 GitHub Secrets 已配置。

### 2. 部署应用

```powershell
# 部署微服务
helm install microservices ./helm/microservices \
  --namespace microservices \
  --create-namespace

# 部署监控栈
helm install observability ./helm/observability-platform \
  --namespace observability \
  --create-namespace
```

### 3. 配置 ArgoCD

```powershell
# 安装 ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 获取 admin 密码
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 4. 配置 ArgoCD Applications

```powershell
kubectl apply -f gitops/apps/microservices-app.yaml
kubectl apply -f gitops/apps/observability-app.yaml
```

---

## 🗑️ 清理资源（节省费用）

如果不再需要集群：

```powershell
cd terraform/eks
terraform destroy
```

输入 `yes` 确认。这会删除所有资源。

---

## 🆘 故障排除

### 错误: "Unable to locate credentials"

```powershell
aws configure
```

### 错误: "Insufficient permissions"

你的 AWS 用户需要这些权限：
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEC2FullAccess`
- `AmazonEC2ContainerRegistryFullAccess`

### 错误: "Region not found"

确保使用有效的 AWS 区域（如：us-east-1, us-west-2）。

### 集群创建时间过长

EKS 集群创建通常需要 15-20 分钟，这是正常的。

### 节点未加入集群

检查节点组状态：
```powershell
aws eks describe-nodegroup \
  --cluster-name observability-platform \
  --nodegroup-name observability-platform-nodes
```

---

## 📚 相关文档

- [AWS EKS 文档](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [ECR 文档](https://docs.aws.amazon.com/ecr/)

---

## ✅ 验证清单

- [ ] AWS 账号已创建
- [ ] AWS CLI 已安装并配置
- [ ] Terraform 已安装
- [ ] kubectl 已安装
- [ ] GitHub Secrets 已配置
- [ ] EKS 集群已创建
- [ ] kubectl 已配置
- [ ] GitHub Actions 工作流已更新
- [ ] 应用已部署

---

## 💡 下一步

1. **验证 CI/CD** - 推送代码，查看 GitHub Actions
2. **部署应用** - 使用 Helm 部署到 EKS
3. **配置监控** - 设置 Prometheus + Grafana
4. **配置 GitOps** - 设置 ArgoCD

需要帮助？查看 `docs/AWS_MIGRATION_GUIDE.md` 获取完整迁移指南。

