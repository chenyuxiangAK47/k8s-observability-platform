#!/bin/bash

set -e

echo "🚀 开始部署云原生可观测性平台..."

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 检查必要工具
check_tool() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}错误: $1 未安装${NC}"
        exit 1
    fi
}

echo "📋 检查必要工具..."
check_tool kubectl
check_tool helm
check_tool docker

# 创建命名空间
echo -e "${GREEN}步骤 1: 创建命名空间...${NC}"
kubectl apply -f k8s/namespaces/

# 安装 Prometheus Operator
echo -e "${GREEN}步骤 2: 安装 Prometheus Operator...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

if ! helm list -n monitoring | grep -q prometheus-operator; then
    helm install prometheus-operator prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set grafana.adminPassword=admin \
        --wait
    
    echo "⏳ 等待 Prometheus Operator 就绪..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kube-prometheus-operator -n monitoring --timeout=300s
else
    echo -e "${YELLOW}Prometheus Operator 已安装，跳过...${NC}"
fi

# 添加依赖的 Helm repos
echo -e "${GREEN}步骤 3: 添加 Helm repos...${NC}"
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

# 部署可观测性平台
echo -e "${GREEN}步骤 4: 部署可观测性平台...${NC}"
cd helm/observability-platform
helm dependency update
cd ../..

if ! helm list -n observability | grep -q observability-platform; then
    helm install observability-platform ./helm/observability-platform \
        --namespace observability \
        --create-namespace \
        --wait
else
    echo -e "${YELLOW}可观测性平台已安装，跳过...${NC}"
fi

# 部署数据库和消息队列
echo -e "${GREEN}步骤 5: 部署数据库和消息队列...${NC}"
kubectl apply -f k8s/database/postgresql.yaml
kubectl apply -f k8s/messaging/rabbitmq.yaml

echo "⏳ 等待数据库和消息队列就绪..."
kubectl wait --for=condition=ready pod -l app=postgresql -n microservices --timeout=300s || true
kubectl wait --for=condition=ready pod -l app=rabbitmq -n microservices --timeout=300s || true

# 创建 Secrets
echo -e "${GREEN}步骤 6: 创建 Secrets...${NC}"
if ! kubectl get secret database-secrets -n microservices &> /dev/null; then
    kubectl create secret generic database-secrets \
        --from-literal=user-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/users_db" \
        --from-literal=product-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/products_db" \
        --from-literal=order-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/orders_db" \
        -n microservices
else
    echo -e "${YELLOW}Secrets 已存在，跳过...${NC}"
fi

if ! kubectl get secret rabbitmq-secrets -n microservices &> /dev/null; then
    kubectl create secret generic rabbitmq-secrets \
        --from-literal=url="amqp://guest:guest@rabbitmq.microservices.svc.cluster.local:5672/" \
        -n microservices
else
    echo -e "${YELLOW}RabbitMQ Secrets 已存在，跳过...${NC}"
fi

# 部署微服务
echo -e "${GREEN}步骤 7: 部署微服务...${NC}"
if ! helm list -n microservices | grep -q microservices; then
    helm install microservices ./helm/microservices \
        --namespace microservices \
        --create-namespace \
        --wait
else
    echo -e "${YELLOW}微服务已安装，跳过...${NC}"
fi

# 配置监控
echo -e "${GREEN}步骤 8: 配置监控...${NC}"
kubectl apply -f k8s/monitoring/

# 配置自动扩缩容
echo -e "${GREEN}步骤 9: 配置自动扩缩容...${NC}"
kubectl apply -f k8s/autoscaling/

echo -e "${GREEN}✅ 部署完成！${NC}"
echo ""
echo "📊 访问服务:"
echo "  - Grafana: kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80"
echo "  - Prometheus: kubectl port-forward -n monitoring svc/prometheus-operator-kube-prom-prometheus 9090:9090"
echo "  - Jaeger: kubectl port-forward -n observability svc/jaeger-query 16686:16686"
echo ""
echo "🔍 检查状态:"
echo "  kubectl get pods -A"













