# order-service/schemas.py
from pydantic import BaseModel


class OrderBase(BaseModel):
    user_id: int
    product_id: int
    quantity: int


class OrderCreate(OrderBase):
    """下单时客户端传进来的字段"""
    pass


class OrderRead(OrderBase):
    """返回给客户端的订单信息"""
    id: int
    total_price: float
    status: str

    class Config:
        from_attributes = True  # 等价于 V1 里的 orm_mode = True
