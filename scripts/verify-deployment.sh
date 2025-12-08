#!/bin/bash

# 验证部署脚本
# 检查所有组件是否正常运行

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔍 开始验证部署...${NC}"

# 检查命名空间
echo -e "${YELLOW}检查命名空间...${NC}"
namespaces=("microservices" "observability" "monitoring")
for ns in "${namespaces[@]}"; do
    if kubectl get namespace $ns &> /dev/null; then
        echo -e "${GREEN}✅ 命名空间 $ns 存在${NC}"
    else
        echo -e "${RED}❌ 命名空间 $ns 不存在${NC}"
        exit 1
    fi
done

# 检查 Pod 状态
echo -e "${YELLOW}检查 Pod 状态...${NC}"
failed_pods=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | grep -v "Completed" || true)
if [ -z "$failed_pods" ]; then
    echo -e "${GREEN}✅ 所有 Pod 运行正常${NC}"
else
    echo -e "${RED}❌ 以下 Pod 未正常运行:${NC}"
    echo "$failed_pods"
fi

# 检查微服务
echo -e "${YELLOW}检查微服务...${NC}"
services=("user-service" "product-service" "order-service")
for svc in "${services[@]}"; do
    if kubectl get deployment $svc -n microservices &> /dev/null; then
        replicas=$(kubectl get deployment $svc -n microservices -o jsonpath='{.status.readyReplicas}')
        desired=$(kubectl get deployment $svc -n microservices -o jsonpath='{.spec.replicas}')
        if [ "$replicas" == "$desired" ]; then
            echo -e "${GREEN}✅ $svc: $replicas/$desired 副本就绪${NC}"
        else
            echo -e "${YELLOW}⚠️  $svc: $replicas/$desired 副本就绪${NC}"
        fi
    else
        echo -e "${RED}❌ $svc 部署不存在${NC}"
    fi
done

# 检查数据库和消息队列
echo -e "${YELLOW}检查基础设施...${NC}"
if kubectl get pod -n microservices -l app=postgresql --field-selector=status.phase=Running &> /dev/null; then
    echo -e "${GREEN}✅ PostgreSQL 运行正常${NC}"
else
    echo -e "${RED}❌ PostgreSQL 未运行${NC}"
fi

if kubectl get pod -n microservices -l app=rabbitmq --field-selector=status.phase=Running &> /dev/null; then
    echo -e "${GREEN}✅ RabbitMQ 运行正常${NC}"
else
    echo -e "${RED}❌ RabbitMQ 未运行${NC}"
fi

# 检查可观测性组件
echo -e "${YELLOW}检查可观测性组件...${NC}"
if kubectl get pod -n observability -l app.kubernetes.io/name=jaeger --field-selector=status.phase=Running &> /dev/null; then
    echo -e "${GREEN}✅ Jaeger 运行正常${NC}"
else
    echo -e "${YELLOW}⚠️  Jaeger 可能未运行${NC}"
fi

if kubectl get pod -n monitoring -l app.kubernetes.io/name=prometheus --field-selector=status.phase=Running &> /dev/null; then
    echo -e "${GREEN}✅ Prometheus 运行正常${NC}"
else
    echo -e "${YELLOW}⚠️  Prometheus 可能未运行${NC}"
fi

# 检查 ServiceMonitor
echo -e "${YELLOW}检查 ServiceMonitor...${NC}"
if kubectl get servicemonitor -n microservices microservices-metrics &> /dev/null; then
    echo -e "${GREEN}✅ ServiceMonitor 已配置${NC}"
else
    echo -e "${YELLOW}⚠️  ServiceMonitor 未配置${NC}"
fi

# 检查 HPA
echo -e "${YELLOW}检查 HPA...${NC}"
hpas=$(kubectl get hpa -n microservices --no-headers 2>/dev/null | wc -l)
if [ "$hpas" -gt 0 ]; then
    echo -e "${GREEN}✅ 找到 $hpas 个 HPA 配置${NC}"
    kubectl get hpa -n microservices
else
    echo -e "${YELLOW}⚠️  未找到 HPA 配置${NC}"
fi

echo -e "${GREEN}✅ 验证完成！${NC}"
echo ""
echo -e "${YELLOW}📊 查看详细状态:${NC}"
echo "  kubectl get pods -A"
echo "  kubectl get svc -A"
echo "  kubectl get hpa -A"













