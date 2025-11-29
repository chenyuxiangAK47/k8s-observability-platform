"""
用户服务 - 示例微服务
集成 OpenTelemetry 可观测性
"""
import os
import time
import random
import asyncio
from fastapi import FastAPI, HTTPException
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode
from prometheus_client import Counter, Histogram

from common.otel_setup import setup_otel, instrument_fastapi
from common.logger import setup_logger

# 初始化 OpenTelemetry
tracer = setup_otel("user-service", "1.0.0")
logger = setup_logger("user-service")

# 初始化 Prometheus Metrics
request_counter = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "status", "endpoint"]
)
request_duration = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration",
    ["method", "endpoint"],
    buckets=[0.1, 0.5, 1.0, 2.0, 5.0]
)
error_counter = Counter(
    "http_errors_total",
    "Total HTTP errors",
    ["status", "endpoint"]
)

# 创建 FastAPI 应用
app = FastAPI(title="User Service", version="1.0.0")
instrument_fastapi(app, "user-service")

# 模拟用户数据
USERS = {
    i: {
        "user_id": i,
        "name": f"User {i}",
        "email": f"user{i}@example.com",
        "active": random.choice([True, False])
    }
    for i in range(1, 101)
}


@app.get("/health")
async def health_check():
    """健康检查端点"""
    return {"status": "healthy", "service": "user-service"}


@app.get("/users/{user_id}")
async def get_user(user_id: int):
    """获取用户信息"""
    start_time = time.time()
    
    with tracer.start_as_current_span("get_user") as span:
        span.set_attribute("user.id", user_id)
        
        try:
            logger.info(f"Fetching user {user_id}", extra_fields={"user_id": user_id})
            
            # 模拟数据库查询延迟
            await asyncio.sleep(random.uniform(0.02, 0.08))
            
            # 模拟偶尔的错误
            if random.random() < 0.04:  # 4% 错误率
                error_counter.labels(status="500", endpoint="/users").inc()
                span.set_status(Status(StatusCode.ERROR, "Simulated error"))
                raise HTTPException(status_code=500, detail="Simulated internal error")
            
            if user_id not in USERS:
                error_counter.labels(status="404", endpoint="/users").inc()
                span.set_status(Status(StatusCode.ERROR, "User not found"))
                raise HTTPException(status_code=404, detail="User not found")
            
            user = USERS[user_id]
            
            duration = time.time() - start_time
            request_duration.labels(method="GET", endpoint="/users").observe(duration)
            request_counter.labels(method="GET", status="200", endpoint="/users").inc()
            
            span.set_attribute("user.active", user["active"])
            span.set_status(Status(StatusCode.OK))
            
            logger.info(f"User {user_id} retrieved successfully", extra_fields={"user_id": user_id})
            
            return user
            
        except HTTPException:
            raise
        except Exception as e:
            error_counter.labels(status="500", endpoint="/users").inc()
            span.set_status(Status(StatusCode.ERROR, str(e)))
            span.record_exception(e)
            logger.error(f"Error fetching user {user_id}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))


@app.get("/users")
async def list_users(limit: int = 10, offset: int = 0):
    """列出用户"""
    start_time = time.time()
    
    with tracer.start_as_current_span("list_users") as span:
        span.set_attribute("users.limit", limit)
        span.set_attribute("users.offset", offset)
        
        try:
            users_list = list(USERS.values())[offset:offset+limit]
            
            duration = time.time() - start_time
            request_duration.labels(method="GET", endpoint="/users").observe(duration)
            request_counter.labels(method="GET", status="200", endpoint="/users").inc()
            
            span.set_attribute("users.count", len(users_list))
            span.set_status(Status(StatusCode.OK))
            
            return {"users": users_list, "total": len(USERS)}
            
        except Exception as e:
            error_counter.labels(status="500", endpoint="/users").inc()
            span.set_status(Status(StatusCode.ERROR, str(e)))
            span.record_exception(e)
            logger.error("Error listing users", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    
    # 确保日志目录存在
    os.makedirs("logs", exist_ok=True)
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8002,
        log_config=None
    )

