"""
RabbitMQ 消费者：监听订单事件并扣减库存

为什么要用消息队列？
---------------------------
- 订单服务发布“订单创建”事件，商品服务订阅事件来自主扣库存
- 两个服务之间通过 MQ 解耦，不需要同步等待 → 更抗压
- 面试时可以讲：这是事件驱动 + 最终一致性 + 异步库存扣减
"""

import json
import logging
import os
import threading
import time
from typing import Optional

import pika

from db import SessionLocal
from models import Product

logger = logging.getLogger(__name__)


RABBITMQ_URL = os.getenv(
    "RABBITMQ_URL",
    "amqp://guest:guest@microshop-rabbitmq:5672/",
)
ORDER_EVENTS_EXCHANGE = os.getenv(
    "ORDER_EVENTS_EXCHANGE",
    "order.events",
)
# 每个消费者都可以有自己的队列，便于水平扩展
ORDER_EVENTS_QUEUE = os.getenv(
    "PRODUCT_ORDER_QUEUE",
    "product-service.order-consumer",
)
# 死信队列（Dead Letter Queue）：处理失败的消息
# 为什么需要死信队列？
# - 如果消息处理失败（如数据库错误、业务逻辑错误），不能无限重试
# - 把失败的消息放到死信队列，后续可以人工处理或自动补偿
DLQ_NAME = os.getenv("DLQ_NAME", "product-service.dlq")
MAX_RETRIES = int(os.getenv("MAX_RETRY_COUNT", "3"))  # 最大重试次数

# 运行中的连接和消费线程，用于优雅关闭
_connection: Optional[pika.BlockingConnection] = None
_consumer_thread: Optional[threading.Thread] = None
_stop_event = threading.Event()


def start_order_event_consumer() -> None:
    """
    在独立线程里启动 RabbitMQ 消费者

    为什么用线程？
    - FastAPI 主线程负责 HTTP
    - 事件消费是一条“常驻任务”，丢给后台线程即可
    """
    global _consumer_thread
    logger.info("启动订单事件消费者线程…")
    _stop_event.clear()
    _consumer_thread = threading.Thread(target=_consume_loop, daemon=True)
    _consumer_thread.start()


def stop_order_event_consumer() -> None:
    """
    停止消费者线程（用于 FastAPI shutdown）
    """
    logger.info("正在停止订单事件消费者…")
    _stop_event.set()

    global _connection
    if _connection and _connection.is_open:
        _connection.close()  # 关闭连接会打断 start_consuming 循环

    if _consumer_thread:
        _consumer_thread.join(timeout=5)


def _consume_loop() -> None:
    """
    循环建立连接 → 消费订单事件 → 处理库存

    如果 MQ 短暂不可用，会自动等待 2 秒重新连接，
    以模拟真实系统里的“自愈性”。
    """
    global _connection
    while not _stop_event.is_set():
        try:
            logger.info("连接到 RabbitMQ: %s", RABBITMQ_URL)
            _connection = pika.BlockingConnection(pika.URLParameters(RABBITMQ_URL))
            channel = _connection.channel()

            channel.exchange_declare(
                exchange=ORDER_EVENTS_EXCHANGE,
                exchange_type="fanout",
                durable=True,
            )
            # 声明死信队列
            channel.queue_declare(queue=DLQ_NAME, durable=True)
            
            # 声明主队列，并绑定死信队列
            # 如果消息被拒绝（reject）且 requeue=False，会被路由到死信队列
            channel.queue_declare(
                queue=ORDER_EVENTS_QUEUE,
                durable=True,
                arguments={
                    "x-dead-letter-exchange": "",  # 使用默认 exchange
                    "x-dead-letter-routing-key": DLQ_NAME,  # 路由到死信队列
                    "x-message-ttl": 60000,  # 消息 TTL：60 秒（可选）
                }
            )
            channel.queue_bind(
                queue=ORDER_EVENTS_QUEUE,
                exchange=ORDER_EVENTS_EXCHANGE,
            )

            # 限制未确认消息数，防止一次拉太多影响内存
            channel.basic_qos(prefetch_count=1)

            def _on_message(ch, method, properties, body):
                """
                消息处理回调
                
                容错策略：
                1. 如果处理成功，ack 消息
                2. 如果处理失败，检查重试次数：
                   - 如果未达到最大重试次数，nack 并 requeue（重新入队）
                   - 如果达到最大重试次数，发送到死信队列
                """
                retry_count = 0
                if properties.headers:
                    retry_count = properties.headers.get("x-retry-count", 0)
                
                try:
                    _handle_order_event(body)
                    # 处理成功，确认消息
                    ch.basic_ack(delivery_tag=method.delivery_tag)
                    logger.info("消息处理成功：delivery_tag=%s", method.delivery_tag)
                except Exception as exc:
                    logger.exception("处理订单事件失败：%s", exc)
                    
                    if retry_count < MAX_RETRIES:
                        # 未达到最大重试次数，重新入队
                        retry_count += 1
                        logger.warning(
                            "消息处理失败，重试 %d/%d：delivery_tag=%s",
                            retry_count,
                            MAX_RETRIES,
                            method.delivery_tag
                        )
                        # nack 并 requeue=True，消息会重新入队
                        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)
                    else:
                        # 达到最大重试次数，发送到死信队列
                        logger.error(
                            "消息达到最大重试次数，发送到死信队列：delivery_tag=%s, retry_count=%d",
                            method.delivery_tag,
                            retry_count
                        )
                        # 发送到死信队列
                        ch.basic_publish(
                            exchange="",
                            routing_key=DLQ_NAME,
                            body=body,
                            properties=pika.BasicProperties(
                                headers={"x-original-retry-count": retry_count},
                                delivery_mode=2,  # 持久化
                            )
                        )
                        # 确认原消息（避免重复处理）
                        ch.basic_ack(delivery_tag=method.delivery_tag)

            logger.info("订单事件消费者已就绪，等待消息…")
            channel.basic_consume(
                queue=ORDER_EVENTS_QUEUE,
                on_message_callback=_on_message,
            )
            channel.start_consuming()

        except pika.exceptions.AMQPConnectionError as exc:
            logger.error("RabbitMQ 连接失败，2 秒后重试：%s", exc)
            time.sleep(2)
        except Exception as exc:
            # 其余异常同样记录并尝试重连
            logger.exception("订单事件消费者异常，2 秒后重试：%s", exc)
            time.sleep(2)


def _handle_order_event(body: bytes) -> None:
    """
    解析订单事件并扣减库存
    """
    payload = json.loads(body.decode("utf-8"))
    if payload.get("event_type") != "ORDER_CREATED":
        logger.debug("忽略非 ORDER_CREATED 事件：%s", payload)
        return

    product_id = payload["product_id"]
    quantity = payload["quantity"]
    order_id = payload["order_id"]

    logger.info(
        "收到订单事件：order_id=%s product_id=%s quantity=%s",
        order_id,
        product_id,
        quantity,
    )

    session = SessionLocal()
    try:
        product = session.query(Product).filter(Product.id == product_id).first()
        if not product:
            logger.warning("找不到产品（可能已被删除）：product_id=%s", product_id)
            return

        if product.stock < quantity:
            # 这里先简单打印日志，在真实场景可以把事件发送到“补偿队列”或报警
            logger.warning(
                "库存不足，无法扣减：product_id=%s current_stock=%s need=%s",
                product_id,
                product.stock,
                quantity,
            )
            return

        product.stock -= quantity
        session.commit()
        logger.info(
            "库存扣减成功：product_id=%s 剩余=%s (order_id=%s)",
            product_id,
            product.stock,
            order_id,
        )
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()



