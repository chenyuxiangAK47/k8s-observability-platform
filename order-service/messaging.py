"""
RabbitMQ 事件发布工具

为什么需要这一层封装？
--------------------------------
- 让订单服务在创建订单后**发布事件**，而不是直接去扣库存
- 这样商品服务可以异步订阅事件，真正做到“服务之间通过消息协作”
- 面试 / 简历上可以强调这是“事件驱动 + 最终一致性”的设计
"""

import json
import logging
import os
from typing import Any, Dict

import pika

logger = logging.getLogger(__name__)

# 允许通过环境变量覆盖，方便不同环境（本地/测试/生产）使用不同的 MQ 地址
RABBITMQ_URL = os.getenv(
    "RABBITMQ_URL",
    "amqp://guest:guest@microshop-rabbitmq:5672/",
)

# 事件总线（exchange）名称，默认使用 fanout，将同一事件广播给多个服务
ORDER_EVENTS_EXCHANGE = os.getenv(
    "ORDER_EVENTS_EXCHANGE",
    "order.events",
)


def publish_order_created(order: Any) -> None:
    """
    将“订单已创建”事件广播出去

    为什么要有这个事件？
    - 订单服务只负责落订单，不直接改商品库存
    - 商品服务（或其他服务）监听这个事件，自主处理库存/通知等逻辑
    - 这样可以把服务解耦：订单服务挂了不影响库存服务的逻辑，反之亦然

    为了让事件更容易被其他语言/服务消费，我们发送 JSON 格式。
    """
    payload: Dict[str, Any] = {
        "event_type": "ORDER_CREATED",
        "order_id": order.id,
        "user_id": order.user_id,
        "product_id": order.product_id,
        "quantity": order.quantity,
        "total_price": order.total_price,
    }

    message = json.dumps(payload).encode("utf-8")
    logger.info("准备发布订单事件：%s", payload)

    # 每次发布都新建连接，简单直观（并在注释里解释原因）
    # 在超大流量场景可以考虑连接池，不过 demo 项目重视可读性
    connection = pika.BlockingConnection(pika.URLParameters(RABBITMQ_URL))
    channel = connection.channel()

    # 声明一个持久化的 fanout exchange，确保交换机存在
    channel.exchange_declare(
        exchange=ORDER_EVENTS_EXCHANGE,
        exchange_type="fanout",
        durable=True,
    )

    # 发布消息；delivery_mode=2 表示消息持久化，防止 MQ 重启丢数据
    channel.basic_publish(
        exchange=ORDER_EVENTS_EXCHANGE,
        routing_key="",
        body=message,
        properties=pika.BasicProperties(delivery_mode=2),
    )

    logger.info("订单事件已发送：order_id=%s -> exchange=%s", order.id, ORDER_EVENTS_EXCHANGE)
    connection.close()



