# 下一步行动指南

## ✅ 当前状态

你已经完成了：
- ✅ 所有微服务代码（包含 OpenTelemetry）
- ✅ Docker 镜像构建脚本
- ✅ Kubernetes 部署配置
- ✅ Helm Charts
- ✅ 完整的文档

## 🎯 立即行动：测试和验证

### 步骤 1: 实际运行部署（最重要！）

#### Windows 用户

```powershell
# 1. 确保 Docker Desktop 正在运行
docker ps

# 2. 运行完整部署脚本（这会自动完成所有步骤）
.\scripts\setup-and-deploy.ps1
```

#### Linux/Mac 用户

```bash
# 1. 确保 Docker 正在运行
docker ps

# 2. 添加执行权限
chmod +x scripts/*.sh

# 3. 运行完整部署脚本
./scripts/setup-and-deploy.sh
```

**预期结果：**
- ✅ 创建 kind 集群
- ✅ 构建 3 个 Docker 镜像
- ✅ 部署所有 Kubernetes 资源
- ✅ 所有 Pod 状态为 Running

### 步骤 2: 验证部署

```bash
# 检查所有 Pod 状态
kubectl get pods -A

# 应该看到：
# - microservices 命名空间：user-service, product-service, order-service, postgresql, rabbitmq
# - observability 命名空间：loki, jaeger, grafana
# - monitoring 命名空间：prometheus-operator 相关 Pod
```

### 步骤 3: 测试微服务功能

```bash
# 1. 端口转发（在单独的终端窗口）
kubectl port-forward -n microservices svc/user-service 8001:8001 &
kubectl port-forward -n microservices svc/product-service 8002:8002 &
kubectl port-forward -n microservices svc/order-service 8003:8003 &

# 2. 创建用户
curl -X POST http://localhost:8001/api/users \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "name": "Test User", "password": "123456"}'

# 3. 创建商品
curl -X POST http://localhost:8002/api/products/ \
  -H "Content-Type: application/json" \
  -d '{"name": "MacBook Pro", "description": "Laptop", "price": 12999.0, "stock": 50}'

# 4. 创建订单（这会触发完整流程）
curl -X POST http://localhost:8003/api/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "product_id": 1, "quantity": 3}'

# 5. 验证库存已扣减
curl http://localhost:8002/api/products/1
# 应该显示 stock: 47（50 - 3）
```

### 步骤 4: 验证 OpenTelemetry 追踪

```bash
# 1. 端口转发 Jaeger UI
kubectl port-forward -n observability svc/jaeger-query 16686:16686

# 2. 打开浏览器访问: http://localhost:16686

# 3. 在 Jaeger UI 中：
#    - 选择服务：order-service
#    - 点击 "Find Traces"
#    - 你应该能看到完整的调用链：
#      * order-service → user-service (HTTP 调用)
#      * order-service → product-service (HTTP 调用)
#      * order-service → RabbitMQ (事件发布)
#      * product-service (RabbitMQ 消费者)
```

### 步骤 5: 验证 Prometheus 指标

```bash
# 1. 端口转发 Prometheus
kubectl port-forward -n monitoring svc/prometheus-operator-kube-prom-prometheus 9090:9090

# 2. 打开浏览器访问: http://localhost:9090

# 3. 在 Prometheus 中查询：
#    - http_requests_total
#    - http_request_duration_seconds
#    - service_calls_total
#    - rabbitmq_messages_published_total
```

### 步骤 6: 验证 Grafana Dashboard

```bash
# 1. 端口转发 Grafana
kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80

# 2. 打开浏览器访问: http://localhost:3000
#    用户名: admin
#    密码: admin

# 3. 配置数据源（如果还没有）：
#    - Prometheus: http://prometheus-operator-kube-prom-prometheus.monitoring.svc.cluster.local:9090
#    - Loki: http://loki-gateway.observability.svc.cluster.local:80
#    - Jaeger: http://jaeger-query.observability.svc.cluster.local:16686
```

## 🔧 如果遇到问题

### 问题 1: Pod 无法启动

```bash
# 查看 Pod 日志
kubectl logs -n microservices <pod-name>

# 查看 Pod 描述
kubectl describe pod -n microservices <pod-name>

# 常见问题：
# - 镜像拉取失败：检查镜像是否已构建
# - 数据库连接失败：检查数据库是否就绪
# - 环境变量缺失：检查 Secret 是否创建
```

### 问题 2: 服务无法连接

