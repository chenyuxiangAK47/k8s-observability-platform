# 修复 Terraform 初始化问题

## 🔴 错误信息

```
Error: Inconsistent dependency lock file

The following dependency selections recorded in the lock file are inconsistent with the current configuration:
  - provider registry.terraform.io/hashicorp/aws: required by this configuration but no version is selected
  - provider registry.terraform.io/hashicorp/helm: required by this configuration but no version is selected
  - provider registry.terraform.io/hashicorp/kubernetes: required by this configuration but no version is selected
```

**原因：** 依赖锁文件（`.terraform.lock.hcl`）与当前配置不一致，需要重新初始化。

---

## ✅ 解决方案

### 方法 1: 重新初始化（推荐）

```bash
# 1. 删除旧的锁文件和 .terraform 目录
rm -rf .terraform .terraform.lock.hcl

# 2. 重新初始化
terraform init

# 3. 应用配置
terraform apply -auto-approve
```

### 方法 2: 升级锁文件

```bash
# 升级锁文件
terraform init -upgrade

# 然后应用
terraform apply -auto-approve
```

---

## 🚀 完整命令（在 CloudShell 中）

```bash
# 确保在正确的目录
cd ~/k8s-observability-platform/terraform/eks

# 删除旧的初始化文件
rm -rf .terraform .terraform.lock.hcl

# 重新初始化
terraform init

# 查看计划（可选）
terraform plan

# 创建集群
terraform apply -auto-approve
```

---

## 📋 步骤说明

1. **删除旧文件** - 清除可能冲突的锁文件
2. **重新初始化** - 下载正确的 provider 版本
3. **应用配置** - 创建 EKS 集群

---

## ⏱️ 时间估算

- 删除文件：几秒钟
- 初始化：1-2 分钟
- 创建集群：15-20 分钟
- **总计：约 20 分钟**

---

## 💡 如果仍然失败

如果 `terraform init` 仍然失败，检查：

1. **网络连接** - 确保 CloudShell 可以访问互联网
2. **权限** - 确保 AWS 凭证有足够权限
3. **Terraform 版本** - 当前是 1.6.0，应该足够

告诉我结果，我继续帮你！

