"""
OpenTelemetry 配置模块
统一的可观测性配置，用于所有微服务
"""
import logging
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def setup_otel(service_name: str, service_version: str = "1.0.0"):
    """
    初始化 OpenTelemetry
    
    Args:
        service_name: 服务名称
        service_version: 服务版本
    """
    # 创建资源信息
    resource = Resource.create({
        "service.name": service_name,
        "service.version": service_version,
        "service.namespace": "observability-demo",
    })
    
    # 配置 Tracer
    trace.set_tracer_provider(
        TracerProvider(resource=resource)
    )
    tracer = trace.get_tracer(__name__)
    
    # 配置 Jaeger Exporter (OTLP)
    otlp_exporter = OTLPSpanExporter(
        endpoint="http://localhost:4318/v1/traces",
        headers={}
    )
    span_processor = BatchSpanProcessor(otlp_exporter)
    trace.get_tracer_provider().add_span_processor(span_processor)
    
    # 注意：Metrics 使用 prometheus_client 直接暴露，而不是 OpenTelemetry
    # 这样可以简化配置，同时保持追踪功能完整
    
    # 自动注入 HTTP 客户端追踪
    HTTPXClientInstrumentor().instrument()
    RequestsInstrumentor().instrument()
    
    logger.info(f"OpenTelemetry initialized for service: {service_name}")
    return tracer


def instrument_fastapi(app, service_name: str):
    """为 FastAPI 应用添加自动追踪和 Prometheus metrics 端点"""
    FastAPIInstrumentor.instrument_app(app)
    
    # 添加 /metrics 端点用于 Prometheus 抓取
    from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
    from fastapi.responses import Response
    
    @app.get("/metrics")
    async def metrics_endpoint():
        """Prometheus metrics 端点"""
        return Response(
            content=generate_latest(),
            media_type=CONTENT_TYPE_LATEST
        )
    
    logger.info(f"FastAPI instrumented: {service_name}")

