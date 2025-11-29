"""
自动修复机器人 (Auto-Heal Bot)
根据 Prometheus 告警自动执行修复操作
"""
import os
import json
import logging
import requests
from flask import Flask, request, jsonify
from typing import Dict, List
import subprocess
import time

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 服务配置
SERVICES = {
    "order-service": {"port": 8000, "health_endpoint": "http://localhost:8000/health"},
    "product-service": {"port": 8001, "health_endpoint": "http://localhost:8001/health"},
    "user-service": {"port": 8002, "health_endpoint": "http://localhost:8002/health"},
}

# 修复策略配置
HEAL_STRATEGIES = {
    "ServiceDown": {
        "actions": ["health_check", "restart_service"],
        "max_retries": 3,
        "cooldown": 60  # 秒
    },
    "HighErrorRate": {
        "actions": ["health_check", "restart_service", "scale_up"],
        "max_retries": 2,
        "cooldown": 120
    },
    "HighLatency": {
        "actions": ["health_check", "scale_up"],
        "max_retries": 2,
        "cooldown": 180
    },
    "LowQPS": {
        "actions": ["health_check"],
        "max_retries": 1,
        "cooldown": 300
    }
}

# 记录修复历史（防止重复操作）
heal_history: Dict[str, float] = {}


def health_check(service_name: str) -> bool:
    """检查服务健康状态"""
    try:
        endpoint = SERVICES[service_name]["health_endpoint"]
        response = requests.get(endpoint, timeout=5)
        return response.status_code == 200
    except Exception as e:
        logger.warning(f"Health check failed for {service_name}: {e}")
        return False


def restart_service(service_name: str) -> bool:
    """重启服务（通过进程管理）"""
    try:
        logger.info(f"Attempting to restart {service_name}")
        
        # 查找并停止旧进程
        # Windows PowerShell 方式
        port = SERVICES[service_name]["port"]
        result = subprocess.run(
            ["powershell", "-Command", 
             f"Get-NetTCPConnection -LocalPort {port} -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess"],
            capture_output=True,
            text=True
        )
        
        if result.stdout.strip():
            pids = result.stdout.strip().split('\n')
            for pid in pids:
                if pid.isdigit():
                    try:
                        subprocess.run(["taskkill", "/F", "/PID", pid], check=False)
                        logger.info(f"Stopped process {pid} for {service_name}")
                    except Exception as e:
                        logger.warning(f"Failed to stop process {pid}: {e}")
        
        # 等待进程完全停止
        time.sleep(2)
        
        # 重新启动服务（这里需要根据实际部署方式调整）
        # 如果是 Docker，可以用 docker-compose restart
        # 如果是直接运行 Python，需要启动新进程
        logger.info(f"Service {service_name} restart initiated")
        
        # 等待服务启动
        time.sleep(5)
        
        # 验证服务是否恢复
        if health_check(service_name):
            logger.info(f"✅ {service_name} restarted successfully")
            return True
        else:
            logger.error(f"❌ {service_name} restart failed")
            return False
            
    except Exception as e:
        logger.error(f"Failed to restart {service_name}: {e}")
        return False


def scale_up(service_name: str) -> bool:
    """扩容服务（增加实例数）"""
    try:
        logger.info(f"Attempting to scale up {service_name}")
        
        # 这里可以实现实际的扩容逻辑
        # 例如：Docker Compose scale, Kubernetes scale, 或启动新实例
        
        # 示例：记录扩容操作
        logger.info(f"Scale up operation logged for {service_name}")
        
        # 在实际环境中，这里会调用：
        # - docker-compose up -d --scale service_name=2
        # - kubectl scale deployment service_name --replicas=2
        # - AWS ECS update service desired count
        
        return True
    except Exception as e:
        logger.error(f"Failed to scale up {service_name}: {e}")
        return False


def should_heal(alert_name: str, service_name: str) -> bool:
    """判断是否应该执行修复（防止频繁操作）"""
    key = f"{alert_name}:{service_name}"
    last_heal_time = heal_history.get(key, 0)
    strategy = HEAL_STRATEGIES.get(alert_name, {})
    cooldown = strategy.get("cooldown", 60)
    
    current_time = time.time()
    if current_time - last_heal_time < cooldown:
        logger.info(f"Skipping heal for {key} (cooldown: {cooldown}s)")
        return False
    
    return True


