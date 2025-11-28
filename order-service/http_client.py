"""
微服务间 HTTP 调用的封装工具

为什么需要这个文件？
--------------
在微服务架构中，服务之间通过 HTTP 调用是常见做法。
但直接用 requests.get() 有几个问题：
1. 没有超时：如果下游服务挂了，会一直等，导致请求被卡住
2. 没有重试：网络抖动时，一次失败就报错，不够健壮
3. 没有日志：出问题时不知道调用了哪个服务、花了多长时间
4. 错误处理不清晰：500 错误和 404 错误混在一起

这个文件封装了一个"生产级"的 HTTP 客户端，解决上述问题。
"""

import os
import time
import logging
from typing import Optional, Dict, Any
import httpx
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential,
    retry_if_exception_type,
)

# 配置日志：记录每次 HTTP 调用的详细信息
# 这样出问题时，可以通过日志快速定位：调用了哪个服务、花了多长时间、是否成功
logger = logging.getLogger(__name__)


class ServiceClient:
    """
    微服务 HTTP 客户端封装类
    
    这个类的作用：
    - 统一处理超时、重试、日志
    - 让调用其他服务的代码更简洁、更健壮
    """
    
    def __init__(
        self,
        base_url: str,
        timeout: float = 3.0,
        max_retries: int = 3,
    ):
        """
        初始化客户端
        
        参数说明：
        - base_url: 服务的基础 URL，比如 "http://user-service:8000/api/users"
        - timeout: 超时时间（秒）。如果下游服务超过这个时间没响应，就放弃等待
                  为什么需要超时？防止下游服务挂了导致我们的请求被卡住
        - max_retries: 最大重试次数。如果第一次调用失败，会自动重试
                       为什么需要重试？网络抖动时，重试一次可能就成功了
        """
        self.base_url = base_url
        self.timeout = timeout
        self.max_retries = max_retries
        
        # 创建 httpx 客户端，设置默认超时
        # httpx 比 requests 更现代，支持异步，性能更好
        self.client = httpx.Client(timeout=timeout)
    
    def get(self, path: str, **kwargs) -> httpx.Response:
        """
        发送 GET 请求（带重试和日志）
        
        参数：
        - path: 路径，比如 "/1"（会拼接到 base_url 后面）
        - **kwargs: 其他 httpx 参数
        
        返回：
        - httpx.Response 对象
        
        这个方法的特殊之处：
        1. 自动重试：如果失败，会重试最多 max_retries 次
        2. 记录日志：记录调用时间、耗时、状态码
        3. 超时保护：超过 timeout 秒就放弃
        """
        url = f"{self.base_url}{path}"
        
        # 记录开始时间，用于计算耗时
        start_time = time.time()
        
        # 使用 tenacity 装饰器实现自动重试
        # stop_after_attempt: 最多重试 max_retries 次
        # wait_exponential: 重试间隔指数增长（1秒、2秒、4秒），避免频繁重试
        # retry_if_exception_type: 只对网络异常和超时异常重试，不重试业务错误（如 404）
        @retry(
            stop=stop_after_attempt(self.max_retries),
            wait=wait_exponential(multiplier=1, min=1, max=10),
            retry=retry_if_exception_type((httpx.TimeoutException, httpx.NetworkError)),
            reraise=True,  # 重试失败后，抛出原始异常
        )
        def _make_request():
            """内部函数：实际发送请求"""
            try:
                response = self.client.get(url, **kwargs)
                return response
            except (httpx.TimeoutException, httpx.NetworkError) as e:
                # 网络异常或超时：记录日志，然后让 tenacity 自动重试
                logger.warning(f"HTTP 调用失败，将重试: {url}, 错误: {e}")
                raise  # 重新抛出异常，让 tenacity 处理重试
        
        try:
            # 执行请求（可能自动重试）
            response = _make_request()
            
            # 计算耗时
            duration = time.time() - start_time
            
            # 记录成功日志
            # 面试时可以讲：这是"可观测性"的一部分，帮助快速定位问题
            logger.info(
                f"HTTP 调用成功: {url}, "
                f"状态码={response.status_code}, "
                f"耗时={duration:.3f}秒"
            )
            
            return response
            
        except (httpx.TimeoutException, httpx.NetworkError) as e:
            # 所有重试都失败了，记录错误日志
            duration = time.time() - start_time
            logger.error(
                f"HTTP 调用最终失败: {url}, "
                f"错误={e}, "
                f"总耗时={duration:.3f}秒, "
                f"重试次数={self.max_retries}"
            )
            raise  # 重新抛出异常，让调用方处理
    
    def close(self):
        """关闭客户端（释放资源）"""
        self.client.close()


# 全局客户端实例（懒加载）
_user_service_client: Optional[ServiceClient] = None
_product_service_client: Optional[ServiceClient] = None


def get_user_service_client() -> ServiceClient:
    """
    获取用户服务客户端（单例模式）
    
    为什么用单例？
    - 避免每次调用都创建新客户端，浪费资源
    - 复用连接池，提高性能
    """
    global _user_service_client
    
    if _user_service_client is None:
        # 从环境变量读取 URL，如果没有就用默认值
        # 这样可以在不同环境（开发/测试/生产）用不同配置，不需要改代码
        base_url = os.getenv(
            "USER_SERVICE_URL",
            "http://user-service:8000/api/users"
        )
        
        _user_service_client = ServiceClient(
            base_url=base_url,
            timeout=float(os.getenv("USER_SERVICE_TIMEOUT", "3.0")),
            max_retries=int(os.getenv("USER_SERVICE_MAX_RETRIES", "3")),
        )
    
    return _user_service_client


def get_product_service_client() -> ServiceClient:
    """
    获取商品服务客户端（单例模式）
    """
    global _product_service_client
    
    if _product_service_client is None:
        base_url = os.getenv(
            "PRODUCT_SERVICE_URL",
            "http://product-service:8000/api/products"
        )
        
        _product_service_client = ServiceClient(
            base_url=base_url,
            timeout=float(os.getenv("PRODUCT_SERVICE_TIMEOUT", "3.0")),
            max_retries=int(os.getenv("PRODUCT_SERVICE_MAX_RETRIES", "3")),
        )
    
    return _product_service_client


