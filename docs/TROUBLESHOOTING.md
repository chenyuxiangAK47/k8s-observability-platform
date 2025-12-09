# 故障排查指南

## 常见错误和解决方案

### 错误 1: "Unable to connect to the server: dial tcp 127.0.0.1:56451"

**症状：**
```
Unable to connect to the server: dial tcp 127.0.0.1:56451: connectex: 
No connection could be made because the target machine actively refused it.
```

**原因：**
- Docker Desktop 未运行
- Kubernetes 集群（kind）未启动或已停止

**解决方案：**

#### 步骤 1: 检查 Docker Desktop

1. 在 Windows 开始菜单搜索 "Docker Desktop"
2. 启动 Docker Desktop
3. 等待 Docker Desktop 完全启动（系统托盘图标不再转圈）
4. 验证 Docker 运行：
   ```powershell
   docker ps
   ```

#### 步骤 2: 检查 kind 集群

```powershell
# 查看所有 kind 集群
kind get clusters

# 如果集群不存在，重新创建
kind create cluster --name monitoring-learning

# 如果集群存在但无法连接，删除并重建
kind delete cluster --name monitoring-learning
kind create cluster --name monitoring-learning
```

#### 步骤 3: 重新部署

```powershell
# 进入项目目录
cd D:\Myfile\另一个吹牛项目

# 运行一键部署脚本
.\scripts\setup-and-deploy.ps1
```

---

### 错误 2: "error during connect: open //./pipe/dockerDesktopLinuxEngine"

**症状：**
```
error during connect: Get "http://%2F%2F.%2Fpipe%2FdockerDesktopLinuxEngine/v1.48/containers/json":
open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified.
```

**原因：**
Docker Desktop 未运行或 Docker 服务未启动

**解决方案：**
1. 启动 Docker Desktop
2. 等待完全启动
3. 验证：`docker ps` 应该能正常执行

---

### 错误 3: PostgreSQL 连接失败

**症状：**
```
sqlalchemy.exc.OperationalError: connection to server at "postgresql.microservices.svc.cluster.local" 
(10.96.68.76), port 5432 failed: Connection refused
```

**原因：**
- PostgreSQL Pod 未就绪
- 数据库初始化失败

**解决方案：**

```powershell
# 检查 PostgreSQL Pod 状态
kubectl get pods -n microservices -l app=postgresql

# 查看 Pod 日志
kubectl logs -n microservices postgresql-0

# 如果 Pod 卡在 Init:0/1，检查 init container
kubectl describe pod -n microservices postgresql-0

# 删除并重新部署 PostgreSQL
kubectl delete -f k8s/database/postgresql.yaml
kubectl apply -f k8s/database/postgresql.yaml

# 等待 Pod 就绪
kubectl wait --for=condition=ready pod -n microservices -l app=postgresql --timeout=300s
```

---

### 错误 4: Grafana 登录失败

**症状：**
- 输入 admin/admin 提示 "Invalid username or password"

**原因：**
Prometheus Operator 生成的 Grafana 使用了随机密码

**解决方案：**

```powershell
# 获取生成的密码
kubectl get secret -n observability prometheus-operator-grafana -o jsonpath="{.data.admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# 或者重置为 admin（仅用于学习环境）
kubectl patch secret -n observability prometheus-operator-grafana -p '{"data":{"admin-password":"' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("admin")) + '"}}'
```

---

### 错误 5: Prometheus 数据源 "no such host"

**症状：**
Grafana 中 Prometheus 数据源显示 "no such host" 错误

**原因：**
Prometheus Service 名称配置错误

**解决方案：**

1. 检查 Prometheus Service 名称：
   ```powershell
   kubectl get svc -n monitoring | grep prometheus
   ```

2. 在 Grafana 中更新数据源 URL：
   - 进入 Configuration > Data Sources > Prometheus
   - 将 URL 更新为正确的 Service 名称
   - 例如：`http://prometheus-operator-kube-p-prometheus.monitoring.svc.cluster.local:9090`

---

### 错误 6: 端口转发被拒绝

**症状：**
```
error: unable to forward port because pod is not running
```

**原因：**
- Pod 未运行
- Pod 名称或命名空间错误

**解决方案：**

```powershell
# 检查 Pod 状态
kubectl get pods -n microservices

# 检查 Pod 日志
kubectl logs -n microservices <pod-name>

# 确保 Pod 运行后再进行端口转发
kubectl wait --for=condition=ready pod -n microservices -l app=user-service --timeout=300s
kubectl port-forward -n microservices svc/user-service 8001:8001
```

---

### 错误 7: PowerShell 脚本编码问题

**症状：**
```
ParserError: 字符串缺少终止符
```

**原因：**
PowerShell 脚本包含中文字符，编码问题

**解决方案：**
- 使用 UTF-8 with BOM 编码保存脚本
- 或者使用英文文本重写脚本

---

## 快速诊断命令

```powershell
# 1. 检查 Docker Desktop
docker ps

# 2. 检查 kind 集群
kind get clusters
kubectl cluster-info

# 3. 检查所有 Pod 状态
kubectl get pods --all-namespaces

# 4. 检查所有 Service
kubectl get svc --all-namespaces

# 5. 检查所有 Deployment
kubectl get deployments --all-namespaces

# 6. 检查事件（查看错误）
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | Select-Object -Last 20
```

---

## 完全重置（最后手段）

如果所有方法都失败，可以完全重置：

```powershell
# 1. 删除所有 kind 集群
kind delete cluster --name monitoring-learning

# 2. 停止 Docker Desktop（可选，如果需要）

# 3. 重新创建集群
kind create cluster --name monitoring-learning

# 4. 重新部署
.\scripts\setup-and-deploy.ps1
```

---

## 获取帮助

如果问题仍然存在：

1. 收集错误信息：
   ```powershell
   kubectl get pods --all-namespaces
   kubectl get events --all-namespaces --sort-by='.lastTimestamp' | Select-Object -Last 50
   ```

2. 检查日志：
   ```powershell
   kubectl logs -n <namespace> <pod-name> --tail=100
   ```

3. 查看 Pod 详细信息：
   ```powershell
   kubectl describe pod -n <namespace> <pod-name>
   ```













