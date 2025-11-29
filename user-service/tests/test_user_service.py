"""
user-service 的单元测试

为什么需要测试？
--------------
1. 验证业务逻辑正确性：用户创建、查询、登录等功能是否按预期工作
2. 防止回归：修改代码后，测试能快速发现是否破坏了原有功能
3. 文档作用：测试用例本身就是"如何使用这个 API"的示例

测试策略：
----------
- 使用 pytest 作为测试框架
- 使用 SQLite 内存数据库（:memory:）作为测试数据库，避免依赖真实的 PostgreSQL
- 每个测试用例独立运行，互不干扰（通过 fixture 实现）
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from db import Base, get_db
from main import app
from models import User


# 创建测试数据库（SQLite 内存数据库）
# 为什么用 SQLite 而不是 PostgreSQL？
# - 更快：不需要启动真实的数据库服务
# - 更简单：测试时不需要 Docker
# - 足够：对于单元测试，SQLite 的行为和 PostgreSQL 基本一致
TEST_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="function")
def db_session():
    """
    测试数据库会话 fixture
    
    为什么用 fixture？
    - 每个测试用例运行前，自动创建新的数据库和会话
    - 测试用例运行后，自动清理（回滚事务）
    - 确保测试用例之间互不干扰
    """
    # 创建表
    Base.metadata.create_all(bind=engine)
    
    # 创建会话
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        # 清理：回滚事务，删除表
        db.rollback()
        Base.metadata.drop_all(bind=engine)
        db.close()


@pytest.fixture(scope="function")
def client(db_session):
    """
    测试客户端 fixture
    
    为什么需要这个？
    - TestClient 是 FastAPI 提供的测试工具，可以模拟 HTTP 请求
    - 不需要启动真实的服务器，直接在内存中运行
    - 通过依赖注入，把测试数据库会话注入到 get_db() 中
    """
    def override_get_db():
        try:
            yield db_session
        finally:
            pass
    
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_create_user_success(client):
    """
    测试：成功创建用户
    
    测试场景：
    - 创建一个新用户
    - 验证返回的状态码是 201（Created）
    - 验证返回的数据包含 email、name、id
    """
    response = client.post(
        "/api/users",
        json={
            "email": "test@example.com",
            "name": "Test User",
            "password": "password123"
        }
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "test@example.com"
    assert data["name"] == "Test User"
    assert "id" in data


def test_create_user_duplicate_email(client):
    """
    测试：重复邮箱不能创建用户
    
    测试场景：
    - 先创建一个用户
    - 再用相同的邮箱创建用户
    - 验证返回 400（Bad Request）和错误信息
    """
    # 第一次创建
    client.post(
        "/api/users",
        json={
            "email": "duplicate@example.com",
            "name": "First User",
            "password": "password123"
        }
    )
    
    # 第二次创建（相同邮箱）
    response = client.post(
        "/api/users",
        json={
            "email": "duplicate@example.com",
            "name": "Second User",
            "password": "password456"
        }
    )
    
    assert response.status_code == 400
    assert "already registered" in response.json()["detail"].lower()


def test_get_user_success(client):
    """
    测试：成功查询用户
    
    测试场景：
    - 先创建一个用户
    - 通过 id 查询用户
    - 验证返回的数据正确
    """
    # 创建用户
    create_response = client.post(
        "/api/users",
        json={
            "email": "get@example.com",
            "name": "Get User",
            "password": "password123"
        }
    )
    user_id = create_response.json()["id"]
    
    # 查询用户
    response = client.get(f"/api/users/{user_id}")
    
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == user_id
    assert data["email"] == "get@example.com"
    assert data["name"] == "Get User"


def test_get_user_not_found(client):
    """
    测试：查询不存在的用户
    
    测试场景：
    - 查询一个不存在的用户 id
    - 验证返回 404（Not Found）
    """
    response = client.get("/api/users/99999")
    
    assert response.status_code == 404
    assert "not found" in response.json()["detail"].lower()


def test_login_success(client):
    """
    测试：成功登录
    
    测试场景：
    - 先创建一个用户
    - 用正确的邮箱和密码登录
    - 验证返回用户信息
    """
    # 创建用户
    client.post(
        "/api/users",
        json={
            "email": "login@example.com",
            "name": "Login User",
            "password": "correct_password"
        }
    )
    
    # 登录
    response = client.post(
        "/api/users/login",
        json={
            "email": "login@example.com",
            "password": "correct_password"
        }
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "login@example.com"


def test_login_invalid_credentials(client):
    """
    测试：登录失败（错误的密码）
    
    测试场景：
    - 先创建一个用户
    - 用错误的密码登录
    - 验证返回 401（Unauthorized）
    """
    # 创建用户
    client.post(
        "/api/users",
        json={
            "email": "login2@example.com",
            "name": "Login User 2",
            "password": "correct_password"
        }
    )
    
    # 用错误密码登录
    response = client.post(
        "/api/users/login",
        json={
            "email": "login2@example.com",
            "password": "wrong_password"
        }
    )
    
    assert response.status_code == 401
    assert "invalid" in response.json()["detail"].lower()

