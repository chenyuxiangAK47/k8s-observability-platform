from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os

# order-service 的数据库只负责订单数据，不直接存用户/商品信息
# 通过把它指向 orders_db，可以在结构层面“逼迫”我们通过 API 去查用户/商品，
# 而不是在同一个数据库里随便 JOIN，体现微服务的数据隔离。
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://postgres:postgres@microshop-postgres:5432/orders_db",
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
