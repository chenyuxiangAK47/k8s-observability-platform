# AWS CloudShell vs 本地运行指南

## 🔍 当前情况

你在 **AWS CloudShell**（bash 环境）中运行命令，但：
- PowerShell 脚本（`.ps1`）无法在 bash 中运行
- 需要先创建 EKS 集群才能使用 `kubectl` 和 `helm`

---

## 📍 两种运行方式对比

### 方式 1: AWS CloudShell（你当前的环境）

**优点：**
- ✅ 已配置 AWS 凭证
- ✅ 可以直接访问 AWS 服务
- ✅ 不需要本地安装工具

**缺点：**
- ❌ 是 bash 环境，不能运行 PowerShell 脚本
- ❌ 需要安装 Terraform、kubectl、helm

**适合：** 快速测试，不想在本地安装工具

---

### 方式 2: 本地 Windows（PowerShell）

**优点：**
- ✅ 可以使用 PowerShell 脚本
- ✅ 所有工具已安装（如果已配置）
- ✅ 更好的开发体验

**缺点：**
- ❌ 需要配置 AWS 凭证
- ❌ 需要安装所有工具

**适合：** 完整开发和部署

---

## 🚀 快速解决方案

### 选项 A: 在 CloudShell 中创建 EKS（推荐，快速）

我已经为你创建了 bash 版本的脚本：

```bash
# 1. 进入项目目录（如果还没进入）
cd ~/k8s-observability-platform  # 或你的项目路径

# 2. 运行 bash 版本的设置脚本
bash scripts/setup-aws-eks.sh
```

**或者手动执行：**

```bash
# 1. 进入 Terraform 目录
cd terraform/eks

# 2. 初始化 Terraform
terraform init

# 3. 查看计划
terraform plan

# 4. 应用配置（创建集群）
terraform apply
```

### 选项 B: 在本地 Windows 中运行

```powershell
# 1. 确保 AWS CLI 已配置
aws configure

# 2. 运行 PowerShell 脚本
.\scripts\setup-aws-eks.ps1
```

---

## 📋 当前状态检查

### 在 CloudShell 中检查：

```bash
# 检查 AWS 凭证
aws sts get-caller-identity

# 检查 ECR 仓库
aws ecr describe-repositories --region us-east-1

# 检查镜像
aws ecr list-images --repository-name user-service --region us-east-1
```

### 在本地 Windows 中检查：

```powershell
# 检查 AWS 凭证
aws sts get-caller-identity

# 检查 ECR 仓库
aws ecr describe-repositories --region us-east-1
```

---

## 🎯 推荐操作

**考虑到明天开始收费，建议：**

### 在 CloudShell 中快速创建：

```bash
# 1. 安装 Terraform（如果还没安装）
# CloudShell 通常已预装，检查：
terraform --version

# 2. 进入 Terraform 目录
cd terraform/eks

# 3. 初始化并应用
terraform init
terraform apply

# 4. 配置 kubectl
aws eks update-kubeconfig --region us-east-1 --name observability-platform

# 5. 验证
kubectl get nodes
```

---

## 💡 快速命令（CloudShell）

```bash
# 创建 EKS 集群
cd terraform/eks
terraform init
terraform apply -auto-approve

# 配置 kubectl
aws eks update-kubeconfig --region us-east-1 --name observability-platform

# 验证
kubectl get nodes
```

---

## 📝 总结

**你当前在：** AWS CloudShell（bash 环境）

**推荐操作：**
1. 在 CloudShell 中使用 bash 脚本或手动运行 Terraform
2. 或切换到本地 Windows 使用 PowerShell 脚本

**最快方式：** 在 CloudShell 中手动运行 Terraform 命令

告诉我你想：
1. **在 CloudShell 中创建** - 我提供详细命令
2. **切换到本地 Windows** - 我帮你配置
3. **其他** - 告诉我你的想法

