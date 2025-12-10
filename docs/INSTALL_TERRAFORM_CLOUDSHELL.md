# 在 AWS CloudShell 中安装 Terraform

## 🚀 快速安装

### 方法 1: 使用包管理器（推荐）

```bash
# 下载 Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip

# 解压
unzip terraform_1.6.0_linux_amd64.zip

# 移动到 PATH
sudo mv terraform /usr/local/bin/

# 验证安装
terraform --version
```

### 方法 2: 使用最新版本（自动获取）

```bash
# 获取最新版本号
TERRAFORM_VERSION=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')

# 下载
wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# 解压
unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# 移动到 PATH
sudo mv terraform /usr/local/bin/

# 验证
terraform --version
```

---

## 📋 完整步骤

### Step 1: 安装 Terraform

```bash
# 下载 Terraform 1.6.0
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip

# 解压
unzip terraform_1.6.0_linux_amd64.zip

# 安装到系统路径
sudo mv terraform /usr/local/bin/

# 清理
rm terraform_1.6.0_linux_amd64.zip

# 验证
terraform --version
```

### Step 2: 获取项目文件

**选项 A: 从 GitHub 克隆（推荐）**

```bash
# 克隆项目
git clone https://github.com/chenyuxiangAK47/k8s-observability-platform.git

# 进入项目目录
cd k8s-observability-platform
```

**选项 B: 上传文件（如果无法克隆）**

在 CloudShell 中使用上传功能上传项目文件。

### Step 3: 创建 EKS 集群

```bash
# 进入 Terraform 目录
cd terraform/eks

# 初始化
terraform init

# 应用（创建集群）
terraform apply -auto-approve
```

---

## ⚡ 最快方式：使用 AWS Console 创建 EKS

如果安装 Terraform 太慢，可以直接在 AWS Console 创建：

1. **进入 EKS Console**
   - https://console.aws.amazon.com/eks/

2. **创建集群**
   - 点击 "Create cluster"
   - 选择 "Standard create"
   - 集群名称：`observability-platform`
   - Kubernetes 版本：1.28
   - 选择 VPC 和子网
   - 创建

3. **添加节点组**
   - 在集群详情页，添加节点组
   - 实例类型：t3.medium
   - 节点数量：2

**时间：** 15-20 分钟

---

## 🎯 推荐操作

考虑到明天开始收费，**最快方式**：

### 选项 1: 在 CloudShell 中安装 Terraform 并创建（20-25 分钟）

```bash
# 1. 安装 Terraform（2 分钟）
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform --version

# 2. 克隆项目（1 分钟）
git clone https://github.com/chenyuxiangAK47/k8s-observability-platform.git
cd k8s-observability-platform/terraform/eks

# 3. 创建集群（15-20 分钟）
terraform init
terraform apply -auto-approve
```

### 选项 2: 使用 AWS Console 创建（15-20 分钟，无需安装）

直接在 AWS Console 中创建 EKS 集群，更快。

---

## 💡 我的建议

**考虑到时间紧迫，推荐：**

1. **快速安装 Terraform**（2 分钟）
2. **克隆项目**（1 分钟）
3. **创建 EKS 集群**（15-20 分钟）

或者直接使用 AWS Console 创建，更快。

---

## 📝 完整命令（复制粘贴）

```bash
# 安装 Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
rm terraform_1.6.0_linux_amd64.zip
terraform --version

# 克隆项目
git clone https://github.com/chenyuxiangAK47/k8s-observability-platform.git
cd k8s-observability-platform/terraform/eks

# 创建集群
terraform init
terraform apply -auto-approve
```

告诉我你想用哪种方式，我立即帮你执行！

