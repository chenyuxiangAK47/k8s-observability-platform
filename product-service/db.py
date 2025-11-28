from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os

# 从环境变量读取 DATABASE_URL；在 docker-compose 中我们把 product-service 指向 products_db
# 这里提供默认值是为了：
# 1）本地单独启动服务时，能直观看到这是“商品服务专属数据库”；
# 2）面试官看代码时，一眼能看出你做了数据库按服务划分，而不是一个大杂烩库。
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://postgres:postgres@microshop-postgres:5432/products_db",
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
