"""
订单服务 - 示例微服务
集成 OpenTelemetry 可观测性
"""
import os
import time
import random
import asyncio
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import httpx
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode
from prometheus_client import Counter, Histogram

from common.otel_setup import setup_otel, instrument_fastapi
from common.logger import setup_logger

# 初始化 OpenTelemetry
tracer = setup_otel("order-service", "1.0.0")
logger = setup_logger("order-service")

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
app = FastAPI(title="Order Service", version="1.0.0")
instrument_fastapi(app, "order-service")

# 服务配置
USER_SERVICE_URL = os.getenv("USER_SERVICE_URL", "http://localhost:8002")
PRODUCT_SERVICE_URL = os.getenv("PRODUCT_SERVICE_URL", "http://localhost:8001")


@app.get("/health")
async def health_check():
    """健康检查端点"""
    return {"status": "healthy", "service": "order-service"}


@app.get("/orders/{order_id}")
async def get_order(order_id: int):
    """
    获取订单信息
    演示跨服务调用和追踪
    """
    start_time = time.time()
    
    with tracer.start_as_current_span("get_order") as span:
        span.set_attribute("order.id", order_id)
        
        try:
            logger.info(f"Fetching order {order_id}", extra_fields={"order_id": order_id})
            
            # 模拟数据库查询延迟
            await asyncio.sleep(random.uniform(0.05, 0.15))
            
            # 调用用户服务验证用户
            async with httpx.AsyncClient() as client:
                try:
                    user_response = await client.get(
                        f"{USER_SERVICE_URL}/users/{order_id % 100}",
                        timeout=2.0
                    )
                    user_response.raise_for_status()
                    span.set_attribute("user.verified", True)
                except Exception as e:
                    logger.warning(f"User service call failed: {e}")
                    span.set_attribute("user.verified", False)
                    span.record_exception(e)
            
            # 模拟偶尔的错误
            if random.random() < 0.05:  # 5% 错误率
                error_counter.labels(status="500", endpoint="/orders").inc()
                span.set_status(Status(StatusCode.ERROR, "Simulated error"))
                raise HTTPException(status_code=500, detail="Simulated internal error")
            
            order_data = {
                "order_id": order_id,
                "user_id": order_id % 100,
                "product_id": random.randint(1, 50),
                "amount": round(random.uniform(10.0, 1000.0), 2),
                "status": "completed"
            }
            
            duration = time.time() - start_time
            request_duration.labels(method="GET", endpoint="/orders").observe(duration)
            request_counter.labels(method="GET", status="200", endpoint="/orders").inc()
            
            span.set_attribute("order.amount", order_data["amount"])
            span.set_status(Status(StatusCode.OK))
            
            logger.info(f"Order {order_id} retrieved successfully", extra_fields={"order_id": order_id})
            
            return order_data
            
        except HTTPException:
            raise
        except Exception as e:
            error_counter.labels(status="500", endpoint="/orders").inc()
            span.set_status(Status(StatusCode.ERROR, str(e)))
            span.record_exception(e)
            logger.error(f"Error fetching order {order_id}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))


@app.post("/orders")
async def create_order(order_data: dict):
    """
    创建订单
    演示跨服务调用链
    """
    start_time = time.time()
    
    with tracer.start_as_current_span("create_order") as span:
        user_id = order_data.get("user_id")
        product_id = order_data.get("product_id")
        
        span.set_attribute("order.user_id", user_id)
        span.set_attribute("order.product_id", product_id)
        
        try:
            logger.info("Creating order", extra_fields=order_data)
            
            # 验证用户
            async with httpx.AsyncClient() as client:
                user_span = tracer.start_span("validate_user")
                try:
                    user_response = await client.get(
                        f"{USER_SERVICE_URL}/users/{user_id}",
                        timeout=2.0
                    )
                    user_response.raise_for_status()
                    user_span.set_attribute("user.valid", True)
                except Exception as e:
                    user_span.set_attribute("user.valid", False)
                    user_span.record_exception(e)
                    raise HTTPException(status_code=400, detail=f"Invalid user: {e}")
                finally:
                    user_span.end()
            
            # 验证商品
            async with httpx.AsyncClient() as client:
                product_span = tracer.start_span("validate_product")
                try:
                    product_response = await client.get(
                        f"{PRODUCT_SERVICE_URL}/products/{product_id}",
                        timeout=2.0
                    )
                    product_response.raise_for_status()
                    product_span.set_attribute("product.valid", True)
                except Exception as e:
                    product_span.set_attribute("product.valid", False)
                    product_span.record_exception(e)
                    raise HTTPException(status_code=400, detail=f"Invalid product: {e}")
                finally:
                    product_span.end()
            
            # 创建订单
            order_id = random.randint(1000, 9999)
            new_order = {
                "order_id": order_id,
                **order_data,
                "status": "created"
            }
            
            duration = time.time() - start_time
            request_duration.labels(method="POST", endpoint="/orders").observe(duration)
            request_counter.labels(method="POST", status="201", endpoint="/orders").inc()
            
            span.set_attribute("order.id", order_id)
            span.set_status(Status(StatusCode.OK))
            
            logger.info(f"Order {order_id} created successfully", extra_fields={"order_id": order_id})
            
            return JSONResponse(status_code=201, content=new_order)
            
        except HTTPException:
            raise
        except Exception as e:
            error_counter.labels(status="500", endpoint="/orders").inc()
            span.set_status(Status(StatusCode.ERROR, str(e)))
            span.record_exception(e)
            logger.error("Error creating order", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    
    # 确保日志目录存在
    os.makedirs("logs", exist_ok=True)
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_config=None  # 使用我们的自定义日志
    )

