# 修复显式 Deny 策略问题

## 🔴 错误信息

```
User: arn:aws:iam::***:user/github-actions is not authorized to perform: 
ecr:GetAuthorizationToken on resource: * with an explicit deny in an identity-based policy
```

**关键问题：** 有一个**显式的 Deny 策略**覆盖了 Allow 策略，阻止了 ECR 权限。

---

## ✅ 解决方案

### Step 1: 检查附加的策略

1. **登录 AWS Console**
   - https://console.aws.amazon.com/

2. **进入 IAM → Users → github-actions**
   - 点击 **Permissions** 标签

3. **检查所有附加的策略**
   - 查看是否有任何策略包含 `Deny` 语句
   - 特别检查是否有策略明确 deny `ecr:*` 或 `ecr:GetAuthorizationToken`

### Step 2: 检查权限边界（Permission Boundary）

1. **在用户详情页面，找到 "Permissions boundary" 部分**
   - 如果设置了权限边界，点击查看详情

2. **检查权限边界策略**
   - 确保权限边界策略允许 `ecr:GetAuthorizationToken`
   - 如果有 deny，需要更新权限边界策略

### Step 3: 检查内联策略（Inline Policies）

1. **在 Permissions 标签，找到 "Permissions policies" 部分**
   - 查看是否有内联策略（Inline policies）

2. **检查内联策略内容**
   - 如果有内联策略包含 deny 语句，需要删除或修改

### Step 4: 检查服务控制策略（SCP）- 如果使用 AWS Organizations

如果你使用 AWS Organizations：

1. **进入 AWS Organizations Console**
2. **检查 SCP（Service Control Policies）**
   - 确保没有 SCP deny ECR 权限

---

## 🔧 快速修复步骤

### 方法 1: 移除显式 Deny（推荐）

1. **找到包含 deny 的策略**
   - IAM → Users → github-actions → Permissions
   - 检查所有策略

2. **编辑或删除 deny 策略**
   - 如果策略是自定义的，编辑它移除 deny 语句
   - 如果是 AWS 托管策略，检查是否有冲突的策略

3. **确保 Allow 策略优先级更高**
   - `AmazonEC2ContainerRegistryFullAccess` 应该允许所有 ECR 操作
   - 确保没有其他策略 deny 这些操作

### 方法 2: 创建新的 IAM 用户（如果无法修复）

如果无法找到或修复 deny 策略：

1. **创建新的 IAM 用户**
   - IAM → Users → Create user
   - 用户名：`github-actions-new`

2. **附加策略**
   - `AmazonEC2ContainerRegistryFullAccess`

3. **创建 Access Key**
   - 更新 GitHub Secrets 使用新的 Access Key

---

## 📋 检查清单

- [ ] 检查所有附加的策略（AWS 托管 + 自定义）
- [ ] 检查权限边界（Permission Boundary）
- [ ] 检查内联策略（Inline Policies）
- [ ] 检查服务控制策略（SCP）- 如果使用 Organizations
- [ ] 确保 `AmazonEC2ContainerRegistryFullAccess` 已附加
- [ ] 确保没有其他策略 deny ECR 权限

---

## 🔍 使用 AWS CLI 检查

```powershell
# 查看用户的所有策略
aws iam list-attached-user-policies --user-name github-actions

# 查看用户的内联策略
aws iam list-user-policies --user-name github-actions

# 查看权限边界
aws iam get-user --user-name github-actions --query 'User.PermissionsBoundary'

# 查看策略内容（替换 <policy-arn>）
aws iam get-policy-version --policy-arn <policy-arn> --version-id <version-id>
```

---

## 💡 常见原因

1. **自定义策略包含 deny**
   - 检查是否有自定义策略明确 deny ECR

2. **权限边界限制**
   - 权限边界会限制所有策略的权限

3. **策略冲突**
   - 多个策略，其中一个 deny，另一个 allow
   - Deny 总是优先于 Allow

4. **SCP 限制**
   - 如果使用 AWS Organizations，SCP 可能限制权限

---

## 🚀 推荐操作

### 立即操作

1. **检查 IAM 用户策略**
   - 确保只有 `AmazonEC2ContainerRegistryFullAccess` 附加
   - 移除任何包含 deny 的策略

2. **检查权限边界**
   - 如果设置了，确保允许 ECR 操作

3. **重新运行工作流**
   - 修复后，重新运行 GitHub Actions 工作流

---

## 📝 如果仍然失败

如果修复后仍然失败：

1. **创建新的 IAM 用户**
   - 使用全新的用户，只附加必要的策略

2. **更新 GitHub Secrets**
   - 使用新用户的 Access Key

3. **验证权限**
   ```powershell
   aws ecr get-authorization-token --region us-east-1
   ```

---

## ✅ 验证修复

修复后，验证权限：

```powershell
# 使用新的 Access Key 配置 AWS CLI
aws configure

# 测试 ECR 权限
aws ecr get-authorization-token --region us-east-1

# 如果成功，会返回授权令牌
# 如果失败，会显示权限错误
```

---

## 🆘 需要帮助？

如果无法找到 deny 策略，请提供：
- IAM 用户的所有附加策略列表
- 权限边界信息
- 是否使用 AWS Organizations

我可以帮你进一步排查。

