from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import logging

from db import Base, engine, get_db
from models import Product
from schemas import ProductCreate, ProductRead
from event_consumer import (
    start_order_event_consumer,
    stop_order_event_consumer,
)

# 记录日志，便于观察事件消费情况
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Product Service")


@app.on_event("startup")
def on_startup():
    Base.metadata.create_all(bind=engine)
    # 启动订单事件消费者：异步扣减库存
    start_order_event_consumer()


@app.on_event("shutdown")
def on_shutdown():
    # 关闭事件消费者，避免线程泄漏
    stop_order_event_consumer()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/api/products/", response_model=ProductRead, status_code=201)
def create_product(payload: ProductCreate, db: Session = Depends(get_db)):
    product = Product(
        name=payload.name,
        description=payload.description,
        price=payload.price,
        stock=payload.stock,
    )
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@app.get("/api/products/", response_model=List[ProductRead])
def list_products(db: Session = Depends(get_db)):
    products = db.query(Product).all()
    return products


@app.get("/api/products/{product_id}", response_model=ProductRead)
def get_product(product_id: int, db: Session = Depends(get_db)):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product
