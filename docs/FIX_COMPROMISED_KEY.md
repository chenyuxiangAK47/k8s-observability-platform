# 修复 AWS 密钥泄露隔离问题

## 🔴 问题

AWS 检测到 Access Key 可能泄露，自动添加了 `AWSCompromisedKeyQuarantineV3` 隔离策略。

这个策略会 **deny 所有操作**，包括 ECR 权限。

---

## ✅ 解决方案

### 方案 1: 创建新的 Access Key（推荐）

**原因：** 旧的 Access Key 已被标记为泄露，即使移除隔离策略，也可能不安全。

#### Step 1: 创建新的 Access Key

1. **登录 AWS Console**
   - https://console.aws.amazon.com/

2. **进入 IAM → Users → github-actions**
   - 点击 **Security credentials** 标签

3. **创建新的 Access Key**
   - 找到 **Access keys** 部分
   - 点击 **Create access key**
   - 选择 **Command Line Interface (CLI)**
   - 点击 **Next** → **Create access key**
   - **立即保存新的 Access Key ID 和 Secret Access Key**

#### Step 2: 删除旧的 Access Key

1. **在 Access keys 列表中**
   - 找到旧的 Access Key：`AKIAUW4LOMD2F7BNAXGM`
   - 点击 **Delete**
   - 确认删除

#### Step 3: 移除隔离策略

1. **进入 Permissions 标签**
2. **找到 `AWSCompromisedKeyQuarantineV3` 策略**
3. **点击策略名称查看详情**
4. **点击 "删除"（Delete）按钮**
5. **确认删除**

#### Step 4: 更新 GitHub Secrets

1. **进入 GitHub 仓库设置**
   - https://github.com/chenyuxiangAK47/k8s-observability-platform/settings/secrets/actions

2. **更新 Secrets**
   - 点击 `AWS_ACCESS_KEY_ID` → **Update**
   - 输入新的 Access Key ID
   - 点击 `AWS_SECRET_ACCESS_KEY` → **Update**
   - 输入新的 Secret Access Key

#### Step 5: 验证

1. **重新运行 GitHub Actions 工作流**
2. **检查 "Login to Amazon ECR" 步骤**
   - 应该成功通过

---

### 方案 2: 只移除隔离策略（不推荐）

如果你确定旧的 Access Key 仍然安全：

1. **进入 IAM → Users → github-actions → Permissions**
2. **找到 `AWSCompromisedKeyQuarantineV3` 策略**
3. **点击 "删除"（Delete）**
4. **确认删除**

**⚠️ 注意：** 如果 Access Key 真的泄露了，只移除隔离策略不安全。建议使用方案 1。

---

## 🔒 安全建议

### 预防措施

1. **不要在代码中硬编码 Access Key**
   - 使用 GitHub Secrets
   - 使用环境变量
   - 使用 AWS IAM Roles（OIDC）

2. **定期轮换 Access Key**
   - 每 90 天更换一次
   - 删除未使用的 Access Key

3. **使用最小权限原则**
   - 只授予必要的权限
   - 定期审查权限

4. **启用 CloudTrail**
   - 监控 Access Key 使用情况
   - 检测异常活动

---

## 📋 快速修复清单

- [ ] 创建新的 Access Key
- [ ] 删除旧的 Access Key（`AKIAUW4LOMD2F7BNAXGM`）
- [ ] 移除隔离策略（`AWSCompromisedKeyQuarantineV3`）
- [ ] 更新 GitHub Secrets（`AWS_ACCESS_KEY_ID` 和 `AWS_SECRET_ACCESS_KEY`）
- [ ] 重新运行工作流验证

---

## 🆘 如果仍然失败

如果移除隔离策略后仍然失败：

1. **检查是否还有其他隔离策略**
2. **验证新的 Access Key 权限**
   ```powershell
   aws configure
   # 输入新的 Access Key
   aws ecr get-authorization-token --region us-east-1
   ```
3. **检查权限边界**
   - 确保权限边界允许 ECR 操作

---

## 💡 总结

**问题根源：** AWS 检测到 Access Key 泄露，自动隔离

**解决方案：** 创建新的 Access Key + 移除隔离策略 + 更新 GitHub Secrets

**预防措施：** 不要在代码中硬编码密钥，使用 GitHub Secrets

