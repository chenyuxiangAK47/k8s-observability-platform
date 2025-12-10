# 获取 AWS Access Key（无需修改密码）

## 🎯 问题说明

你遇到的错误：
```
You may not be authorized to perform this action, or the new password 
does not comply with the account password policy
```

**原因：**
- IAM 用户 `github-actions` 可能没有修改自己密码的权限
- 或者密码策略不符合要求

**好消息：** 对于 GitHub Actions，**你不需要控制台密码**，只需要 **Access Key**！

---

## ✅ 解决方案：直接创建 Access Key

### 方法 1: 使用根账号登录（如果有权限）

如果你有 AWS 根账号（主账号）的访问权限：

1. **使用根账号登录 AWS Console**
   - 不要使用 `github-actions` 用户登录
   - 使用创建这个账号的主邮箱登录

2. **进入 IAM → Users**
   - 找到 `github-actions` 用户
   - 点击用户名进入详情

3. **创建 Access Key**
   - 进入 **Security credentials** 标签
   - 找到 **Access keys** 部分
   - 点击 **Create access key**
   - 选择 **Command Line Interface (CLI)**
   - 点击 **Next** → **Create access key**
   - **立即保存 Access Key ID 和 Secret Access Key**

### 方法 2: 使用其他有权限的 IAM 用户

如果你有其他 IAM 用户有管理权限：

1. **使用有权限的用户登录**
   - 登录 AWS Console
   - 确保这个用户有 `IAMFullAccess` 或至少能管理其他用户

2. **进入 IAM → Users → github-actions**
   - 进入 **Security credentials** 标签
   - 创建 Access Key（同上）

### 方法 3: 创建新的 IAM 用户（推荐）

如果无法访问现有用户，创建一个新的：

1. **使用根账号或有权限的用户登录**

2. **创建新用户**
   - IAM → Users → Create user
   - 用户名：`github-actions-ci`（或任何你喜欢的名字）
   - 点击 **Next**

3. **设置权限**
   - 选择 **Attach policies directly**
   - 搜索并选择：
     - `AmazonEC2ContainerRegistryFullAccess`（ECR 访问）
     - `AmazonEKSClusterPolicy`（如果需要 EKS）
   - 点击 **Next** → **Create user**

4. **创建 Access Key**
   - 点击刚创建的用户
   - **Security credentials** → **Create access key**
   - 选择 **Command Line Interface (CLI)**
   - **保存 Access Key ID 和 Secret Access Key**

---

## 📋 配置 GitHub Secrets

获取 Access Key 后，配置 GitHub Secrets：

| Secret Name | Value |
|------------|-------|
| `AWS_ACCOUNT_ID` | `324025606388` |
| `AWS_ACCESS_KEY_ID` | 从上面获取的 Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | 从上面获取的 Secret Access Key |

---

## 🔑 重要说明

### 控制台密码 vs Access Key

| 类型 | 用途 | GitHub Actions 需要？ |
|------|------|---------------------|
| **控制台密码** | 登录 AWS Console | ❌ 不需要 |
| **Access Key** | 程序化访问 AWS API | ✅ **必须** |

**结论：** 你不需要修改控制台密码，只需要 Access Key！

---

## 🚀 快速步骤总结

1. **使用根账号或有权限的用户登录 AWS Console**
2. **进入 IAM → Users → github-actions**
3. **Security credentials → Create access key**
4. **保存 Access Key ID 和 Secret Access Key**
5. **配置 GitHub Secrets**

---

## 🆘 如果无法访问根账号

如果你无法访问根账号或其他有权限的用户：

1. **联系 AWS 账号管理员**
   - 请求为 `github-actions` 用户创建 Access Key
   - 或请求创建新的 IAM 用户用于 CI/CD

2. **使用 AWS CLI（如果已配置）**
   ```powershell
   # 如果你有其他用户的 Access Key
   aws configure
   # 然后创建新用户的 Access Key
   ```

---

## ✅ 验证

配置完 GitHub Secrets 后：

1. **触发工作流**
   - Actions → 选择工作流 → Run workflow

2. **检查结果**
   - "Configure AWS credentials" 步骤应该通过
   - 不再需要控制台密码

---

## 💡 总结

**你不需要修改控制台密码！**

只需要：
- ✅ Access Key ID
- ✅ Secret Access Key
- ✅ AWS Account ID（已有：`324025606388`）

使用有权限的账号登录，为 `github-actions` 用户创建 Access Key 即可。

