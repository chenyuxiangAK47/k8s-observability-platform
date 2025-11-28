# Microshop Microservices

一个面向学习/作品集的 Python 微服务示例，展示了“可上线”的工程化实践：独立数据库、服务间 API 调用、RabbitMQ 事件驱动、容错重试、Docker Compose 一键启动。

## 架构速览

| 服务            | 端口 | 负责内容                                   | 数据库          |
|-----------------|------|--------------------------------------------|-----------------|
| user-service    | 8001 | 用户注册、查询、登录                       | `users_db`      |
| product-service | 8002 | 商品 CRUD、监听订单事件扣减库存           | `products_db`   |
| order-service   | 8003 | 下单、调用用户/商品服务校验并发布订单事件 | `orders_db`     |
| PostgreSQL      | 5432 | 通过 `db-init/init-microshop-dbs.sql` 初始化三个库 | - |
| Redis           | 6379 | 预留（后续可做缓存/限流）                  | - |
| RabbitMQ        | 5672/15672 | 订单事件总线（fanout exchange）          | - |

特点：

- **数据自治**：每个业务服务只访问自己的数据库，通过 API/事件交流。
- **容错通信**：订单服务调用下游时使用 httpx + tenacity，带超时、重试、日志。
- **事件驱动库存**：下单后只发布事件，商品服务异步扣库存 → 体现最终一致性。
- **可观测性**：结构化日志记录调用耗时、事件处理成功/失败。
- **Docker Compose**：`docker compose up -d --build` 即可模拟整套微服务。

## 快速开始

```bash
# 1. 启动 Docker Desktop（或任何兼容 Docker 环境）

# 2. 拉起所有服务
docker compose up -d --build

# 3. 验证健康检查
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health
```

### 选装：只重建业务镜像

```bash
docker compose build order-service product-service
docker compose up -d order-service product-service
```

## 手动演练：订单 → 事件 → 扣库存

```bash
# 1. 创建用户
curl -Method POST http://localhost:8001/api/users `
  -ContentType "application/json" `
  -Body '{ "email": "user1@example.com", "name": "User1", "password": "123456" }'

# 2. 创建商品（库存 50 件）
curl -Method POST http://localhost:8002/api/products/ `
  -ContentType "application/json" `
  -Body '{ "name": "MacBook Pro", "description": "demo product", "price": 12999.0, "stock": 50 }'

# 3. 创建订单（quantity=3）
curl -Method POST http://localhost:8003/api/orders `
  -ContentType "application/json" `
  -Body '{ "user_id": 1, "product_id": 1, "quantity": 3 }'

# 4. 查询商品库存 → 47（由商品服务消费 RabbitMQ 事件后扣减）
curl http://localhost:8002/api/products/1
```

## 目录结构

```
.
├─docker-compose.yml           # 一键启动 DB + MQ + 3 个服务
├─db-init/init-microshop-dbs.sql  # 初始化 users_db / products_db / orders_db
├─user-service/                # FastAPI + SQLAlchemy（用户）
├─product-service/             # FastAPI + SQLAlchemy + RabbitMQ 消费者（商品）
├─order-service/               # FastAPI + RabbitMQ 事件发布（订单）
└─.gitignore
```

## TODO / 进阶方向

- Redis 缓存/幂等性：例如订单接口传 `request_id`，用 Redis 保证“不重复扣款”。
- CI/CD：加上 `pytest`、`docker build` 的 GitHub Actions。
- 观测性：接入 OpenTelemetry/Jaeger，实现链路追踪。
- API 网关 / 身份认证：继续拆分出 auth-service，演示统一鉴权。

## License

MIT

