# 修复部署问题指南

## 问题 1: RabbitMQ Service 缺少 Port Name

### 错误信息
```
The Service "rabbitmq" is invalid: 
* spec.ports[0].name: Required value
* spec.ports[1].name: Required value
```

### 解决方案
已修复脚本，添加了 port name：
```yaml
ports:
- name: amqp
  port: 5672
  targetPort: 5672
- name: management
  port: 15672
  targetPort: 15672
```

### 手动修复
```bash
kubectl delete svc rabbitmq -n microservices
# 然后重新运行部署脚本
```

---

## 问题 2: PostgreSQL Pod 处于 Pending 状态

### 可能原因
1. **存储类问题**：EKS 可能没有默认的 StorageClass
2. **资源不足**：节点资源不足
3. **PVC 无法创建**：权限问题

### 检查方法
```bash
# 查看 Pod 详情
kubectl describe pod postgresql-0 -n microservices

# 查看 PVC 状态
kubectl get pvc -n microservices

# 查看节点资源
kubectl top nodes
```

### 解决方案

#### 方案 1: 创建 StorageClass（如果缺失）
```bash
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp2
provisioner: ebs.csi.aws.com
parameters:
  type: gp2
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

# 标记为默认
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

#### 方案 2: 使用临时存储（快速测试）
修改 StatefulSet，使用 emptyDir：
```bash
kubectl patch statefulset postgresql -n microservices --type='json' -p='[
  {"op": "remove", "path": "/spec/volumeClaimTemplates"},
  {"op": "add", "path": "/spec/template/spec/volumes", "value": [{"name": "data", "emptyDir": {}}]}
]'
```

---

## 问题 3: ArgoCD 未安装

### 检查方法
```bash
# 查看 ArgoCD Pod
kubectl get pods -n argocd

# 查看 ArgoCD 安装状态
kubectl get all -n argocd
```

### 解决方案

#### 手动安装 ArgoCD
```bash
# 创建命名空间
kubectl create namespace argocd

# 安装 ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 等待安装完成（3-5 分钟）
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=600s

# 获取密码
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

---

## 问题 4: Git Push 认证问题

### 错误信息
```
Username for 'https://github.com': Password for 'https://...@github.com': 这个咋输入 粘在一起了
```

### 解决方案

#### 方案 1: 使用 Personal Access Token（推荐）
```bash
# 1. 在 GitHub 创建 Personal Access Token
# Settings > Developer settings > Personal access tokens > Tokens (classic)
# 权限：repo (全部)

# 2. 配置 Git 使用 Token
git config --global credential.helper store
git push
# Username: chenyuxiangAK47
# Password: <你的 Personal Access Token>
```

#### 方案 2: 使用 SSH（推荐长期使用）
```bash
# 1. 生成 SSH 密钥（如果还没有）
ssh-keygen -t ed25519 -C "your_email@example.com"

# 2. 复制公钥
cat ~/.ssh/id_ed25519.pub

# 3. 添加到 GitHub
# Settings > SSH and GPG keys > New SSH key

# 4. 更改远程 URL
git remote set-url origin git@github.com:chenyuxiangAK47/k8s-observability-platform.git

# 5. 测试
ssh -T git@github.com

# 6. 推送
git push
```

#### 方案 3: 在 CloudShell 中配置（临时）
```bash
# 设置 Git 用户信息
git config --global user.name "chenyuxiangAK47"
git config --global user.email "e1582387@u.nus.edu"

# 使用 Token 推送（一次性）
git push https://<TOKEN>@github.com/chenyuxiangAK47/k8s-observability-platform.git
```

---

## 快速修复命令（复制粘贴）

```bash
# 1. 修复 RabbitMQ Service
kubectl delete svc rabbitmq -n microservices
# 重新运行部署脚本

# 2. 创建 StorageClass（如果 PostgreSQL 卡住）
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp2
provisioner: ebs.csi.aws.com
parameters:
  type: gp2
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# 3. 手动安装 ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. 配置 Git（使用 Token）
git config --global credential.helper store
# 然后 git push，输入 Token 作为密码
```

---

## 验证修复

```bash
# 检查所有 Pod
kubectl get pods -n microservices
kubectl get pods -n argocd

# 检查 Service
kubectl get svc -n microservices

# 检查 ArgoCD
kubectl get applications -n argocd
```

