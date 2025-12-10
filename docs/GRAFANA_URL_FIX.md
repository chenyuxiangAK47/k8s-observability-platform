# Grafana Prometheus 数据源 URL 配置

## ❌ 常见错误

### 错误 1: Service 名称拼写错误

**错误的 URL:**
```
http://prometheus-operator-kube-prom-prometheus.monitoring.svc.cluster.local:9090
```

**正确的 URL:**
```
http://prometheus-operator-kube-p-prometheus.monitoring.svc.cluster.local:9090
```

**关键区别:**
- ❌ 错误: `kube-prom-prometheus` (prom 后面还有 rom)
- ✅ 正确: `kube-p-prometheus` (p 后面直接是 prometheus)

## ✅ 正确的配置步骤

### 步骤 1: 复制正确的 URL

在 Grafana 的 Prometheus 数据源配置页面：

1. 找到 **Prometheus server URL** 输入框
2. **删除**旧的 URL（全部删除）
3. **输入**正确的 URL：
   ```
   http://prometheus-operator-kube-p-prometheus.monitoring.svc.cluster.local:9090
   ```

### 步骤 2: 检查拼写

确保是：
- ✅ `kube-p-prometheus`（正确）
- ❌ 不是 `kube-prom-prometheus`（错误）

**记忆技巧:**
- `kube-p-prometheus` = kube + p + prometheus
- 只有一个 `p`，没有 `prom`

### 步骤 3: 保存并测试

1. 点击 **Save & test** 按钮
2. 应该看到绿色的成功消息："Data source is working"

## 🔍 如何验证 Service 名称

如果不确定，可以运行：

```powershell
kubectl get svc -n monitoring | Select-String "prometheus"
```

应该看到：
```
prometheus-operator-kube-p-prometheus   ClusterIP   10.96.138.150   <none>   9090/TCP
```

注意名称是 `kube-p-prometheus`，不是 `kube-prom-prometheus`。

## 💡 其他数据源 URL

### Loki（日志）
```
http://loki-gateway.observability.svc.cluster.local:80
```

### Jaeger（追踪）
```
http://observability-platform-jaeger-query.observability.svc.cluster.local:80
```
















