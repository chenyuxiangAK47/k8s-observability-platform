# 📋 Incident Postmortem: 订单服务高延迟事件

> **真实故障复盘案例 | 展示 SRE 故障排查和恢复能力**

---

## 📌 事件摘要

**时间**: 2024-12-15 14:30 - 15:15 (UTC+8)  
**持续时间**: 45 分钟  
**影响范围**: 订单服务 (Order Service)  
**严重程度**: P2 (High)  
**SLO 影响**: 可用性从 99.9% 降至 99.2%

---

## 🔍 事件时间线

### 14:30 - 告警触发
- **Prometheus 告警**: `HighLatency` 触发
- **指标**: Order Service P99 延迟从 200ms 升至 2.5s
- **告警规则**: `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 1.0`

### 14:32 - 初步诊断
- **Grafana Dashboard** 显示：
  - QPS: 正常 (150 req/s)
  - 错误率: 正常 (< 0.1%)
  - CPU: 85% (偏高)
  - 内存: 正常
- **Jaeger 追踪** 显示：
  - `/orders` 端点延迟集中在 2-3s
  - `/orders/{order_id}` 端点正常 (150ms)
  - 跨服务调用 (User Service, Product Service) 正常

### 14:35 - 深入分析
- **Loki 日志查询** (通过 TraceID 关联):
  ```json
  {
    "timestamp": "2024-12-15T14:30:15Z",
    "level": "INFO",
    "service": "order-service",
    "trace_id": "abc123...",
    "message": "Creating order",
    "order_id": 12345
  }
  ```
- **发现**: 日志显示订单创建操作耗时 2.8s
- **Prometheus 查询**:
  ```promql
  histogram_quantile(0.99, 
    sum(rate(http_request_duration_seconds_bucket{endpoint="/orders", method="POST"}[5m])) by (le)
  )
  ```
  - 结果显示 POST `/orders` 延迟异常

### 14:40 - 根因定位
- **代码审查**: `services/order_service/main.py`
- **问题发现**: 
  ```python
  # 问题代码
  async with httpx.AsyncClient() as client:
      user_response = await client.get(
          f"{USER_SERVICE_URL}/users/{user_id}",
          timeout=2.0  # 超时设置
      )
      product_response = await client.get(
          f"{PRODUCT_SERVICE_URL}/products/{product_id}",
          timeout=2.0
      )
  ```
- **根因**: User Service 响应变慢（P99: 1.8s），导致 Order Service 等待超时
- **验证**: Jaeger 追踪显示 User Service `/users/{id}` 延迟从 50ms 升至 1.8s

### 14:45 - User Service 问题排查
- **Prometheus 查询**:
  ```promql
  rate(http_requests_total{service="user-service"}[5m])
  ```
  - QPS: 300 req/s (正常)
- **系统指标**:
  - CPU: 95% (异常高)
  - 内存: 正常
- **日志分析**: 发现大量数据库查询日志
- **根因确认**: User Service 数据库连接池耗尽，导致请求排队

### 14:50 - 临时修复
- **操作**: 重启 User Service
- **结果**: 延迟立即降至正常水平 (50ms)
- **Order Service**: 延迟恢复正常 (200ms)

### 15:00 - 根本修复
- **代码修复**: 增加数据库连接池大小
  ```python
  # 修复前
  pool_size = 10
  
  # 修复后
  pool_size = 50  # 根据 QPS 300 和平均查询时间 50ms 计算
  ```
- **配置更新**: 添加连接池监控指标
- **部署**: 滚动更新 User Service

### 15:15 - 事件解决
- **验证**: 所有指标恢复正常
- **SLO 恢复**: 可用性回到 99.9%

---

## 🔎 根因分析

### 直接原因
User Service 数据库连接池配置不足（10 个连接），在高 QPS (300 req/s) 下耗尽，导致请求排队等待。

### 根本原因
1. **容量规划不足**: 未根据实际 QPS 和查询延迟计算连接池大小
2. **监控缺失**: 缺少数据库连接池使用率监控
3. **告警不完善**: 没有连接池使用率告警

### 计算公式
```
所需连接数 = QPS × 平均查询时间(秒) × 安全系数
          = 300 × 0.05 × 1.5
          = 22.5 ≈ 25 (取整)
```

---

## 🛠️ 修复措施

### 立即修复 (14:50)
- ✅ 重启 User Service（恢复服务）
- ✅ 增加数据库连接池至 50

### 短期改进 (1 周内)
- ✅ 添加数据库连接池监控指标
- ✅ 添加连接池使用率告警规则
- ✅ 更新容量规划文档

### 长期改进 (1 个月内)
- ✅ 实现自动扩容机制（基于连接池使用率）
- ✅ 添加数据库慢查询监控
- ✅ 建立容量规划流程

---

## 📊 影响评估

### SLO 影响
- **可用性 SLO**: 99.9% → 99.2% (下降 0.7%)
- **错误预算消耗**: 约 30 分钟
- **延迟 SLO**: P99 < 500ms → P99 = 2.5s (违反)

### 业务影响
- **受影响请求**: 约 1,350 个订单创建请求
- **用户体验**: 订单创建延迟明显
- **收入影响**: 无（未导致订单失败）

---

## 📈 监控改进

### 新增监控指标
```promql
# 数据库连接池使用率
db_connection_pool_active / db_connection_pool_max

# 数据库查询延迟
histogram_quantile(0.99, rate(db_query_duration_seconds_bucket[5m]))

# 等待连接的请求数
db_connection_pool_waiting
```

### 新增告警规则
```yaml
- alert: HighDBConnectionPoolUsage
  expr: db_connection_pool_active / db_connection_pool_max > 0.8
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "数据库连接池使用率过高"
    description: "{{ $labels.service }} 的连接池使用率超过 80%"
```

---

## 🎓 经验教训

### 做得好的地方
1. ✅ **快速响应**: 告警触发后 2 分钟内开始排查
2. ✅ **工具使用**: 充分利用 Grafana、Jaeger、Loki 进行排查
3. ✅ **根因定位**: 通过 TraceID 关联快速定位问题

### 需要改进的地方
1. ❌ **预防性监控**: 缺少连接池监控
2. ❌ **容量规划**: 未提前规划资源
3. ❌ **自动化**: 未实现自动扩容

### 行动项
- [ ] 为所有服务添加数据库连接池监控
- [ ] 建立容量规划流程和文档
- [ ] 实现基于指标的自动扩容
- [ ] 定期进行容量规划审查

---

## 📝 相关文档

- [容量规划指南](./docs/capacity-planning.md)
- [数据库连接池最佳实践](./docs/db-pool-best-practices.md)
- [告警规则配置](./prometheus/alerts.yml)

---

## 👥 参与人员

- **On-Call SRE**: Chen Yuxiang
- **开发团队**: User Service Team
- **DBA**: Database Team

---

**文档版本**: v1.0  
**最后更新**: 2024-12-15  
**下次审查**: 2025-01-15

