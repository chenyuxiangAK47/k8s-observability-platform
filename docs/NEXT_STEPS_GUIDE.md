# 下一步操作指南

## ✅ 当前状态

- ✅ 所有微服务已部署并运行
- ✅ 可观测性平台已部署（Prometheus、Loki、Jaeger、Grafana）
- ✅ PostgreSQL 和 RabbitMQ 已运行

## 📋 下一步操作

### 步骤 1: 启动端口转发

**方法 A: 使用脚本（推荐）**
```powershell
.\scripts\start-port-forwards.ps1
```

**方法 B: 手动启动（只启动 Grafana）**
```powershell
kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80
```

### 步骤 2: 配置 Grafana Prometheus 数据源

1. **访问 Grafana**
   - 打开浏览器访问: http://localhost:3000
   - 用户名: `admin`
   - 密码: `kLroxB5N2vTDsfo8g21No0ExXike3QJZlazZv8Uy`

2. **配置 Prometheus 数据源**
   - 点击左侧 **Connections > Data sources**
   - 点击 **prometheus-1**
   - 在 **Connection** 部分，修改 **Prometheus server URL** 为：
     ```
     http://prometheus-operator-kube-p-prometheus.monitoring.svc.cluster.local:9090
     ```
   - 点击 **Save & test**
   - 应该看到绿色的成功消息

### 步骤 3: 探索微服务指标

1. **使用 Explore 功能**
   - 点击左侧 **Explore**
   - 选择 **Prometheus** 数据源
   - 输入查询：
     ```
     user_service_http_requests_total
     ```
   - 点击 **Run query**
   - 应该能看到数据图表

2. **尝试其他查询**
   ```
   # 查看所有微服务请求
   user_service_http_requests_total
   product_service_http_requests_total
   order_service_http_requests_total
   
   # 按状态码分组
   sum by (status) (user_service_http_requests_total)
   
   # 请求速率（QPS）
   rate(user_service_http_requests_total[5m])
   ```

### 步骤 4: 查看预置 Dashboard

1. **浏览 Dashboard**
   - 点击左侧 **Dashboards**
   - 查看 Prometheus Operator 自带的 Dashboard：
     - Kubernetes / Compute Resources / Cluster
     - Kubernetes / Compute Resources / Namespace (Pods)
     - Kubernetes / Compute Resources / Pod

2. **查看微服务 Dashboard**
   - 搜索 "microservices" 相关的 Dashboard
   - 或者创建自定义 Dashboard

### 步骤 5: 创建自定义 Dashboard

1. **创建新 Dashboard**
   - 点击 **Dashboards > New > New dashboard**
   - 点击 **Add visualization**
   - 选择 **Prometheus** 数据源

2. **添加微服务指标 Panel**
   - 查询: `user_service_http_requests_total`
   - 可视化类型: Time series
   - 设置标题: "User Service HTTP Requests"

3. **添加更多 Panel**
   - CPU 使用率
   - 内存使用率
   - 请求延迟
   - 错误率

### 步骤 6: 配置其他数据源（可选）

#### Loki（日志）

1. 点击 **Connections > Data sources > Add new connection**
2. 搜索并选择 **Loki**
3. 配置：
   - **Name**: `loki`
   - **URL**: `http://loki-gateway.observability.svc.cluster.local:80`
4. 点击 **Save & test**

#### Jaeger（追踪）

1. 点击 **Connections > Data sources > Add new connection**
2. 搜索并选择 **Jaeger**
3. 配置：
   - **Name**: `jaeger`
   - **URL**: `http://observability-platform-jaeger-query.observability.svc.cluster.local:80`
4. 点击 **Save & test**

### 步骤 7: 测试微服务并查看追踪

1. **启动微服务端口转发**
   ```powershell
   kubectl port-forward -n microservices svc/user-service 8001:8001
   ```

2. **测试 API**
   ```powershell
   Invoke-RestMethod -Uri "http://localhost:8001/api/users" -Method POST -ContentType "application/json" -Body '{"email":"test@example.com","name":"Test User","password":"123456"}'
   ```

3. **查看分布式追踪**
   - 访问 Jaeger: http://localhost:16686
   - 选择服务: `user-service`
   - 查看完整的调用链

## 🎯 学习路径

### 初级（当前阶段）
- ✅ 部署所有组件
- ✅ 配置 Grafana 数据源
- ✅ 查看预置 Dashboard
- ✅ 在 Explore 中查询指标

### 中级（下一步）
- 📊 创建自定义 Dashboard
- 📈 配置告警规则
- 🔍 查看分布式追踪
- 📝 查看日志聚合

### 高级（未来）
- 🚀 优化 HPA 配置
- 📊 创建 SLO/SLI Dashboard
- 🔔 配置告警通知
- 📈 性能调优

## 💡 常用 Prometheus 查询

### 微服务指标
```
# HTTP 请求总数
user_service_http_requests_total

# 按状态码分组
sum by (status) (user_service_http_requests_total)

# 请求速率（QPS）
rate(user_service_http_requests_total[5m])

# 错误率
sum(rate(user_service_http_requests_total{status=~"5.."}[5m])) / sum(rate(user_service_http_requests_total[5m]))
```

### Kubernetes 指标
```
# Pod CPU 使用率
container_cpu_usage_seconds_total

# Pod 内存使用
container_memory_usage_bytes

# Pod 重启次数
kube_pod_container_status_restarts_total
```

## 📚 参考文档

- [Grafana 配置指南](GRAFANA_SETUP.md)
- [Grafana 故障排查](GRAFANA_FIX.md)
- [部署指南](DEPLOYMENT.md)
- [学习笔记](LEARNING_NOTES.md)





