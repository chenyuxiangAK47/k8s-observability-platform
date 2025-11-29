"""
集成测试：验证服务间调用和事件驱动流程

为什么需要集成测试？
------------------
- 单元测试只测试单个服务的逻辑，不测试服务间的交互
- 集成测试验证整个系统是否能正常工作
- 可以验证 HTTP 调用、事件消费等跨服务功能

测试策略：
----------
- 使用 Docker Compose 启动完整环境（3 个服务 + PostgreSQL + RabbitMQ）
- 测试端到端流程：创建用户 → 创建商品 → 创建订单 → 验证库存扣减
- 使用真实的 HTTP 调用和事件消费（不 mock）

注意：
----
- 这个测试需要 Docker 环境
- 运行时间较长（需要启动多个容器）
- 适合在 CI/CD 中运行，不适合频繁的本地开发
"""

import pytest
import time
import requests
import subprocess
import os


# 服务地址（Docker Compose 网络内）
USER_SERVICE_URL = os.getenv("USER_SERVICE_URL", "http://localhost:8001")
PRODUCT_SERVICE_URL = os.getenv("PRODUCT_SERVICE_URL", "http://localhost:8002")
ORDER_SERVICE_URL = os.getenv("ORDER_SERVICE_URL", "http://localhost:8003")


@pytest.fixture(scope="module")
def wait_for_services():
    """
    等待服务启动完成
    
    为什么需要这个？
    - Docker Compose 启动服务需要时间
    - 如果测试立即运行，服务可能还没准备好
    - 通过轮询健康检查接口，确保服务可用
    """
    max_attempts = 30
    for attempt in range(max_attempts):
        try:
            # 检查三个服务的健康检查接口
            requests.get(f"{USER_SERVICE_URL}/health", timeout=2)
            requests.get(f"{PRODUCT_SERVICE_URL}/health", timeout=2)
            requests.get(f"{ORDER_SERVICE_URL}/health", timeout=2)
            print("所有服务已启动")
            return
        except requests.exceptions.RequestException:
            if attempt < max_attempts - 1:
                time.sleep(2)
            else:
                pytest.fail("服务启动超时")


@pytest.mark.integration
def test_end_to_end_order_flow(wait_for_services):
    """
    端到端测试：完整的下单流程
    
    测试场景：
    1. 创建用户
    2. 创建商品（库存 100）
    3. 创建订单（数量 3）
    4. 验证库存被扣减（100 → 97）
    
    为什么这是集成测试？
    - 涉及三个服务的交互
    - 使用真实的 HTTP 调用
    - 使用真实的 RabbitMQ 事件消费
    - 验证整个系统的行为
    """
    # 1. 创建用户
    user_response = requests.post(
        f"{USER_SERVICE_URL}/api/users",
        json={
            "email": f"test_{int(time.time())}@example.com",
            "name": "Integration Test User",
            "password": "password123"
        },
        timeout=5
    )
    assert user_response.status_code == 201
    user_id = user_response.json()["id"]
    print(f"✓ 用户创建成功: user_id={user_id}")
    
    # 2. 创建商品
    product_response = requests.post(
        f"{PRODUCT_SERVICE_URL}/api/products/",
        json={
            "name": "Integration Test Product",
            "description": "Test product for integration test",
            "price": 9999.0,
            "stock": 100
        },
        timeout=5
    )
    assert product_response.status_code == 201
    product_id = product_response.json()["id"]
    initial_stock = product_response.json()["stock"]
    print(f"✓ 商品创建成功: product_id={product_id}, stock={initial_stock}")
    
    # 3. 创建订单
    order_response = requests.post(
        f"{ORDER_SERVICE_URL}/api/orders",
        json={
            "user_id": user_id,
            "product_id": product_id,
            "quantity": 3
        },
        timeout=10  # 订单服务需要调用下游服务，可能需要更长时间
    )
    assert order_response.status_code == 200
    order_data = order_response.json()
    assert order_data["total_price"] == 29997.0  # 9999.0 * 3
    print(f"✓ 订单创建成功: order_id={order_data['id']}, total_price={order_data['total_price']}")
    
    # 4. 等待事件消费（RabbitMQ 异步处理需要时间）
    # 为什么需要等待？
    # - 订单服务发布事件后，商品服务异步消费
    # - 需要给事件消费一些时间（通常几秒内）
    max_wait = 10
    for attempt in range(max_wait):
        time.sleep(1)
        product_check = requests.get(f"{PRODUCT_SERVICE_URL}/api/products/{product_id}", timeout=5)
        if product_check.status_code == 200:
            current_stock = product_check.json()["stock"]
            if current_stock == initial_stock - 3:  # 库存应该减少 3
                print(f"✓ 库存扣减成功: {initial_stock} → {current_stock}")
                assert current_stock == 97
                return
        if attempt == max_wait - 1:
            pytest.fail(f"库存扣减超时，当前库存: {current_stock}")


@pytest.mark.integration
def test_order_with_nonexistent_user(wait_for_services):
    """
    集成测试：使用不存在的用户创建订单
    
    验证点：
    - 订单服务应该返回 400（Bad Request）
    - 不应该创建订单
    """
    # 创建商品（订单需要商品存在）
    product_response = requests.post(
        f"{PRODUCT_SERVICE_URL}/api/products/",
        json={
            "name": "Test Product",
            "description": "Test",
            "price": 100.0,
            "stock": 10
        },
        timeout=5
    )
    product_id = product_response.json()["id"]
    
    # 尝试用不存在的用户创建订单
    order_response = requests.post(
        f"{ORDER_SERVICE_URL}/api/orders",
        json={
            "user_id": 99999,  # 不存在的用户
            "product_id": product_id,
            "quantity": 1
        },
        timeout=10
    )
    
    assert order_response.status_code == 400
    assert "not found" in order_response.json()["detail"].lower()
    print("✓ 正确处理了不存在的用户")


@pytest.mark.integration
def test_order_with_insufficient_stock(wait_for_services):
    """
    集成测试：库存不足时创建订单
    
    验证点：
    - 订单服务应该返回 400（Bad Request）
    - 不应该创建订单
    """
    # 创建用户
    user_response = requests.post(
        f"{USER_SERVICE_URL}/api/users",
        json={
            "email": f"test_stock_{int(time.time())}@example.com",
            "name": "Test User",
            "password": "password123"
        },
        timeout=5
    )
    user_id = user_response.json()["id"]
    
    # 创建商品（库存只有 5）
    product_response = requests.post(
        f"{PRODUCT_SERVICE_URL}/api/products/",
        json={
            "name": "Low Stock Product",
            "description": "Test",
            "price": 100.0,
            "stock": 5
        },
        timeout=5
    )
    product_id = product_response.json()["id"]
    
    # 尝试购买 10 件（库存不足）
    order_response = requests.post(
        f"{ORDER_SERVICE_URL}/api/orders",
        json={
            "user_id": user_id,
            "product_id": product_id,
            "quantity": 10  # 超过库存
        },
        timeout=10
    )
    
    assert order_response.status_code == 400
    assert "stock" in order_response.json()["detail"].lower()
    print("✓ 正确处理了库存不足的情况")

