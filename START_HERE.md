# 🚀 从这里开始！

欢迎！这是你的**云原生可观测性平台**项目的起点。

## ⚡ 快速开始（5分钟）

### Windows 用户

```powershell
# 1. 确保 Docker Desktop 正在运行
docker ps

# 2. 一键部署（自动完成所有步骤）
.\scripts\setup-and-deploy.ps1

# 3. 验证部署
.\scripts\verify-deployment.ps1
```

### Linux/Mac 用户

```bash
# 1. 确保 Docker 正在运行
docker ps

# 2. 添加执行权限
chmod +x scripts/*.sh

# 3. 一键部署
./scripts/setup-and-deploy.sh

# 4. 验证部署
./scripts/verify-deployment.sh
```

## 📋 部署脚本会做什么？

1. ✅ 创建 Kubernetes 集群（使用 kind）
2. ✅ 构建 Docker 镜像（user-service, product-service, order-service）
3. ✅ 部署基础设施（PostgreSQL, RabbitMQ）
4. ✅ 部署可观测性平台（Prometheus, Loki, Jaeger, Grafana）
5. ✅ 部署微服务
6. ✅ 配置监控和自动扩缩容

## 🎯 部署完成后

### 1. 测试微服务

```bash
# 端口转发（在单独的终端）
kubectl port-forward -n microservices svc/user-service 8001:8001 &
kubectl port-forward -n microservices svc/product-service 8002:8002 &
kubectl port-forward -n microservices svc/order-service 8003:8003 &

# 创建用户
curl -X POST http://localhost:8001/api/users \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "name": "Test User", "password": "123456"}'

# 创建商品
curl -X POST http://localhost:8002/api/products/ \
  -H "Content-Type: application/json" \
  -d '{"name": "MacBook Pro", "description": "Laptop", "price": 12999.0, "stock": 50}'

# 创建订单
curl -X POST http://localhost:8003/api/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "product_id": 1, "quantity": 3}'
```

### 2. 查看分布式追踪

```bash
# 端口转发 Jaeger UI
kubectl port-forward -n observability svc/jaeger-query 16686:16686

# 打开浏览器: http://localhost:16686
# 选择服务 order-service，查看完整的调用链
```

### 3. 查看监控指标

```bash
# 端口转发 Prometheus
kubectl port-forward -n monitoring svc/prometheus-operator-kube-prom-prometheus 9090:9090

# 打开浏览器: http://localhost:9090
# 查询指标: http_requests_total
```

### 4. 查看 Grafana Dashboard

```bash
# 端口转发 Grafana
kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80

# 打开浏览器: http://localhost:3000
# 用户名: admin
# 密码: admin
```

## 📚 文档导航

- **[NEXT_STEPS.md](NEXT_STEPS.md)** - 详细的下一步行动指南 ⭐
- **[QUICKSTART.md](QUICKSTART.md)** - 快速开始指南
- **[BUILD_AND_DEPLOY.md](BUILD_AND_DEPLOY.md)** - 构建和部署详解
- **[LEARNING_NOTES.md](LEARNING_NOTES.md)** - 学习笔记（为什么这么做）
- **[README.md](README.md)** - 项目概述

## ❓ 遇到问题？

1. **查看日志**
   ```bash
   kubectl logs -n microservices <pod-name>
   ```

2. **查看 Pod 状态**
   ```bash
   kubectl get pods -A
   kubectl describe pod -n microservices <pod-name>
   ```

3. **参考故障排查**
   - [QUICKSTART.md](QUICKSTART.md) 中的故障排查部分
   - [NEXT_STEPS.md](NEXT_STEPS.md) 中的问题解决部分

## 🎓 学习路径

1. **第一步**：运行部署脚本，看到所有服务运行 ✅
2. **第二步**：测试微服务功能，理解业务流程 ✅
3. **第三步**：查看分布式追踪，理解服务调用链 ✅
4. **第四步**：查看监控指标，理解可观测性 ✅
5. **第五步**：阅读代码注释，理解设计决策 ✅

## 🎉 完成标志

当你能够：
- ✅ 一键部署整个平台
- ✅ 看到完整的分布式追踪
- ✅ 在 Grafana 中查看监控数据
- ✅ 理解每个组件的作用

**恭喜！你已经掌握了云原生可观测性平台的核心技能！** 🎊

---

**现在就开始吧！运行部署脚本，让我们看看你的平台运行起来！** 🚀












