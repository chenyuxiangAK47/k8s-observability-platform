# Access Guide - 访问指南

## 🚀 微服务访问

### User Service
```powershell
kubectl port-forward -n microservices svc/user-service 8001:8001
```
访问: http://localhost:8001/docs (Swagger UI)

### Product Service
```powershell
kubectl port-forward -n microservices svc/product-service 8002:8002
```
访问: http://localhost:8002/docs

### Order Service
```powershell
kubectl port-forward -n microservices svc/order-service 8003:8003
```
访问: http://localhost:8003/docs

---

## 📊 可观测性平台访问

### 1. Grafana (推荐从这里开始)
```powershell
kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80
```
- 访问: http://localhost:3000
- 用户名: `admin`
- 密码: `admin`

### 2. Prometheus
```powershell
kubectl port-forward -n monitoring svc/prometheus-operator-kube-p-prometheus 9090:9090
```
- 访问: http://localhost:9090
- ⚠️ 注意: 服务名称是 `prometheus-operator-kube-p-prometheus` (不是 `prometheus-operator-kube-prom-prometheus`)

### 3. Jaeger (分布式追踪)

**方法 1: 通过 Service (推荐)**
```powershell
kubectl port-forward -n observability svc/observability-platform-jaeger-query 16686:80
```
- 访问: http://localhost:16686

**方法 2: 直接转发到 Pod (如果方法1不工作)**
```powershell
# 获取 Pod 名称
$pod = kubectl get pod -n observability -l app.kubernetes.io/name=jaeger,app.kubernetes.io/component=query -o jsonpath='{.items[0].metadata.name}'

# 转发到 Pod
kubectl port-forward -n observability $pod 16686:16686
```
- 访问: http://localhost:16686

---

## 💡 使用提示

1. **每个服务需要在单独的终端窗口运行**
2. **按 Ctrl+C 停止端口转发**
3. **建议先访问 Grafana**，它集成了 Prometheus 和 Loki 的数据
4. **Swagger UI** 用于测试 API 接口
5. **Observability Platform** 用于查看系统运行状态

---

## 🔍 快速检查脚本

运行以下脚本查看所有服务状态：
```powershell
.\scripts\test-services.ps1
```

查看完整的访问指南：
```powershell
.\scripts\access-observability-fixed.ps1
```

---

## ✅ 验证部署

检查所有 Pod 状态：
```powershell
kubectl get pods -A
```

检查微服务状态：
```powershell
kubectl get pods -n microservices
```

检查可观测性组件：
```powershell
kubectl get pods -n monitoring
kubectl get pods -n observability
```


