import os

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# 从环境变量读取 DATABASE_URL（docker-compose 已经配置）
# 这里给一个**按服务划分数据库**的默认值：users_db
# 这样就算在本地不跑 docker-compose，直接 `uvicorn main:app` 也能看出这是“用户服务专属数据库”。
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://postgres:postgres@microshop-postgres:5432/users_db",
)

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
