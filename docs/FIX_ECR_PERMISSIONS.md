# 修复 ECR 权限问题

## 🔴 错误信息

```
User: arn:aws:iam::***:user/github-actions is not authorized to perform: 
ecr:GetAuthorizationToken on resource: *
```

**原因：** IAM 用户 `github-actions` 缺少 ECR 权限。

---

## ✅ 解决方案

### 方法 1: 附加 AWS 托管策略（最简单，推荐）

1. **登录 AWS Console**
   - 使用根账号或有权限的用户登录
   - 访问：https://console.aws.amazon.com/

2. **进入 IAM → Users**
   - 找到 `github-actions` 用户
   - 点击用户名进入详情

3. **附加策略**
   - 点击 **Permissions** 标签
   - 点击 **Add permissions** → **Attach policies directly**
   - 搜索并选择：**`AmazonEC2ContainerRegistryFullAccess`**
   - 点击 **Next** → **Add permissions**

4. **验证**
   - 确保策略已附加
   - 策略应该包含以下权限：
     - `ecr:GetAuthorizationToken`
     - `ecr:*`（所有 ECR 操作）

### 方法 2: 创建自定义策略（更精细控制）

如果你想要更精细的权限控制：

1. **进入 IAM → Policies**
   - 点击 **Create policy**
   - 选择 **JSON** 标签

2. **粘贴以下策略：**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ecr:GetAuthorizationToken"
         ],
         "Resource": "*"
       },
       {
         "Effect": "Allow",
         "Action": [
           "ecr:BatchCheckLayerAvailability",
           "ecr:GetDownloadUrlForLayer",
           "ecr:BatchGetImage",
           "ecr:PutImage",
           "ecr:InitiateLayerUpload",
           "ecr:UploadLayerPart",
           "ecr:CompleteLayerUpload"
         ],
         "Resource": "arn:aws:ecr:us-east-1:324025606388:repository/*"
       }
     ]
   }
   ```

3. **命名策略**
   - Policy name: `GitHubActionsECRPolicy`
   - 点击 **Create policy**

4. **附加到用户**
   - 回到 IAM → Users → github-actions
   - Permissions → Add permissions → Attach policies directly
   - 搜索 `GitHubActionsECRPolicy`
   - 选择并附加

---

## 🔍 验证权限

### 使用 AWS CLI 验证

```powershell
# 配置 AWS CLI（如果还没配置）
aws configure
# 输入 Access Key ID: <你的 Access Key ID>
# 输入 Secret Access Key: <你的 Secret Access Key>
# 输入 region: us-east-1

# 测试 ECR 权限
aws ecr get-authorization-token --region us-east-1

# 如果成功，会返回授权令牌
# 如果失败，会显示权限错误
```

### 检查当前权限

```powershell
# 查看用户附加的策略
aws iam list-attached-user-policies --user-name github-actions

# 查看用户的内联策略
aws iam list-user-policies --user-name github-actions

# 查看策略详情
aws iam get-policy --policy-arn <策略ARN>
```

---

## 📋 完整权限清单

GitHub Actions 需要以下 ECR 权限：

| 权限 | 用途 | 必需？ |
|------|------|--------|
| `ecr:GetAuthorizationToken` | 获取 ECR 登录令牌 | ✅ 必须 |
| `ecr:BatchCheckLayerAvailability` | 检查镜像层 | ✅ 必须 |
| `ecr:GetDownloadUrlForLayer` | 下载镜像层 | ✅ 必须 |
| `ecr:BatchGetImage` | 获取镜像 | ✅ 必须 |
| `ecr:PutImage` | 推送镜像 | ✅ 必须 |
| `ecr:InitiateLayerUpload` | 开始上传层 | ✅ 必须 |
| `ecr:UploadLayerPart` | 上传层部分 | ✅ 必须 |
| `ecr:CompleteLayerUpload` | 完成层上传 | ✅ 必须 |

**最简单方法：** 使用 `AmazonEC2ContainerRegistryFullAccess` 策略，包含所有上述权限。

---

## 🚀 快速修复步骤

1. **登录 AWS Console**
   - https://console.aws.amazon.com/

2. **IAM → Users → github-actions**
   - 点击 **Permissions** 标签

3. **检查当前策略**
   - 如果看到 `AmazonEC2ContainerRegistryFullAccess`，但仍有错误
   - 可能需要等待几分钟让权限生效

4. **如果没有策略，添加：**
   - **Add permissions** → **Attach policies directly**
   - 搜索：`AmazonEC2ContainerRegistryFullAccess`
   - 选择并附加

5. **等待 1-2 分钟**
   - IAM 权限更改可能需要几秒钟生效

6. **重新运行工作流**
   - GitHub Actions → 选择工作流 → **Re-run jobs**

---

## 🆘 如果仍然失败

### 检查 1: 策略是否正确附加

在 IAM → Users → github-actions → Permissions，确保看到：
- ✅ `AmazonEC2ContainerRegistryFullAccess` 或
- ✅ 自定义策略包含 `ecr:GetAuthorizationToken`

### 检查 2: 区域是否正确

确保：
- GitHub Actions 使用的区域是 `us-east-1`
- IAM 策略没有区域限制

### 检查 3: 等待权限生效

IAM 权限更改通常立即生效，但有时需要等待 1-2 分钟。

### 检查 4: 验证 Access Key

确保 GitHub Secrets 中的 Access Key 是正确的：
- `AWS_ACCESS_KEY_ID` = `AKIAUW4LOMD2F7BNAXGM`
- `AWS_SECRET_ACCESS_KEY` = `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`

---

## ✅ 验证修复

修复后，重新运行工作流：

1. **进入 GitHub Actions**
2. **选择失败的工作流运行**
3. **点击 "Re-run jobs"**
4. **检查 "Login to Amazon ECR" 步骤**
   - 应该成功通过
   - 不再显示权限错误

---

## 💡 最佳实践

### 生产环境建议

1. **使用最小权限原则**
   - 只授予必要的权限
   - 限制资源范围（如特定 ECR 仓库）

2. **使用 IAM Roles（OIDC）**
   - 更安全，不需要存储 Access Key
   - 参考 `docs/GITHUB_SECRETS_SETUP.md` 中的 OIDC 方案

3. **定期轮换 Access Key**
   - 每 90 天更换一次
   - 删除未使用的 Access Key

---

## 📝 总结

**问题：** IAM 用户缺少 `ecr:GetAuthorizationToken` 权限

**解决：** 附加 `AmazonEC2ContainerRegistryFullAccess` 策略

**步骤：**
1. AWS Console → IAM → Users → github-actions
2. Permissions → Add permissions
3. 附加 `AmazonEC2ContainerRegistryFullAccess`
4. 等待 1-2 分钟
5. 重新运行工作流

修复后，工作流应该能成功登录 ECR 并推送镜像！

