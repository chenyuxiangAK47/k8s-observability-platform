# AWS 迁移快速开始

## 🚀 5 分钟快速配置

### Step 1: 获取 AWS 凭证（2 分钟）

1. **登录 AWS Console**
   - https://console.aws.amazon.com/

2. **创建 IAM 用户**
   - IAM → Users → Create user
   - 用户名：`github-actions`
   - 附加策略：`AmazonEC2ContainerRegistryFullAccess`
   - 创建 Access Key
   - **保存 Access Key ID 和 Secret Access Key**

3. **获取 Account ID**
   - AWS Console 右上角显示，或
   ```powershell
   aws sts get-caller-identity --query Account --output text
   ```

### Step 2: 配置 GitHub Secrets（1 分钟）

1. **进入仓库设置**
   - https://github.com/chenyuxiangAK47/k8s-observability-platform/settings/secrets/actions

2. **添加 3 个 Secrets**
   - `AWS_ACCOUNT_ID` = 你的 AWS 账号 ID
   - `AWS_ACCESS_KEY_ID` = 从 Step 1 获取
   - `AWS_SECRET_ACCESS_KEY` = 从 Step 1 获取

### Step 3: 测试工作流（2 分钟）

1. **触发工作流**
   - 推送代码，或
   - Actions → 选择工作流 → Run workflow

2. **验证**
   - 检查 "Configure AWS credentials" 是否通过
   - 检查镜像是否推送到 ECR

---

## ✅ 完成！

如果工作流成功运行，说明配置正确。

下一步：创建 EKS 集群（使用 Terraform）

```powershell
.\scripts\setup-aws-eks.ps1
```

---

## 📚 详细文档

- [GitHub Secrets 配置指南](GITHUB_SECRETS_SETUP.md)
- [AWS 迁移完整指南](AWS_MIGRATION_GUIDE.md)
- [AWS 设置说明](AWS_SETUP_INSTRUCTIONS.md)

