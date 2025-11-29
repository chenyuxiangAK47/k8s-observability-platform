# 微服务说明

## 服务列表

### Order Service (订单服务)
- **端口**: 8000
- **功能**: 订单创建、查询
- **依赖**: User Service, Product Service
- **健康检查**: http://localhost:8000/health

### Product Service (商品服务)
- **端口**: 8001
- **功能**: 商品查询、列表
- **健康检查**: http://localhost:8001/health

### User Service (用户服务)
- **端口**: 8002
- **功能**: 用户查询、列表
- **健康检查**: http://localhost:8002/health

## 启动顺序

1. 先启动基础设施（Prometheus、Grafana 等）
2. 启动 User Service 和 Product Service
3. 最后启动 Order Service（因为它依赖前两个服务）

## 环境变量

可以通过环境变量配置：

```bash
# Order Service
export USER_SERVICE_URL=http://localhost:8002
export PRODUCT_SERVICE_URL=http://localhost:8001

# OpenTelemetry
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
export OTEL_SERVICE_NAME=order-service
```

## 日志位置

所有服务的日志会输出到：
- 控制台（JSON 格式）
- `services/logs/{service_name}.log`（文件）

## 指标端点

每个服务都会暴露 Prometheus 指标端点：
- Order Service: http://localhost:8000/metrics
- Product Service: http://localhost:8001/metrics
- User Service: http://localhost:8002/metrics



