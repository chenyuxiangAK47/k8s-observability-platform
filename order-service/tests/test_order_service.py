"""
order-service 的单元测试

测试重点：
----------
1. 订单创建逻辑（需要 mock 下游服务）
2. 错误处理（用户不存在、商品不存在、库存不足、下游服务不可用）

为什么需要 mock？
----------------
- 订单服务依赖 user-service 和 product-service
- 单元测试不应该依赖真实的 HTTP 服务（避免网络问题、服务不可用等）
- 通过 mock，可以模拟各种场景：成功、失败、超时等

测试策略：
----------
- 使用 unittest.mock 或 pytest 的 monkeypatch 来 mock HTTP 调用
- 测试数据库使用 SQLite 内存数据库
"""

import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import httpx

from db import Base, get_db
from main import app
from models import Order

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


def test_create_order_success(client):
    """
    测试：成功创建订单
    
    测试场景：
    - mock 用户服务返回成功（200）
    - mock 商品服务返回成功（200），库存充足
    - 验证订单创建成功，返回正确的 total_price
    
    为什么需要 mock？
    - 订单服务需要调用 user-service 和 product-service
    - 单元测试不应该依赖真实的 HTTP 服务
    - 通过 mock，可以控制下游服务的响应
    """
    # Mock 用户服务响应
    mock_user_response = MagicMock()
    mock_user_response.status_code = 200
    mock_user_response.json.return_value = {"id": 1, "email": "test@example.com", "name": "Test User"}
    
    # Mock 商品服务响应
    mock_product_response = MagicMock()
    mock_product_response.status_code = 200
    mock_product_response.json.return_value = {
        "id": 1,
        "name": "iPhone 15",
        "price": 9999.0,
        "stock": 100
    }
    
    # 使用 patch 来替换 HTTP 客户端的 get 方法
    # 注意：patch 的路径是 '模块名.函数名'，不是文件路径
    with patch('http_client.get_user_service_client') as mock_user_client, \
         patch('http_client.get_product_service_client') as mock_product_client:
        
        # 设置 mock 返回值
        mock_user_client_instance = MagicMock()
        mock_user_client_instance.get.return_value = mock_user_response
        mock_user_client.return_value = mock_user_client_instance
        
        mock_product_client_instance = MagicMock()
        mock_product_client_instance.get.return_value = mock_product_response
        mock_product_client.return_value = mock_product_client_instance
        
        # Mock RabbitMQ 发布（避免真实连接）
        with patch('messaging.publish_order_created'):
            # 创建订单
            response = client.post(
                "/api/orders",
                json={
                    "user_id": 1,
                    "product_id": 1,
                    "quantity": 2
                }
            )
            
            assert response.status_code == 200
            data = response.json()
            assert data["user_id"] == 1
            assert data["product_id"] == 1
            assert data["quantity"] == 2
            assert data["total_price"] == 19998.0  # 9999.0 * 2


def test_create_order_user_not_found(client):
    """
    测试：用户不存在
    
    测试场景：
    - mock 用户服务返回 404
    - 验证订单服务返回 400（Bad Request）
    
    为什么返回 400 而不是 404？
    - 404 表示"资源不存在"，但这是业务错误（用户不存在），应该返回 400
    - 400 表示"客户端请求错误"，更符合业务语义
    """
    # Mock 用户服务返回 404
    mock_user_response = MagicMock()
    mock_user_response.status_code = 404
    
    with patch('http_client.get_user_service_client') as mock_user_client:
        mock_user_client_instance = MagicMock()
        mock_user_client_instance.get.return_value = mock_user_response
        mock_user_client.return_value = mock_user_client_instance
        
        # 创建订单
        response = client.post(
            "/api/orders",
            json={
                "user_id": 999,
                "product_id": 1,
                "quantity": 1
            }
        )
        
        assert response.status_code == 400
        assert "not found" in response.json()["detail"].lower()


