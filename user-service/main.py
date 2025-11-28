from typing import List

from fastapi import FastAPI, Depends, HTTPException, status
from sqlalchemy.orm import Session

from db import Base, engine, get_db
from models import User
from schemas import UserCreate, UserRead, UserLogin

app = FastAPI(title="User Service")


@app.on_event("startup")
def on_startup():
    # 确保 users 表被创建
    Base.metadata.create_all(bind=engine)


@app.get("/health")
def health():
    return {"status": "ok from user-service"}


@app.post("/api/users", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def create_user(payload: UserCreate, db: Session = Depends(get_db)):
    # 检查邮箱是否已存在
    existing = db.query(User).filter(User.email == payload.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    user = User(
        email=payload.email,
        name=payload.name,
        password=payload.password,  # demo 里直接存明文
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@app.get("/api/users", response_model=List[UserRead])
def list_users(db: Session = Depends(get_db)):
    users = db.query(User).all()
    return users


@app.get("/api/users/{user_id}", response_model=UserRead)
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return user


@app.post("/api/users/login", response_model=UserRead)
def login(payload: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == payload.email).first()
    if not user or user.password != payload.password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )
    return user