```bash
# 检查 Service
kubectl get svc -n microservices

# 检查 Endpoints（确保有 Pod 在运行）
kubectl get endpoints -n microservices

# 测试服务间连接
kubectl exec -n microservices <order-service-pod> -- \
  curl http://user-service.microservices.svc.cluster.local:8001/health
```

### 问题 3: 追踪数据缺失

```bash
# 检查 OpenTelemetry 环境变量
kubectl exec -n microservices <pod-name> -- env | grep OTEL

# 检查 Jaeger Collector 是否运行
kubectl get pods -n observability | grep jaeger

# 检查网络连接
kubectl exec -n microservices <pod-name> -- \
  curl -v http://jaeger-collector.observability.svc.cluster.local:4317
```

## 📊 验证清单

完成以下检查，确保一切正常：

- [ ] 所有 Pod 状态为 Running
- [ ] 可以创建用户、商品、订单
- [ ] 订单创建后库存正确扣减
- [ ] Jaeger 中能看到完整的调用链
- [ ] Prometheus 中能看到指标数据
- [ ] Grafana 可以查询数据
- [ ] HPA 配置已应用（`kubectl get hpa -n microservices`）

## 🚀 进阶任务

### 任务 1: 添加 Grafana Dashboard

创建自定义 Dashboard 展示：
- 服务 QPS（每秒请求数）
- 服务延迟（P50/P95/P99）
- 错误率
- 服务间调用关系

### 任务 2: 测试 HPA 自动扩缩容

```bash
# 1. 安装压力测试工具
# Windows: choco install apache-bench
# Mac: brew install apache-bench

# 2. 对服务进行压力测试
ab -n 10000 -c 100 http://localhost:8001/health

# 3. 观察 Pod 数量变化
watch kubectl get pods -n microservices

# 4. 查看 HPA 状态
kubectl get hpa -n microservices
kubectl describe hpa user-service-hpa -n microservices
```

### 任务 3: 测试故障恢复

```bash
# 1. 删除一个 Pod
kubectl delete pod -n microservices <pod-name>

# 2. 观察 Kubernetes 自动创建新 Pod
kubectl get pods -n microservices -w

# 3. 验证服务仍然可用
curl http://localhost:8001/health
```

### 任务 4: 查看日志聚合

```bash
# 1. 在 Grafana 中配置 Loki 数据源

# 2. 使用 LogQL 查询日志
# 例如：{service="user-service"} |= "error"

# 3. 通过 TraceID 关联日志和追踪
# 在 Jaeger 中找到 TraceID，然后在 Loki 中搜索
```

## 📚 学习资源

完成验证后，深入学习：

1. **Kubernetes 进阶**
   - [Kubernetes 官方文档](https://kubernetes.io/docs/)
   - [Kubernetes 最佳实践](https://kubernetes.io/docs/concepts/configuration/overview/)

2. **OpenTelemetry 深入**
   - [OpenTelemetry Python](https://opentelemetry-python.readthedocs.io/)
   - [分布式追踪最佳实践](https://opentelemetry.io/docs/specs/otel/)

3. **Prometheus 和 Grafana**
   - [Prometheus 查询语言 PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/)
   - [Grafana Dashboard 设计](https://grafana.com/docs/grafana/latest/dashboards/)

## 🎯 下一步计划

### 短期（本周）

1. ✅ **实际运行部署脚本** - 验证一切正常工作
2. ✅ **测试完整流程** - 创建订单，验证追踪
3. ✅ **查看监控数据** - 在 Grafana 中查看指标

### 中期（下周）

1. 🔄 **添加 CI/CD** - GitHub Actions 自动化构建和部署
2. 🔄 **完善 Dashboard** - 创建更丰富的 Grafana Dashboard
3. 🔄 **性能测试** - 压力测试和性能分析

### 长期（本月）

1. 📋 **Service Mesh** - 集成 Istio 或 Linkerd
2. 📋 **多环境支持** - Dev/Staging/Prod 环境
3. 📋 **安全加固** - 添加认证、授权、网络策略

## 💡 提示

1. **遇到问题不要慌**：查看日志，使用 `kubectl describe` 和 `kubectl logs`
2. **逐步验证**：先确保基础服务运行，再测试高级功能
3. **记录问题**：遇到问题时记录下来，这是学习的过程
4. **参考文档**：项目中的文档都有详细说明

## 🎉 完成标志

当你能够：
- ✅ 一键部署整个平台
- ✅ 看到完整的分布式追踪
- ✅ 在 Grafana 中查看监控数据
- ✅ 理解每个组件的作用

**恭喜！你已经掌握了云原生可观测性平台的核心技能！** 🎊