def test_create_order_product_not_found(client):
    """
    测试：商品不存在
    
    测试场景：
    - mock 用户服务返回成功
    - mock 商品服务返回 404
    - 验证订单服务返回 400
    """
    # Mock 用户服务成功
    mock_user_response = MagicMock()
    mock_user_response.status_code = 200
    mock_user_response.json.return_value = {"id": 1}
    
    # Mock 商品服务返回 404
    mock_product_response = MagicMock()
    mock_product_response.status_code = 404
    
    with patch('http_client.get_user_service_client') as mock_user_client, \
         patch('http_client.get_product_service_client') as mock_product_client:
        
        mock_user_client_instance = MagicMock()
        mock_user_client_instance.get.return_value = mock_user_response
        mock_user_client.return_value = mock_user_client_instance
        
        mock_product_client_instance = MagicMock()
        mock_product_client_instance.get.return_value = mock_product_response
        mock_product_client.return_value = mock_product_client_instance
        
        # 创建订单
        response = client.post(
            "/api/orders",
            json={
                "user_id": 1,
                "product_id": 999,
                "quantity": 1
            }
        )
        
        assert response.status_code == 400
        assert "not found" in response.json()["detail"].lower()


def test_create_order_insufficient_stock(client):
    """
    测试：库存不足
    
    测试场景：
    - mock 用户服务成功
    - mock 商品服务成功，但库存不足
    - 验证订单服务返回 400
    """
    # Mock 用户服务成功
    mock_user_response = MagicMock()
    mock_user_response.status_code = 200
    mock_user_response.json.return_value = {"id": 1}
    
    # Mock 商品服务成功，但库存不足
    mock_product_response = MagicMock()
    mock_product_response.status_code = 200
    mock_product_response.json.return_value = {
        "id": 1,
        "name": "iPhone 15",
        "price": 9999.0,
        "stock": 5  # 库存只有 5
    }
    
    with patch('http_client.get_user_service_client') as mock_user_client, \
         patch('http_client.get_product_service_client') as mock_product_client:
        
        mock_user_client_instance = MagicMock()
        mock_user_client_instance.get.return_value = mock_user_response
        mock_user_client.return_value = mock_user_client_instance
        
        mock_product_client_instance = MagicMock()
        mock_product_client_instance.get.return_value = mock_product_response
        mock_product_client.return_value = mock_product_client_instance
        
        # 创建订单（数量 10，但库存只有 5）
        response = client.post(
            "/api/orders",
            json={
                "user_id": 1,
                "product_id": 1,
                "quantity": 10
            }
        )
        
        assert response.status_code == 400
        assert "stock" in response.json()["detail"].lower()


def test_create_order_downstream_service_unavailable(client):
    """
    测试：下游服务不可用（500 错误）
    
    测试场景：
    - mock 用户服务返回 500（服务器错误）
    - 验证订单服务返回 503（Service Unavailable）
    
    为什么返回 503 而不是 500？
    - 500 表示"我的服务出错了"
    - 503 表示"我依赖的服务不可用"，更准确
    """
    # Mock 用户服务返回 500
    mock_user_response = MagicMock()
    mock_user_response.status_code = 500
    
    with patch('http_client.get_user_service_client') as mock_user_client:
        mock_user_client_instance = MagicMock()
        mock_user_client_instance.get.return_value = mock_user_response
        mock_user_client.return_value = mock_user_client_instance
        
        # 创建订单
        response = client.post(
            "/api/orders",
            json={
                "user_id": 1,
                "product_id": 1,
                "quantity": 1
            }
        )
        
        assert response.status_code == 503
        assert "unavailable" in response.json()["detail"].lower()


def test_create_order_timeout(client):
    """
    测试：下游服务超时
    
    测试场景：
    - mock 用户服务抛出 TimeoutException
    - 验证订单服务返回 503
    
    为什么需要测试超时？
    - 超时是生产环境中常见的问题
    - 需要确保超时后不会导致请求被卡住
    """
    # Mock 用户服务超时
    with patch('http_client.get_user_service_client') as mock_user_client:
        mock_user_client_instance = MagicMock()
        mock_user_client_instance.get.side_effect = httpx.TimeoutException("Request timeout")
        mock_user_client.return_value = mock_user_client_instance
        
        # 创建订单
        response = client.post(
            "/api/orders",
            json={
                "user_id": 1,
                "product_id": 1,
                "quantity": 1
            }
        )
        
        assert response.status_code == 503
        assert "timeout" in response.json()["detail"].lower()

