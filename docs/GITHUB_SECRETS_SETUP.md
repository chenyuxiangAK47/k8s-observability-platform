# GitHub Secrets 配置指南

## 🔴 错误信息

```
Credentials could not be loaded, please check your action inputs: 
Could not load credentials from any providers
```

**原因：** GitHub Actions 工作流需要 AWS 凭证来访问 ECR，但 GitHub Secrets 中还没有配置。

---

## ✅ 解决方案（两种方式）

### 方案 1: 使用静态 Access Keys（简单，快速）

适合快速测试和开发环境。

#### Step 1: 获取 AWS Access Keys

1. **登录 AWS Console**
   - 访问 https://console.aws.amazon.com/
   - 使用你的 AWS 账号登录

2. **创建 IAM 用户（如果还没有）**
   - 进入 **IAM** → **Users**
   - 点击 **Create user**
   - 用户名：`github-actions-ecr`
   - 选择 **Provide user access to the AWS Management Console**（可选）
   - 点击 **Next**

3. **设置权限**
   - 选择 **Attach policies directly**
   - 搜索并选择以下策略：
     - `AmazonEC2ContainerRegistryFullAccess`（ECR 完整访问）
     - `AmazonEKSClusterPolicy`（如果需要部署到 EKS）
   - 点击 **Next** → **Create user**

4. **创建 Access Key**
   - 点击刚创建的用户
   - 进入 **Security credentials** 标签
   - 点击 **Create access key**
   - 选择 **Command Line Interface (CLI)**
   - 点击 **Next** → **Create access key**
   - **重要：** 立即下载或复制：
     - **Access Key ID**
     - **Secret Access Key**（只显示一次！）

5. **获取 AWS Account ID**
   ```powershell
   aws sts get-caller-identity --query Account --output text
   ```
   或从 AWS Console 右上角查看。

#### Step 2: 配置 GitHub Secrets

1. **进入 GitHub 仓库**
   - 打开你的仓库：https://github.com/chenyuxiangAK47/k8s-observability-platform

2. **进入 Secrets 设置**
   - 点击 **Settings**（仓库设置）
   - 左侧菜单 → **Secrets and variables** → **Actions**

3. **添加 Secrets**
   点击 **New repository secret**，依次添加：

   | Secret Name | Value | 说明 |
   |------------|-------|------|
   | `AWS_ACCOUNT_ID` | `123456789012` | 你的 AWS 账号 ID（12 位数字） |
   | `AWS_ACCESS_KEY_ID` | `AKIA...` | 从 Step 1 获取的 Access Key ID |
   | `AWS_SECRET_ACCESS_KEY` | `...` | 从 Step 1 获取的 Secret Access Key |

4. **验证**
   - 确保所有 3 个 secrets 都已添加
   - 名称必须完全匹配（区分大小写）

#### Step 3: 验证工作流

1. **触发工作流**
   - 推送代码到仓库，或
   - 进入 **Actions** → 选择工作流 → **Run workflow**

2. **检查结果**
   - 工作流应该能成功连接到 AWS
   - "Configure AWS credentials" 步骤应该通过

---

### 方案 2: 使用 OIDC（推荐，更安全）

适合生产环境，不需要存储静态密钥。

#### Step 1: 创建 IAM Role

1. **进入 IAM → Roles**
   - 点击 **Create role**

2. **选择信任实体类型**
   - 选择 **Web identity**
   - Identity provider: 选择 **GitHub**（如果没有，需要先配置）
   - Audience: 选择或输入 `sts.amazonaws.com`

3. **配置条件**
   - 添加条件：
     ```
     StringEquals:
       token.actions.githubusercontent.com:aud: sts.amazonaws.com
     StringLike:
       token.actions.githubusercontent.com:sub: repo:chenyuxiangAK47/k8s-observability-platform:*
     ```

4. **附加策略**
   - `AmazonEC2ContainerRegistryFullAccess`
   - `AmazonEKSClusterPolicy`（如果需要）

5. **创建 Role**
   - Role name: `GitHubActionsECRRole`
   - 记录 Role ARN（格式：`arn:aws:iam::<ACCOUNT_ID>:role/GitHubActionsECRRole`）

#### Step 2: 配置 GitHub OIDC Provider（如果还没有）

1. **进入 IAM → Identity providers**
   - 点击 **Add provider**
   - Provider type: **OpenID Connect**
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
   - 点击 **Add provider**

#### Step 3: 更新工作流文件

更新 `.github/workflows/cicd-aws-ecr.yml`：

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/GitHubActionsECRRole
    aws-region: us-east-1
```

替换 `<ACCOUNT_ID>` 为你的 AWS 账号 ID。

#### Step 4: 更新 GitHub Secrets

只需要添加：
- `AWS_ACCOUNT_ID`（用于构建 ECR 地址）

不需要 `AWS_ACCESS_KEY_ID` 和 `AWS_SECRET_ACCESS_KEY`。

---

## 📋 快速检查清单

### 使用静态密钥（方案 1）

- [ ] 已创建 IAM 用户
- [ ] 已附加 `AmazonEC2ContainerRegistryFullAccess` 策略
- [ ] 已创建 Access Key
- [ ] 已保存 Access Key ID 和 Secret Access Key
- [ ] 已在 GitHub Secrets 中添加 `AWS_ACCOUNT_ID`
- [ ] 已在 GitHub Secrets 中添加 `AWS_ACCESS_KEY_ID`
- [ ] 已在 GitHub Secrets 中添加 `AWS_SECRET_ACCESS_KEY`
- [ ] 已触发工作流测试

### 使用 OIDC（方案 2）

- [ ] 已配置 GitHub OIDC Provider
- [ ] 已创建 IAM Role
- [ ] 已配置信任关系
- [ ] 已附加必要策略
- [ ] 已更新工作流文件使用 `role-to-assume`
- [ ] 已在 GitHub Secrets 中添加 `AWS_ACCOUNT_ID`
- [ ] 已触发工作流测试

---

## 🔧 故障排除

### 错误: "Access Denied"

**原因：** IAM 用户/角色权限不足

**解决：**
1. 检查 IAM 用户/角色是否附加了 `AmazonEC2ContainerRegistryFullAccess` 策略
2. 如果使用 EKS，还需要 `AmazonEKSClusterPolicy`

### 错误: "Invalid credentials"

**原因：** Access Key 错误或已过期

**解决：**
1. 检查 GitHub Secrets 中的值是否正确
2. 检查 Access Key 是否已删除或禁用
3. 重新创建 Access Key

### 错误: "Role cannot be assumed"

**原因：** OIDC 信任关系配置错误

**解决：**
1. 检查 IAM Role 的信任关系
2. 确保 GitHub OIDC Provider 已配置
3. 检查条件中的仓库名称是否正确

---

## 💡 推荐

- **开发/测试环境：** 使用方案 1（静态密钥），简单快速
- **生产环境：** 使用方案 2（OIDC），更安全

---

## 📝 下一步

配置完 Secrets 后：

1. **触发工作流**
   - 推送代码，或
   - 手动运行工作流

2. **验证**
   - 检查 "Configure AWS credentials" 步骤是否通过
   - 检查镜像是否成功推送到 ECR

3. **查看 ECR**
   ```powershell
   aws ecr describe-repositories --region us-east-1
   ```

---

## 🆘 需要帮助？

如果遇到问题，请提供：
- 错误信息截图
- IAM 用户/角色配置
- GitHub Secrets 名称（不提供值）