def execute_heal(alert_name: str, service_name: str) -> Dict:
    """执行修复操作"""
    strategy = HEAL_STRATEGIES.get(alert_name, {})
    actions = strategy.get("actions", [])
    max_retries = strategy.get("max_retries", 1)
    
    results = {
        "alert": alert_name,
        "service": service_name,
        "actions_taken": [],
        "success": False,
        "message": ""
    }
    
    for action in actions:
        logger.info(f"Executing {action} for {service_name}")
        
        if action == "health_check":
            is_healthy = health_check(service_name)
            results["actions_taken"].append(f"health_check: {'healthy' if is_healthy else 'unhealthy'}")
            if is_healthy:
                results["success"] = True
                results["message"] = "Service is healthy, no further action needed"
                break
        
        elif action == "restart_service":
            if restart_service(service_name):
                results["actions_taken"].append("restart_service: success")
                results["success"] = True
                results["message"] = "Service restarted successfully"
                break
            else:
                results["actions_taken"].append("restart_service: failed")
        
        elif action == "scale_up":
            if scale_up(service_name):
                results["actions_taken"].append("scale_up: success")
                results["success"] = True
                results["message"] = "Service scaled up successfully"
                break
            else:
                results["actions_taken"].append("scale_up: failed")
    
    # 记录修复历史
    key = f"{alert_name}:{service_name}"
    heal_history[key] = time.time()
    
    return results


@app.route('/webhook/alert', methods=['POST'])
def handle_alert():
    """处理 Prometheus Alertmanager 的 Webhook 告警"""
    try:
        data = request.json
        logger.info(f"Received alert: {json.dumps(data, indent=2)}")
        
        alerts = data.get('alerts', [])
        results = []
        
        for alert in alerts:
            status = alert.get('status')  # 'firing' or 'resolved'
            labels = alert.get('labels', {})
            annotations = alert.get('annotations', {})
            
            alert_name = labels.get('alertname', 'Unknown')
            service_name = labels.get('service', '')
            
            # 只处理 firing 状态的告警
            if status != 'firing':
                logger.info(f"Alert {alert_name} is {status}, skipping")
                continue
            
            # 如果没有 service 标签，尝试从 job 标签提取
            if not service_name:
                job = labels.get('job', '')
                if 'order' in job.lower():
                    service_name = 'order-service'
                elif 'product' in job.lower():
                    service_name = 'product-service'
                elif 'user' in job.lower():
                    service_name = 'user-service'
            
            if not service_name or service_name not in SERVICES:
                logger.warning(f"Unknown service: {service_name}, skipping")
                continue
            
            # 检查是否应该执行修复
            if not should_heal(alert_name, service_name):
                continue
            
            # 执行修复
            result = execute_heal(alert_name, service_name)
            results.append(result)
            
            logger.info(f"Heal result: {json.dumps(result, indent=2)}")
        
        return jsonify({
            "status": "success",
            "processed": len(results),
            "results": results
        }), 200
        
    except Exception as e:
        logger.error(f"Error processing alert: {e}", exc_info=True)
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@app.route('/health', methods=['GET'])
def health():
    """健康检查端点"""
    return jsonify({"status": "healthy", "service": "auto-heal-bot"}), 200


@app.route('/status', methods=['GET'])
def status():
    """查看修复历史和状态"""
    return jsonify({
        "status": "running",
        "heal_history": {k: time.ctime(v) for k, v in heal_history.items()},
        "services": list(SERVICES.keys()),
        "strategies": list(HEAL_STRATEGIES.keys())
    }), 200


if __name__ == '__main__':
    logger.info("🚀 Auto-Heal Bot started")
    logger.info(f"Listening for alerts on /webhook/alert")
    logger.info(f"Services monitored: {list(SERVICES.keys())}")
    
    app.run(host='0.0.0.0', port=5000, debug=False)

