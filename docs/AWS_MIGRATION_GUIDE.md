# AWS 迁移完整指南

## 🎯 迁移目标

将本地 Kind 集群迁移到 AWS，解决资源过载问题，展示生产级 DevOps 能力。

---

## 📋 需要准备的 AWS 资源

### ✅ 必须准备（EKS 方案）

| 资源 | 用途 | 成本估算 |
|------|------|---------|
| **EKS Cluster** | Kubernetes 运行环境 | ~$0.10/小时（控制平面） |
| **EC2 节点** | EKS 工作节点 | ~$0.10-0.20/小时（t3.medium） |
| **ECR** | Docker 镜像仓库 | 免费（前 500MB/月） |
| **VPC** | 网络隔离 | 免费 |
| **IAM Roles** | 权限控制 | 免费 |
| **CloudWatch** | 日志和监控 | 免费（前 5GB/月） |

### ❌ 不需要准备（除非需要）

| 资源 | 是否必须 | 说明 |
|------|---------|------|
| **S3** | ❌ | 除非需要文件存储或 Loki 长期存储 |
| **RDS** | ❌ | 你的服务使用 PostgreSQL，可以继续用容器 |
| **DynamoDB** | ❌ | 不需要 |
| **ElastiCache** | ❌ | 不需要 |

---

## 🚀 迁移方案对比

### 方案 A: ECS Fargate（推荐新手，最简单）

**优点：**
- ✅ 无需管理节点（Serverless）
- ✅ 自动扩缩容
- ✅ 按需付费
- ✅ 不会崩溃
- ✅ 配置简单

**需要准备：**
- ECR（镜像仓库）
- ECS Fargate Cluster
- Task Definitions（每个服务一个）
- IAM Roles

**成本：** ~$20-30/月

---

### 方案 B: EKS（推荐专业，完整 Kubernetes）

**优点：**
- ✅ 完整的 Kubernetes 功能
- ✅ 可以运行 ArgoCD、Prometheus Operator
- ✅ 生产级架构
- ✅ 展示 K8s 技能

**需要准备：**
- EKS Cluster
- EC2 节点（或 Fargate Profiles）
- ECR
- VPC、Subnets、Security Groups
- IAM Roles for Service Accounts

**成本：** ~$50-100/月

---

### 方案 C: EC2 + Docker Compose（最便宜）

**优点：**
- ✅ 最便宜（~$10/月）
- ✅ 最简单
- ✅ 适合快速验证

**需要准备：**
- 1 个 EC2 实例（t3.medium）
- Docker + Docker Compose
- Security Group（开放端口）

**成本：** ~$10-15/月

---

## 🎯 我的建议

### 阶段 1: 快速验证（ECS Fargate）

先用 ECS Fargate 快速验证：
- 部署 3 个微服务
- 验证 CI/CD 流程
- 验证监控

**时间：** 1-2 小时

### 阶段 2: 完整迁移（EKS）

如果 ECS 验证成功，迁移到 EKS：
- 完整的 Kubernetes 环境
- ArgoCD GitOps
- Prometheus + Grafana
- 生产级架构

**时间：** 2-3 小时

---

## 📦 AWS 资源清单

### EKS 方案需要创建：

```
1. VPC + Subnets (2 个可用区)
   - Public Subnets (ALB)
   - Private Subnets (EKS 节点)

2. EKS Cluster
   - 控制平面（AWS 管理）
   - 工作节点组（EC2 或 Fargate）

3. ECR Repositories
   - user-service
   - product-service
   - order-service

4. IAM Roles
   - EKS Cluster Role
   - Node Group Role
   - IRSA (Prometheus, ArgoCD)

5. Security Groups
   - EKS Cluster SG
   - Node Group SG
   - ALB SG

6. CloudWatch
   - Log Groups（自动创建）
   - Metrics（自动收集）
```

### ECS Fargate 方案需要创建：

```
1. ECR Repositories
   - user-service
   - product-service
   - order-service

2. ECS Cluster (Fargate)

3. Task Definitions
   - user-service
   - product-service
   - order-service

4. IAM Roles
   - Task Execution Role
   - Task Role

5. ALB (可选)
   - Application Load Balancer
   - Target Groups
```

---

## 🔧 迁移步骤

### Step 1: 准备 AWS 账号

1. **创建 AWS 账号**（如果还没有）
2. **安装 AWS CLI：**
   ```powershell
   # 使用 Chocolatey
   choco install awscli
   
   # 或下载安装包
   # https://aws.amazon.com/cli/
   ```

3. **配置 AWS 凭证：**
   ```powershell
   aws configure
   # 输入 Access Key ID
   # 输入 Secret Access Key
   # 选择区域（如：us-east-1）
   ```

4. **验证配置：**
   ```powershell
   aws sts get-caller-identity
   ```

### Step 2: 创建 ECR 仓库

```powershell
# 创建 3 个 ECR 仓库
aws ecr create-repository --repository-name user-service --region us-east-1
aws ecr create-repository --repository-name product-service --region us-east-1
aws ecr create-repository --repository-name order-service --region us-east-1
```

### Step 3: 更新 GitHub Actions

更新 CI/CD 工作流，推送到 ECR 而不是 GHCR。

### Step 4: 创建 EKS 集群

使用 Terraform 或 AWS CLI 创建 EKS 集群。

### Step 5: 部署应用

使用 kubectl 或 Helm 部署应用到 EKS。

---

## 💰 成本估算

### EKS 方案（完整）

| 资源 | 规格 | 月成本 |
|------|------|--------|
| EKS 控制平面 | 标准 | ~$72 |
| EC2 节点 | t3.medium x 2 | ~$60 |
| ECR | 3 个仓库 | 免费 |
| CloudWatch | 日志和指标 | ~$5-10 |
| **总计** | | **~$140-150/月** |

### ECS Fargate 方案（简单）

| 资源 | 规格 | 月成本 |
|------|------|--------|
| ECS Fargate | 0.5 vCPU, 1GB x 3 | ~$20-30 |
| ECR | 3 个仓库 | 免费 |
| CloudWatch | 日志和指标 | ~$5 |
| **总计** | | **~$25-35/月** |

### EC2 + Docker Compose（最便宜）

| 资源 | 规格 | 月成本 |
|------|------|--------|
| EC2 | t3.medium | ~$30 |
| EBS | 20GB | ~$2 |
| **总计** | | **~$32/月** |

---

## 🎯 推荐路径

### 路径 1: 快速验证 → 完整迁移

1. **先用 ECS Fargate**（1-2 小时）
   - 验证 CI/CD
   - 验证服务运行
   - 成本低

2. **再迁移到 EKS**（2-3 小时）
   - 完整 Kubernetes
   - 生产级架构

### 路径 2: 直接 EKS

如果预算充足，直接创建 EKS 集群。

---

## 📝 下一步

告诉我你的选择：

1. **ECS Fargate** - 我立即创建配置和脚本
2. **EKS** - 我创建完整的 Terraform 配置
3. **EC2 + Docker Compose** - 我创建部署脚本

我会为你创建：
- ✅ Terraform 配置（基础设施即代码）
- ✅ GitHub Actions 更新（CI/CD）
- ✅ 部署脚本
- ✅ 完整文档

---

## 🆘 需要帮助？

如果遇到问题，请提供：
- AWS 账号状态
- AWS CLI 版本：`aws --version`
- 选择的区域（如：us-east-1）

