"""
结构化日志配置
支持 TraceID 关联
"""
import json
import logging
import sys
from datetime import datetime
from opentelemetry import trace


class JSONFormatter(logging.Formatter):
    """JSON 格式的日志格式化器"""
    
    def format(self, record):
        # 获取当前 TraceID
        span = trace.get_current_span()
        trace_id = None
        if span and span.get_span_context().is_valid:
            trace_id = format(span.get_span_context().trace_id, '032x')
        
        log_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "service": getattr(record, 'service', 'unknown'),
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }
        
        # 添加 TraceID（如果存在）
        if trace_id:
            log_data["trace_id"] = trace_id
        
        # 添加异常信息（如果存在）
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        
        # 添加额外字段
        if hasattr(record, 'extra_fields'):
            log_data.update(record.extra_fields)
        
        return json.dumps(log_data)


def setup_logger(service_name: str, log_level: str = "INFO"):
    """
    配置结构化日志
    
    Args:
        service_name: 服务名称
        log_level: 日志级别
    """
    logger = logging.getLogger(service_name)
    logger.setLevel(getattr(logging, log_level.upper()))
    
    # 移除默认处理器
    logger.handlers.clear()
    
    # 控制台输出（JSON 格式）
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(JSONFormatter())
    logger.addHandler(console_handler)
    
    # 文件输出（用于 Promtail 采集）
    file_handler = logging.FileHandler(f'logs/{service_name}.log')
    file_handler.setFormatter(JSONFormatter())
    logger.addHandler(file_handler)
    
    # 添加服务名称到日志记录
    old_factory = logging.getLogRecordFactory()
    
    def record_factory(*args, **kwargs):
        record = old_factory(*args, **kwargs)
        record.service = service_name
        return record
    
    logging.setLogRecordFactory(record_factory)
    
    return logger


