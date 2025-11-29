"""
简单的熔断器（Circuit Breaker）实现

为什么需要熔断器？
----------------
在微服务架构中，如果下游服务持续失败，继续调用会浪费资源。
熔断器的思想：
1. 正常状态：正常调用下游服务
2. 失败次数达到阈值：进入"打开"状态，直接返回错误，不再调用下游
3. 一段时间后：进入"半开"状态，尝试调用一次
4. 如果成功：回到正常状态；如果失败：继续打开状态

这是 Netflix Hystrix 的核心思想，用于防止"雪崩效应"。
"""

import os
import time
import logging
from enum import Enum
from typing import Optional
from threading import Lock

logger = logging.getLogger(__name__)


class CircuitState(Enum):
    """熔断器状态"""
    CLOSED = "closed"  # 正常状态：允许调用
    OPEN = "open"  # 打开状态：直接返回错误，不调用下游
    HALF_OPEN = "half_open"  # 半开状态：尝试调用一次


class CircuitBreaker:
    """
    简单的熔断器实现
    
    使用场景：
    - 订单服务调用用户服务时，如果用户服务持续失败，可以快速失败
    - 避免浪费资源在已经挂掉的服务上
    """
    
    def __init__(
        self,
        failure_threshold: int = 5,  # 失败多少次后打开熔断器
        timeout: float = 60.0,  # 打开状态持续多久（秒）
        half_open_timeout: float = 10.0,  # 半开状态持续多久（秒）
    ):
        """
        初始化熔断器
        
        参数：
        - failure_threshold: 连续失败多少次后打开熔断器
        - timeout: 打开状态持续多久（秒），之后进入半开状态
        - half_open_timeout: 半开状态持续多久（秒），之后尝试调用
        """
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.half_open_timeout = half_open_timeout
        
        self.state = CircuitState.CLOSED
        self.failure_count = 0
        self.last_failure_time: Optional[float] = None
        self.last_half_open_time: Optional[float] = None
        self.lock = Lock()  # 线程安全
    
    def call(self, func, *args, **kwargs):
        """
        通过熔断器调用函数
        
        如果熔断器处于打开状态，直接抛出异常，不调用函数
        如果处于半开状态，尝试调用一次
        如果处于关闭状态，正常调用
        """
        with self.lock:
            # 检查状态转换
            self._check_state_transition()
            
            if self.state == CircuitState.OPEN:
                # 打开状态：直接返回错误
                logger.warning("熔断器处于打开状态，跳过调用")
                raise Exception("Circuit breaker is OPEN")
            
            if self.state == CircuitState.HALF_OPEN:
                # 半开状态：尝试调用一次
                logger.info("熔断器处于半开状态，尝试调用一次")
        
        # 调用函数（不在锁内，避免阻塞）
        try:
            result = func(*args, **kwargs)
            # 调用成功，重置失败计数
            with self.lock:
                self._on_success()
            return result
        except Exception as e:
            # 调用失败，增加失败计数
            with self.lock:
                self._on_failure()
            raise
    
    def _check_state_transition(self):
        """检查并更新状态"""
        now = time.time()
        
        if self.state == CircuitState.OPEN:
            # 打开状态：检查是否应该进入半开状态
            if self.last_failure_time and (now - self.last_failure_time) >= self.timeout:
                logger.info("熔断器从打开状态进入半开状态")
                self.state = CircuitState.HALF_OPEN
                self.last_half_open_time = now
        
        elif self.state == CircuitState.HALF_OPEN:
            # 半开状态：检查是否应该回到打开状态
            if self.last_half_open_time and (now - self.last_half_open_time) >= self.half_open_timeout:
                # 半开状态超时，如果还没成功，回到打开状态
                if self.failure_count >= self.failure_threshold:
                    logger.warning("半开状态超时，回到打开状态")
                    self.state = CircuitState.OPEN
                    self.last_failure_time = now
    
    def _on_success(self):
        """调用成功时的处理"""
        if self.state == CircuitState.HALF_OPEN:
            # 半开状态下成功，回到关闭状态
            logger.info("半开状态下调用成功，熔断器回到关闭状态")
            self.state = CircuitState.CLOSED
        
        # 重置失败计数
        self.failure_count = 0
        self.last_failure_time = None
    
    def _on_failure(self):
        """调用失败时的处理"""
        self.failure_count += 1
        self.last_failure_time = time.time()
        
        if self.failure_count >= self.failure_threshold:
            if self.state == CircuitState.CLOSED:
                # 关闭状态下失败次数达到阈值，打开熔断器
                logger.error(
                    "失败次数达到阈值（%d），打开熔断器",
                    self.failure_threshold
                )
                self.state = CircuitState.OPEN
            elif self.state == CircuitState.HALF_OPEN:
                # 半开状态下失败，回到打开状态
                logger.warning("半开状态下调用失败，回到打开状态")
                self.state = CircuitState.OPEN


# 全局熔断器实例（每个下游服务一个）
_user_service_circuit_breaker: Optional[CircuitBreaker] = None
_product_service_circuit_breaker: Optional[CircuitBreaker] = None


def get_user_service_circuit_breaker() -> CircuitBreaker:
    """获取用户服务的熔断器（单例）"""
    global _user_service_circuit_breaker
    if _user_service_circuit_breaker is None:
        _user_service_circuit_breaker = CircuitBreaker(
            failure_threshold=int(os.getenv("USER_SERVICE_CIRCUIT_BREAKER_THRESHOLD", "5")),
            timeout=float(os.getenv("USER_SERVICE_CIRCUIT_BREAKER_TIMEOUT", "60.0")),
        )
    return _user_service_circuit_breaker


def get_product_service_circuit_breaker() -> CircuitBreaker:
    """获取商品服务的熔断器（单例）"""
    global _product_service_circuit_breaker
    if _product_service_circuit_breaker is None:
        _product_service_circuit_breaker = CircuitBreaker(
            failure_threshold=int(os.getenv("PRODUCT_SERVICE_CIRCUIT_BREAKER_THRESHOLD", "5")),
            timeout=float(os.getenv("PRODUCT_SERVICE_CIRCUIT_BREAKER_TIMEOUT", "60.0")),
        )
    return _product_service_circuit_breaker

