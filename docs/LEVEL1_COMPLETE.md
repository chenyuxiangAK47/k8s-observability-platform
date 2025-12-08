# 🎯 Level 1 完整功能指南

本文档介绍 Level 1 的所有高级功能：高级自动扩缩容 + Service Mesh。

---

## 📋 目录

1. [高级自动扩缩容](#高级自动扩缩容)
2. [Service Mesh (Istio)](#service-mesh-istio)
3. [快速开始](#快速开始)
4. [使用示例](#使用示例)
5. [故障排查](#故障排查)

---

## 🚀 高级自动扩缩容

### 1. 基于 Prometheus 指标的 HPA

**功能：** 使用 Prometheus 指标（QPS、延迟、错误率）进行扩缩容，而不仅仅是 CPU/内存。

**配置：** `k8s/autoscaling/prometheus-metrics-hpa.yaml`

**支持的指标：**
- `http_requests_per_second` - HTTP 请求速率
- `http_request_duration_seconds_0_95` - P95 延迟
- `http_error_rate` - 错误率

**示例：**
```yaml
metrics:
- type: Pods
  pods:
    metric:
      name: http_requests_per_second
    target:
      type: AverageValue
      averageValue: "100"  # 每个 Pod 处理 100 QPS
```

### 2. VPA (Vertical Pod Autoscaler)

**功能：** 自动调整 Pod 的资源请求和限制，优化资源使用。

**配置：** `k8s/autoscaling/vpa.yaml`

**更新模式：**
- `Auto` - 自动更新（会重启 Pod）
- `Off` - 仅推荐，不自动更新
- `Initial` - 仅在创建时应用

**示例：**
```yaml
updatePolicy:
  updateMode: "Auto"
resourcePolicy:
  containerPolicies:
  - containerName: user-service
    minAllowed:
      cpu: 50m
      memory: 128Mi
    maxAllowed:
      cpu: 2
      memory: 2Gi
```

### 3. KEDA (基于外部指标)

**功能：** 基于外部系统（Redis、Kafka、SQS 等）的指标进行扩缩容。

**配置：** `k8s/autoscaling/keda-redis-scaler.yaml`

**支持的触发器：**
- Redis 队列长度
- Kafka 消息积压
- Prometheus 指标
- HTTP 请求
- 等等

**示例：**
```yaml
triggers:
- type: redis
  metadata:
    address: redis.microservices.svc.cluster.local:6379
    listName: order-queue
    listLength: "10"  # 队列长度 > 10 时扩容
```

---

## 🌐 Service Mesh (Istio)

### 1. mTLS (双向 TLS)

**功能：** 强制所有服务间通信使用加密的 mTLS。

**配置：** `k8s/service-mesh/mtls-policy.yaml`

**模式：**
- `STRICT` - 强制 mTLS（生产环境推荐）
- `PERMISSIVE` - 允许明文和 mTLS（迁移阶段）
- `DISABLE` - 禁用 mTLS

**验证：**
```bash
kubectl get peerauthentication -n microservices
```

### 2. 金丝雀发布

**功能：** 逐步将流量从旧版本切换到新版本，降低发布风险。

**配置：** `k8s/service-mesh/virtual-services.yaml`

**使用脚本：**
```bash
# 10% 流量到新版本
./scripts/canary-deployment.sh user-service microservices 90 10

# 50% 流量到新版本
./scripts/canary-deployment.sh user-service microservices 50 50

# 100% 流量到新版本
./scripts/canary-deployment.sh user-service microservices 0 100
```

**手动配置：**
```yaml
http:
- route:
  - destination:
      host: user-service
      subset: v2
    weight: 10  # 10% 流量到新版本
  - destination:
      host: user-service
      subset: v1
    weight: 90  # 90% 流量到旧版本
```

### 3. 流量管理

**功能：** 定义路由规则、负载均衡策略、熔断等。

**配置：**
- `k8s/service-mesh/destination-rules.yaml` - 定义服务版本和策略
- `k8s/service-mesh/virtual-services.yaml` - 定义路由规则
- `k8s/service-mesh/gateway.yaml` - 定义入口流量

**负载均衡策略：**
- `ROUND_ROBIN` - 轮询
- `LEAST_CONN` - 最少连接
- `RANDOM` - 随机

**熔断配置：**
```yaml
outlierDetection:
  consecutiveErrors: 3
  interval: 30s
  baseEjectionTime: 30s
  maxEjectionPercent: 50
```

---

## 🚀 快速开始

### 一键安装

```bash
# Linux/Mac
chmod +x scripts/*.sh
./scripts/install-level1-complete.sh

# Windows
.\scripts\install-level1-complete.ps1
```

### 分步安装

#### 1. 安装高级自动扩缩容

```bash
# Linux/Mac
./scripts/install-advanced-autoscaling.sh

# Windows
.\scripts\install-advanced-autoscaling.ps1
```

#### 2. 安装 Istio

```bash
# Linux/Mac
./scripts/install-istio.sh

# Windows
.\scripts\install-istio.ps1
```

---

## 📝 使用示例

### 示例 1: 基于 QPS 的自动扩缩容

1. **部署服务并启用 Prometheus HPA**
   ```bash
   kubectl apply -f k8s/autoscaling/prometheus-metrics-hpa.yaml
   ```

2. **生成负载**
   ```bash
   # 使用 hey 或 ab 工具生成负载
   hey -n 10000 -c 100 http://user-service.microservices.svc.cluster.local:8001/health
   ```

3. **观察扩缩容**
   ```bash
   watch kubectl get hpa -n microservices
   kubectl get pods -n microservices -w
   ```

### 示例 2: 金丝雀发布

1. **部署新版本（v2）**
   ```bash
   # 更新 Deployment，添加 version: v2 标签
   kubectl set image deployment/user-service user-service=user-service:v2 -n microservices
   kubectl label deployment/user-service version=v2 -n microservices
   ```

2. **逐步切换流量**
   ```bash
   # 10% 流量到新版本
   ./scripts/canary-deployment.sh user-service microservices 90 10
   
   # 等待观察，确认无问题后增加到 50%
   ./scripts/canary-deployment.sh user-service microservices 50 50
   
   # 最后切换到 100%
   ./scripts/canary-deployment.sh user-service microservices 0 100
   ```

3. **验证流量分布**
   ```bash
   kubectl get virtualservice user-service-canary -n microservices -o yaml
   ```

### 示例 3: 验证 mTLS

1. **检查 mTLS 状态**
   ```bash
   kubectl get peerauthentication -n microservices
   ```

2. **查看服务间通信**
   ```bash
   # 进入 Pod
   kubectl exec -it user-service-xxx -n microservices -- sh
   
   # 查看 Istio sidecar 日志
   kubectl logs user-service-xxx -c istio-proxy -n microservices
   ```

---

## 🔧 故障排查

### 问题 1: Prometheus Adapter 无法获取指标

**检查：**
```bash
# 检查 Prometheus Adapter 状态
kubectl get pods -n kube-system | grep prometheus-adapter

# 检查自定义指标 API
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq

# 查看 Prometheus Adapter 日志
kubectl logs -n kube-system -l app=prometheus-adapter
```

**解决方案：**
- 确认 Prometheus 可访问
- 检查 Prometheus Adapter 配置
- 确认指标名称正确

### 问题 2: VPA 不工作

**检查：**
```bash
# 查看 VPA 状态
kubectl get vpa -n microservices
kubectl describe vpa user-service-vpa -n microservices

# 查看 VPA Recommender 日志
kubectl logs -n kube-system -l app=vpa-recommender
```

**解决方案：**
- 确认 VPA 组件已安装
- 检查 VPA 推荐模式（Auto/Off/Initial）
- 等待足够时间收集指标（通常需要几分钟）

### 问题 3: Istio Sidecar 未注入

**检查：**
```bash
# 检查命名空间标签
kubectl get namespace microservices --show-labels

# 检查 Pod 是否有 sidecar
kubectl get pods -n microservices -o jsonpath='{.items[0].spec.containers[*].name}'
```

**解决方案：**
```bash
# 启用自动注入
kubectl label namespace microservices istio-injection=enabled --overwrite

# 重启 Pod 以注入 sidecar
kubectl rollout restart deployment -n microservices
```

### 问题 4: 金丝雀发布流量未分配

**检查：**
```bash
# 查看 VirtualService
kubectl get virtualservice -n microservices -o yaml

# 查看 DestinationRule
kubectl get destinationrule -n microservices -o yaml

# 检查 Pod 标签
kubectl get pods -n microservices --show-labels
```

**解决方案：**
- 确认 Pod 有正确的版本标签（version: v1, version: v2）
- 确认 DestinationRule 定义了对应的 subset
- 确认 VirtualService 路由规则正确

---

## 📊 监控和观察

### 查看 HPA 状态

```bash
kubectl get hpa -n microservices
kubectl describe hpa user-service-prometheus-hpa -n microservices
```

### 查看 VPA 推荐

```bash
kubectl get vpa -n microservices
kubectl describe vpa user-service-vpa -n microservices
```

### 查看 Istio 流量

```bash
# 使用 Istio Dashboard（如果安装了 Grafana）
# 或使用 Kiali（Istio 的可视化工具）

# 查看服务拓扑
istioctl dashboard kiali
```

### 查看 mTLS 状态

```bash
# 使用 Istio 的 authz 检查
istioctl authz check user-service.microservices.svc.cluster.local
```

---

## 🎓 学习要点

### 1. 自动扩缩容策略

- **HPA** - 水平扩缩容（增加/减少 Pod 数量）
- **VPA** - 垂直扩缩容（调整单个 Pod 资源）
- **KEDA** - 基于外部指标的扩缩容

### 2. Service Mesh 核心概念

- **Sidecar** - 每个 Pod 中的代理容器
- **mTLS** - 服务间加密通信
- **VirtualService** - 定义路由规则
- **DestinationRule** - 定义服务版本和策略
- **Gateway** - 定义入口流量

### 3. 金丝雀发布最佳实践

1. **从小流量开始** - 10% → 50% → 100%
2. **监控关键指标** - 错误率、延迟、QPS
3. **快速回滚能力** - 发现问题立即回滚
4. **自动化测试** - 在切换流量前运行测试

---

## 📚 相关资源

- [Kubernetes HPA 文档](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [VPA 文档](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
- [KEDA 文档](https://keda.sh/docs/)
- [Istio 文档](https://istio.io/latest/docs/)
- [Istio 流量管理](https://istio.io/latest/docs/concepts/traffic-management/)

---

## 💡 面试话术

**当被问到"你了解自动扩缩容吗？"时：**

> "我在项目中实现了完整的自动扩缩容方案。包括：
> 1. **HPA**：基于 CPU/内存和 Prometheus 指标（QPS、延迟）进行水平扩缩容
> 2. **VPA**：自动调整 Pod 的资源请求和限制，优化资源使用
> 3. **KEDA**：基于外部系统（Redis 队列）的指标进行扩缩容
> 
> 这样可以确保服务在高负载时自动扩展，低负载时自动收缩，既保证了性能，又优化了成本。"

**当被问到"你了解 Service Mesh 吗？"时：**

> "我在项目中实现了 Istio Service Mesh，包括：
> 1. **mTLS**：强制所有服务间通信使用加密，提高安全性
> 2. **流量管理**：实现金丝雀发布，逐步将流量从旧版本切换到新版本
> 3. **可观测性**：自动生成服务拓扑和分布式追踪
> 4. **熔断和限流**：保护服务不被过载
> 
> Service Mesh 让我实现了零停机部署和更好的服务治理能力。"

---

**最后更新：2025-01-XX**

