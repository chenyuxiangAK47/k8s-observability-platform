import httpx
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session

from db import get_db
import models, schemas

router = APIRouter()

USER_SERVICE = "http://user-service:8000"
PRODUCT_SERVICE = "http://product-service:8000"


@router.post("/orders", response_model=schemas.OrderRead)
async def create_order(payload: schemas.OrderCreate, db: Session = Depends(get_db)):

    async with httpx.AsyncClient() as client:
        # 1. 检查用户是否存在
        user_resp = await client.get(f"{USER_SERVICE}/api/users/{payload.user_id}")
        if user_resp.status_code != 200:
            raise HTTPException(400, "User not found")

        # 2. 检查商品是否存在
        product_resp = await client.get(f"{PRODUCT_SERVICE}/api/products/{payload.product_id}")
        if product_resp.status_code != 200:
            raise HTTPException(400, "Product not found")

        product = product_resp.json()

        # 检查库存
        if product["stock"] < payload.quantity:
            raise HTTPException(400, "Not enough stock")

        # 3. 创建订单（本地数据库）
        total_price = product["price"] * payload.quantity

        new_order = models.Order(
            user_id=payload.user_id,
            product_id=payload.product_id,
            quantity=payload.quantity,
            total_price=total_price
        )

        db.add(new_order)
        db.commit()
        db.refresh(new_order)

    return new_order
