# Grafana Prometheus 数据源配置修复

## 常见错误

### 错误 1: DNS 解析失败

**错误信息:**
```
dial tcp: lookup prometheus-operator-kube-prom-prometheus.monitoring.svc.cluster.local on 10.96.0.10:53: no such host
```

**原因:** Service 名称拼写错误

**错误的 URL:**
```
http://prometheus-operator-kube-prom-prometheus.monitoring.svc.cluster.local:9090
```

**正确的 URL:**
```
http://prometheus-operator-kube-p-prometheus.monitoring.svc.cluster.local:9090
```

**注意:** 是 `kube-p-prometheus` 不是 `kube-prom-prometheus`

### 错误 2: 连接超时

**错误信息:**
```
context deadline exceeded
```

**解决方案:**
1. 检查 Prometheus Pod 是否运行：
   ```bash
   kubectl get pods -n monitoring | grep prometheus
   ```

2. 检查 Service 是否存在：
   ```bash
   kubectl get svc -n monitoring prometheus-operator-kube-p-prometheus
   ```

3. 从 Grafana Pod 内部测试连接：
   ```bash
   kubectl exec -n monitoring deployment/prometheus-operator-grafana -- curl http://prometheus-operator-kube-p-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up
   ```

## 正确的配置步骤

### 1. 确认 Service 名称

```bash
kubectl get svc -n monitoring | grep prometheus
```

应该看到：
```
prometheus-operator-kube-p-prometheus   ClusterIP   10.96.138.150   <none>   9090/TCP
```

### 2. 在 Grafana 中配置

1. 进入 **Connections > Data sources > prometheus-1**
2. 在 **Connection** 部分，设置 **Prometheus server URL** 为：
   ```
   http://prometheus-operator-kube-p-prometheus.monitoring.svc.cluster.local:9090
   ```
3. 点击 **Save & test**
4. 应该看到绿色的成功消息

### 3. 验证配置

在 Grafana 的 **Explore** 页面：
1. 选择 **Prometheus** 数据源
2. 输入查询：`up`
3. 点击 **Run query**
4. 应该能看到数据

## 其他数据源配置

### Loki（日志）

**URL:**
```
http://loki-gateway.observability.svc.cluster.local:80
```

### Jaeger（追踪）

**URL:**
```
http://observability-platform-jaeger-query.observability.svc.cluster.local:80
```

## 故障排查命令

```bash
# 检查 Service
kubectl get svc -n monitoring

# 检查 DNS 解析（从 Grafana Pod）
kubectl exec -n monitoring deployment/prometheus-operator-grafana -- nslookup prometheus-operator-kube-p-prometheus.monitoring.svc.cluster.local

# 测试连接（从 Grafana Pod）
kubectl exec -n monitoring deployment/prometheus-operator-grafana -- curl http://prometheus-operator-kube-p-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up

# 检查 Prometheus Pod
kubectl get pods -n monitoring | grep prometheus
```









