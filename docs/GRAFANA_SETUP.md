# Grafana 配置指南

## 配置 Prometheus 数据源

### 问题
默认配置中 Prometheus URL 是 `http://localhost:9090`，这在 Grafana Pod 内部无法访问。

### 解决方案
使用 Kubernetes Service 的内部地址：

**正确的 Prometheus URL:**
```
http://prometheus-operator-kube-prom-prometheus.monitoring.svc.cluster.local:9090
```

### 配置步骤

1. 在 Grafana 中，进入 **Connections > Data sources**
2. 点击 **prometheus-1** 数据源
3. 在 **Connection** 部分，修改 **Prometheus server URL** 为：
   ```
   http://prometheus-operator-kube-prom-prometheus.monitoring.svc.cluster.local:9090
   ```
4. 点击 **Save & test**
5. 应该看到绿色的成功消息

## 配置 Loki 数据源（日志）

### Loki URL
```
http://loki-gateway.observability.svc.cluster.local:80
```

### 配置步骤

1. 在 Grafana 中，进入 **Connections > Data sources**
2. 点击 **Add new connection**
3. 搜索并选择 **Loki**
4. 配置：
   - **Name**: `loki`
   - **URL**: `http://loki-gateway.observability.svc.cluster.local:80`
5. 点击 **Save & test**

## 配置 Jaeger 数据源（追踪）

### Jaeger URL
```
http://observability-platform-jaeger-query.observability.svc.cluster.local:80
```

### 配置步骤

1. 在 Grafana 中，进入 **Connections > Data sources**
2. 点击 **Add new connection**
3. 搜索并选择 **Jaeger**
4. 配置：
   - **Name**: `jaeger`
   - **URL**: `http://observability-platform-jaeger-query.observability.svc.cluster.local:80`
5. 点击 **Save & test**

## 下一步：探索 Grafana

配置完数据源后，你可以：

1. **查看预置 Dashboard**
   - 进入 **Dashboards**
   - 查看 Prometheus Operator 自带的 Dashboard

2. **创建自定义 Dashboard**
   - 点击 **Dashboards > New > New dashboard**
   - 添加 Panel，查询 Prometheus 指标

3. **探索数据**
   - 点击左侧 **Explore**
   - 选择数据源（Prometheus 或 Loki）
   - 输入查询语句

4. **查看微服务指标**
   - 在 Explore 中，查询：`user_service_http_requests_total`
   - 或：`product_service_http_requests_total`
   - 或：`order_service_http_requests_total`

## 常用 Prometheus 查询

### 微服务指标
```
# HTTP 请求总数
user_service_http_requests_total

# 按状态码分组
sum by (status) (user_service_http_requests_total)

# 请求速率（QPS）
rate(user_service_http_requests_total[5m])
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

## 常用 Loki 查询

### 查看微服务日志
```
{namespace="microservices"} |= "error"
```

### 查看特定服务日志
```
{namespace="microservices", app="user-service"}
```





