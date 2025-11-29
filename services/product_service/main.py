"""
商品服务 - 示例微服务
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
tracer = setup_otel("product-service", "1.0.0")
logger = setup_logger("product-service")

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
app = FastAPI(title="Product Service", version="1.0.0")
instrument_fastapi(app, "product-service")

# 模拟商品数据
PRODUCTS = {
    i: {
        "product_id": i,
        "name": f"Product {i}",
        "price": round(random.uniform(10.0, 500.0), 2),
        "stock": random.randint(0, 100)
    }
    for i in range(1, 101)
}


@app.get("/health")
async def health_check():
    """健康检查端点"""
    return {"status": "healthy", "service": "product-service"}


@app.get("/products/{product_id}")
async def get_product(product_id: int):
    """获取商品信息"""
    start_time = time.time()
    
    with tracer.start_as_current_span("get_product") as span:
        span.set_attribute("product.id", product_id)
        
        try:
            logger.info(f"Fetching product {product_id}", extra_fields={"product_id": product_id})
            
            # 模拟数据库查询延迟
            await asyncio.sleep(random.uniform(0.03, 0.10))
            
            # 模拟偶尔的错误
            if random.random() < 0.03:  # 3% 错误率
                error_counter.labels(status="500", endpoint="/products").inc()
                span.set_status(Status(StatusCode.ERROR, "Simulated error"))
                raise HTTPException(status_code=500, detail="Simulated internal error")
            
            if product_id not in PRODUCTS:
                error_counter.labels(status="404", endpoint="/products").inc()
                span.set_status(Status(StatusCode.ERROR, "Product not found"))
                raise HTTPException(status_code=404, detail="Product not found")
            
            product = PRODUCTS[product_id]
            
            duration = time.time() - start_time
            request_duration.labels(method="GET", endpoint="/products").observe(duration)
            request_counter.labels(method="GET", status="200", endpoint="/products").inc()
            
            span.set_attribute("product.price", product["price"])
            span.set_attribute("product.stock", product["stock"])
            span.set_status(Status(StatusCode.OK))
            
            logger.info(f"Product {product_id} retrieved successfully", extra_fields={"product_id": product_id})
            
            return product
            
        except HTTPException:
            raise
        except Exception as e:
            error_counter.labels(status="500", endpoint="/products").inc()
            span.set_status(Status(StatusCode.ERROR, str(e)))
            span.record_exception(e)
            logger.error(f"Error fetching product {product_id}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))


@app.get("/products")
async def list_products(limit: int = 10, offset: int = 0):
    """列出商品"""
    start_time = time.time()
    
    with tracer.start_as_current_span("list_products") as span:
        span.set_attribute("products.limit", limit)
        span.set_attribute("products.offset", offset)
        
        try:
            products_list = list(PRODUCTS.values())[offset:offset+limit]
            
            duration = time.time() - start_time
            request_duration.labels(method="GET", endpoint="/products").observe(duration)
            request_counter.labels(method="GET", status="200", endpoint="/products").inc()
            
            span.set_attribute("products.count", len(products_list))
            span.set_status(Status(StatusCode.OK))
            
            return {"products": products_list, "total": len(PRODUCTS)}
            
        except Exception as e:
            error_counter.labels(status="500", endpoint="/products").inc()
            span.set_status(Status(StatusCode.ERROR, str(e)))
            span.record_exception(e)
            logger.error("Error listing products", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    
    # 确保日志目录存在
    os.makedirs("logs", exist_ok=True)
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8001,
        log_config=None
    )

