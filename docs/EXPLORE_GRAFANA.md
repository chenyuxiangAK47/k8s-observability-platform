# Grafana 探索指南

## ✅ Prometheus 数据源已配置成功！

现在你可以开始探索 Grafana 的功能了。

## 🎯 第一步：探索微服务指标（推荐先做）

### 操作步骤

1. **打开 Explore**
   - 点击左侧导航栏的 **Explore**（探索图标）

2. **选择数据源**
   - 在顶部下拉菜单中选择 **Prometheus**

3. **输入查询**
   ```
   user_service_http_requests_total
   ```

4. **运行查询**
   - 点击 **Run query** 按钮
   - 应该能看到数据图表

### 尝试其他查询

```
# 查看所有微服务的请求
user_service_http_requests_total
product_service_http_requests_total
order_service_http_requests_total

# 按状态码分组
sum by (status) (user_service_http_requests_total)

# 请求速率（QPS - 每秒请求数）
rate(user_service_http_requests_total[5m])

# 错误率
sum(rate(user_service_http_requests_total{status=~"5.."}[5m])) / sum(rate(user_service_http_requests_total[5m]))
```

## 📊 第二步：查看预置 Dashboard

### 操作步骤

1. **打开 Dashboards**
   - 点击左侧导航栏的 **Dashboards**

2. **浏览 Dashboard**
   - 查看 Prometheus Operator 自带的 Dashboard
   - 推荐查看：
     - **Kubernetes / Compute Resources / Cluster**
     - **Kubernetes / Compute Resources / Namespace (Pods)**
     - **Kubernetes / Compute Resources / Pod**

3. **查看微服务 Dashboard**
   - 搜索 "microservices" 相关的 Dashboard
   - 或者查看 Pod 级别的 Dashboard

## 🎨 第三步：创建自定义 Dashboard

### 创建新 Dashboard

1. **新建 Dashboard**
   - 点击 **Dashboards > New > New dashboard**

2. **添加 Panel**
   - 点击 **Add visualization**
   - 选择 **Prometheus** 数据源

3. **配置查询**
   - 查询: `user_service_http_requests_total`
   - 可视化类型: **Time series**
   - 设置标题: "User Service HTTP Requests"

4. **添加更多 Panel**
   - CPU 使用率: `container_cpu_usage_seconds_total`
   - 内存使用率: `container_memory_usage_bytes`
   - 请求延迟: `user_service_http_request_duration_seconds`
   - 错误率: `sum(rate(user_service_http_requests_total{status=~"5.."}[5m]))`

5. **保存 Dashboard**
   - 点击右上角 **Save dashboard**
   - 输入名称: "Microservices Overview"

## 🔍 第四步：配置其他数据源（可选）

### Loki（日志聚合）

1. 点击 **Connections > Data sources > Add new connection**
2. 搜索并选择 **Loki**
3. 配置：
   - **Name**: `loki`
   - **URL**: `http://loki-gateway.observability.svc.cluster.local:80`
4. 点击 **Save & test**

### Jaeger（分布式追踪）

1. 点击 **Connections > Data sources > Add new connection**
2. 搜索并选择 **Jaeger**
3. 配置：
   - **Name**: `jaeger`
   - **URL**: `http://observability-platform-jaeger-query.observability.svc.cluster.local:80`
4. 点击 **Save & test**

## 📈 常用 Prometheus 查询

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

# 请求延迟（P95）
histogram_quantile(0.95, rate(user_service_http_request_duration_seconds_bucket[5m]))
```

### Kubernetes 指标

```
# Pod CPU 使用率
container_cpu_usage_seconds_total

# Pod 内存使用
container_memory_usage_bytes

# Pod 重启次数
kube_pod_container_status_restarts_total

# Pod 数量
count(kube_pod_info)
```

## 🎓 学习路径

### 初级（当前阶段）
- ✅ 配置 Prometheus 数据源
- 📊 在 Explore 中查询指标
- 📈 查看预置 Dashboard

### 中级（下一步）
- 🎨 创建自定义 Dashboard
- 📊 配置告警规则
- 🔍 查看分布式追踪
- 📝 查看日志聚合

### 高级（未来）
- 🚀 优化 HPA 配置
- 📊 创建 SLO/SLI Dashboard
- 🔔 配置告警通知
- 📈 性能调优

## 💡 提示

1. **Explore 功能**：最适合快速查询和测试
2. **Dashboard**：适合长期监控和展示
3. **告警**：可以基于指标设置告警规则
4. **变量**：可以在 Dashboard 中使用变量，实现动态查询

## 🔗 相关文档

- [Grafana 配置指南](GRAFANA_SETUP.md)
- [Grafana 故障排查](GRAFANA_FIX.md)
- [下一步操作指南](NEXT_STEPS_GUIDE.md)
















