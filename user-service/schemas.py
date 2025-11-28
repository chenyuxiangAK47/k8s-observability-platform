from pydantic import BaseModel, EmailStr


class UserBase(BaseModel):
    email: EmailStr
    name: str


class UserCreate(UserBase):
    password: str


class UserRead(UserBase):
    id: int

    class Config:
        # 你现在的 Pydantic 版本可能还是兼容 orm_mode，这样跟 product-service 一致
        orm_mode = True
        # 如果以后想完全用 V2 写法，可以改成:
        # from_attributes = True


class UserLogin(BaseModel):
    email: EmailStr
    password: str
