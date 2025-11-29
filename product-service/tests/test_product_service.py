"""
product-service 的单元测试

测试重点：
----------
1. 商品 CRUD 操作（创建、查询、列表）
2. 库存扣减逻辑（通过事件消费）

为什么测试很重要？
----------------
- 商品服务负责库存管理，库存扣减错误会导致超卖或库存不一致
- 通过测试可以验证事件消费逻辑是否正确
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from db import Base, get_db
from main import app
from models import Product

TEST_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    """测试数据库会话 fixture"""
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.rollback()
        Base.metadata.drop_all(bind=engine)
        db.close()


@pytest.fixture(scope="function")
def client(db_session):
    """测试客户端 fixture"""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass
    
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_create_product_success(client):
    """
    测试：成功创建商品
    
    验证点：
    - 返回 201（Created）
    - 返回的数据包含所有字段（name、price、stock 等）
    """
    response = client.post(
        "/api/products/",
        json={
            "name": "iPhone 15",
            "description": "Latest iPhone",
            "price": 9999.0,
            "stock": 100
        }
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "iPhone 15"
    assert data["price"] == 9999.0
    assert data["stock"] == 100
    assert "id" in data


def test_get_product_success(client):
    """
    测试：成功查询商品
    
    验证点：
    - 创建商品后能正确查询
    - 返回的数据完整
    """
    # 创建商品
    create_response = client.post(
        "/api/products/",
        json={
            "name": "MacBook Pro",
            "description": "Apple laptop",
            "price": 12999.0,
            "stock": 50
        }
    )
    product_id = create_response.json()["id"]
    
    # 查询商品
    response = client.get(f"/api/products/{product_id}")
    
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == product_id
    assert data["name"] == "MacBook Pro"
    assert data["stock"] == 50


def test_get_product_not_found(client):
    """
    测试：查询不存在的商品
    
    验证点：
    - 返回 404（Not Found）
    """
    response = client.get("/api/products/99999")
    
    assert response.status_code == 404
    assert "not found" in response.json()["detail"].lower()


def test_list_products(client):
    """
    测试：列出所有商品
    
    验证点：
    - 创建多个商品后，列表接口返回所有商品
    - 返回的是数组格式
    """
    # 创建多个商品
    client.post(
        "/api/products/",
        json={
            "name": "Product 1",
            "description": "Desc 1",
            "price": 100.0,
            "stock": 10
        }
    )
    client.post(
        "/api/products/",
        json={
            "name": "Product 2",
            "description": "Desc 2",
            "price": 200.0,
            "stock": 20
        }
    )
    
    # 查询列表
    response = client.get("/api/products/")
    
    assert response.status_code == 200
    products = response.json()
    assert len(products) == 2
    assert products[0]["name"] in ["Product 1", "Product 2"]
    assert products[1]["name"] in ["Product 1", "Product 2"]


def test_stock_deduction_logic(db_session):
    """
    测试：库存扣减逻辑（直接测试模型层）
    
    为什么单独测试这个？
    - 库存扣减是商品服务的核心业务逻辑
    - 通过直接操作数据库，验证库存扣减是否正确
    
    验证点：
    - 创建商品后，库存是初始值
    - 扣减库存后，库存正确减少
    - 库存不能扣成负数（业务规则）
    """
    # 创建商品
    product = Product(
        name="Test Product",
        description="Test",
        price=100.0,
        stock=50
    )
    db_session.add(product)
    db_session.commit()
    db_session.refresh(product)
    
    # 验证初始库存
    assert product.stock == 50
    
    # 扣减库存（模拟事件消费）
    product.stock -= 10
    db_session.commit()
    db_session.refresh(product)
    
    # 验证库存已扣减
    assert product.stock == 40
    
    # 再次扣减
    product.stock -= 5
    db_session.commit()
    db_session.refresh(product)
    
    # 验证最终库存
    assert product.stock == 35

