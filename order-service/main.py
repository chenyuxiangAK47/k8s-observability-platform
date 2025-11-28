from fastapi import FastAPI, HTTPException, Depends, status
from sqlalchemy.orm import Session
from typing import List
import logging
import httpx

from db import Base, engine, get_db
from models import Order
from schemas import OrderCreate, OrderRead
from http_client import get_user_service_client, get_product_service_client
from messaging import publish_order_created

# 配置日志：记录服务间调用的详细信息
# 这样出问题时，可以通过日志快速定位：调用了哪个服务、花了多长时间、是否成功
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Order Service")


@app.on_event("startup")
def on_startup():
    """服务启动时创建数据库表"""
    Base.metadata.create_all(bind=engine)


@app.on_event("shutdown")
def on_shutdown():
    """服务关闭时释放 HTTP 客户端资源"""
    get_user_service_client().close()
    get_product_service_client().close()


@app.post("/api/orders", response_model=OrderRead)
def create_order(
    order: OrderCreate,
    db: Session = Depends(get_db),
):
    """
    创建订单
    
    这个函数的改进点（相比之前的版本）：
    1. 使用封装好的 HTTP 客户端，自动处理超时、重试、日志
    2. 区分不同类型的错误（404 vs 500 vs 超时），返回更准确的错误信息
    3. 如果下游服务不可用，返回 503（服务不可用），而不是 400（客户端错误）
    
    为什么这样改？
    - 404（用户不存在）是业务错误，应该返回 400
    - 500（用户服务崩了）是系统错误，应该返回 503，告诉调用方"服务暂时不可用"
    - 超时也是系统问题，应该返回 503
    """
    
    # 1. 验证用户存在（调用用户服务）
    # 使用封装好的 HTTP 客户端，自动处理超时、重试、日志
    user_client = get_user_service_client()
    
    try:
        user_response = user_client.get(f"/{order.user_id}")
        
        # 根据状态码判断错误类型
        if user_response.status_code == 404:
            # 404：用户不存在，这是业务错误，返回 400
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User not found"
            )
        elif user_response.status_code >= 500:
            # 500+：用户服务内部错误，返回 503（服务不可用）
            # 为什么返回 503 而不是 500？
            # - 500 表示"我的服务出错了"
            # - 503 表示"我依赖的服务不可用"，更准确
            logger.error(f"用户服务返回错误: {user_response.status_code}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="User service unavailable"
            )
        elif user_response.status_code != 200:
            # 其他错误（如 401、403），也返回 503
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"User service returned {user_response.status_code}"
            )
            
    except httpx.TimeoutException:
        # 超时：用户服务响应太慢，返回 503
        logger.error(f"调用用户服务超时: user_id={order.user_id}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="User service timeout"
        )
    except httpx.NetworkError as e:
        # 网络错误：用户服务可能挂了，返回 503
        logger.error(f"调用用户服务网络错误: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="User service network error"
        )
    
    # 2. 验证产品存在（调用商品服务）
    product_client = get_product_service_client()
    
    try:
        product_response = product_client.get(f"/{order.product_id}")
        
        if product_response.status_code == 404:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Product not found"
            )
        elif product_response.status_code >= 500:
            logger.error(f"商品服务返回错误: {product_response.status_code}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Product service unavailable"
            )
        elif product_response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Product service returned {product_response.status_code}"
            )
            
        product_data = product_response.json()
        
    except httpx.TimeoutException:
        logger.error(f"调用商品服务超时: product_id={order.product_id}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Product service timeout"
        )
    except httpx.NetworkError as e:
        logger.error(f"调用商品服务网络错误: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Product service network error"
        )
    
    # 3. 检查库存（业务逻辑）
    if product_data["stock"] < order.quantity:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Not enough stock"
        )
    
    # 4. 创建订单（保存到本地数据库）
    # 注意：这里只保存订单，不扣减库存
    # 为什么？因为库存应该由商品服务管理，订单服务不应该直接改商品数据
    # （这是微服务"数据自治"的体现）
    new_order = Order(
        user_id=order.user_id,
        product_id=order.product_id,
        quantity=order.quantity,
        total_price=product_data["price"] * order.quantity,
    )
    
    db.add(new_order)
    db.commit()
    db.refresh(new_order)
    
    logger.info(f"订单创建成功: order_id={new_order.id}, user_id={order.user_id}, product_id={order.product_id}")

    # 5. 发布“订单已创建”事件（事件驱动，交给商品服务去扣库）
    try:
        publish_order_created(new_order)
    except Exception as exc:  # pragma: no cover - demo 环境下主要用于教学
        # 这里我们只是记录错误，在真正生产环境会把状态标记成“待补偿”并提供重试机制
        logger.error("发布订单事件失败（不会回滚订单）：%s", exc)
    
    return new_order


@app.get("/api/orders/{order_id}", response_model=OrderRead)
def get_order(order_id: int, db: Session = Depends(get_db)):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@app.get("/api/orders", response_model=List[OrderRead])
def list_orders(db: Session = Depends(get_db)):
    orders = db.query(Order).all()
    return orders


@app.get("/health")
def health():
    return {"status": "ok"}
