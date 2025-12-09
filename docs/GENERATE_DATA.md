# 生成微服务数据指南

## 问题：Grafana Explore 显示 "No data"

### 原因
微服务还没有产生 HTTP 请求数据，所以 Prometheus 中没有指标数据。

### 解决方案：测试微服务 API 产生数据

## 步骤 1: 启动微服务端口转发

在新 PowerShell 窗口中运行：

```powershell
kubectl port-forward -n microservices svc/user-service 8001:8001
```

保持这个窗口打开。

## 步骤 2: 测试 API（产生请求数据）

在另一个 PowerShell 窗口中运行：

```powershell
# 创建用户
Invoke-RestMethod -Uri "http://localhost:8001/api/users" -Method POST -ContentType "application/json" -Body '{"email":"test@example.com","name":"Test User","password":"123456"}'

# 获取用户（假设用户 ID 是 1）
Invoke-RestMethod -Uri "http://localhost:8001/api/users/1"

# 再创建几个用户（产生更多数据）
Invoke-RestMethod -Uri "http://localhost:8001/api/users" -Method POST -ContentType "application/json" -Body '{"email":"user2@example.com","name":"User 2","password":"123456"}'
Invoke-RestMethod -Uri "http://localhost:8001/api/users" -Method POST -ContentType "application/json" -Body '{"email":"user3@example.com","name":"User 3","password":"123456"}'
```

## 步骤 3: 回到 Grafana Explore

1. 刷新 Grafana Explore 页面
2. 重新运行查询：`user_service_http_requests_total`
3. 应该能看到数据了！

## 步骤 4: 测试完整业务流程（产生更多数据）

### 启动所有微服务端口转发

```powershell
# User Service (端口 8001)
kubectl port-forward -n microservices svc/user-service 8001:8001

# Product Service (端口 8002) - 新窗口
kubectl port-forward -n microservices svc/product-service 8002:8002

# Order Service (端口 8003) - 新窗口
kubectl port-forward -n microservices svc/order-service 8003:8003
```

### 测试完整业务流程

```powershell
# 1. 创建用户
$user = Invoke-RestMethod -Uri "http://localhost:8001/api/users" -Method POST -ContentType "application/json" -Body '{"email":"buyer@example.com","name":"Buyer","password":"123456"}'
$userId = $user.id

# 2. 创建商品
$product = Invoke-RestMethod -Uri "http://localhost:8002/api/products/" -Method POST -ContentType "application/json" -Body '{"name":"MacBook Pro","description":"Laptop","price":12999.0,"stock":50}'
$productId = $product.id

# 3. 创建订单（这会调用多个服务）
$order = Invoke-RestMethod -Uri "http://localhost:8003/api/orders" -Method POST -ContentType "application/json" -Body "{`"user_id`":$userId,`"product_id`":$productId,`"quantity`":1}"
```

## 步骤 5: 在 Grafana 中查看数据

### 查看各个服务的指标

```
# User Service
user_service_http_requests_total

# Product Service
product_service_http_requests_total

# Order Service
order_service_http_requests_total
```

### 查看服务间调用

```
# Order Service 调用其他服务的次数
service_calls_total
```

### 查看请求速率

```
# User Service QPS
rate(user_service_http_requests_total[5m])

# 所有服务的总 QPS
sum(rate(user_service_http_requests_total[5m])) + sum(rate(product_service_http_requests_total[5m])) + sum(rate(order_service_http_requests_total[5m]))
```

## 💡 提示

1. **等待几秒**：Prometheus 每 15 秒采集一次数据，所以可能需要等待一下
2. **刷新查询**：在 Grafana Explore 中点击 "Run query" 刷新数据
3. **查看时间范围**：确保时间范围设置正确（右上角的时间选择器）
4. **使用预置 Dashboard**：如果微服务数据还没生成，可以先查看 Kubernetes 预置 Dashboard，它们有系统指标数据

## 🎯 快速测试脚本

运行 `.\scripts\test-api.ps1` 可以自动测试所有 API 并产生数据。














