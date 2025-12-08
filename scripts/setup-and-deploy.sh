#!/bin/bash

# 完整的设置和部署脚本
# 
# 这个脚本做了什么？
# 1. 检查前置条件
# 2. 创建 Kubernetes 集群
# 3. 构建 Docker 镜像
# 4. 部署所有组件
# 5. 验证部署

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

CLUSTER_NAME="observability-platform"

echo -e "${BLUE}🚀 开始完整的设置和部署流程...${NC}"

# ==================== 步骤 1: 检查前置条件 ====================
echo -e "${YELLOW}📋 步骤 1: 检查前置条件...${NC}"

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}错误: $1 未安装${NC}"
        echo -e "请安装 $1 后重试"
        exit 1
    fi
    echo -e "${GREEN}✅ $1 已安装${NC}"
}

check_command docker
check_command kubectl
check_command helm
check_command kind

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}错误: Docker 未运行${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker 正在运行${NC}"

# ==================== 步骤 2: 创建 Kubernetes 集群 ====================
echo -e "${YELLOW}📦 步骤 2: 创建 Kubernetes 集群...${NC}"

if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${YELLOW}集群 ${CLUSTER_NAME} 已存在，跳过创建${NC}"
else
    echo -e "${BLUE}创建 kind 集群: ${CLUSTER_NAME}...${NC}"
    kind create cluster --name ${CLUSTER_NAME}
    echo -e "${GREEN}✅ 集群创建完成${NC}"
fi

# 设置 kubectl context
kubectl cluster-info --context kind-${CLUSTER_NAME}

# ==================== 步骤 3: 构建 Docker 镜像 ====================
echo -e "${YELLOW}🐳 步骤 3: 构建 Docker 镜像...${NC}"

chmod +x scripts/build-images.sh
./scripts/build-images.sh

# ==================== 步骤 4: 部署基础设施 ====================
echo -e "${YELLOW}🏗️  步骤 4: 部署基础设施...${NC}"

# 创建命名空间
echo -e "${BLUE}创建命名空间...${NC}"
kubectl apply -f k8s/namespaces/

# 安装 Prometheus Operator
echo -e "${BLUE}安装 Prometheus Operator...${NC}"
if helm list -n monitoring | grep -q prometheus-operator; then
    echo -e "${YELLOW}Prometheus Operator 已安装，跳过...${NC}"
else
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm install prometheus-operator prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set grafana.adminPassword=admin \
        --wait
    
    echo -e "${GREEN}✅ Prometheus Operator 安装完成${NC}"
fi

# 部署数据库和消息队列
echo -e "${BLUE}部署数据库和消息队列...${NC}"
kubectl apply -f k8s/database/postgresql.yaml
kubectl apply -f k8s/messaging/rabbitmq.yaml

echo -e "${BLUE}等待数据库和消息队列就绪...${NC}"
kubectl wait --for=condition=ready pod -l app=postgresql -n microservices --timeout=300s || true
kubectl wait --for=condition=ready pod -l app=rabbitmq -n microservices --timeout=300s || true

# 创建 Secrets
echo -e "${BLUE}创建 Secrets...${NC}"
if ! kubectl get secret database-secrets -n microservices &> /dev/null; then
    kubectl create secret generic database-secrets \
        --from-literal=user-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/users_db" \
        --from-literal=product-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/products_db" \
        --from-literal=order-db-url="postgresql://user:password@postgresql.microservices.svc.cluster.local:5432/orders_db" \
        -n microservices
fi

if ! kubectl get secret rabbitmq-secrets -n microservices &> /dev/null; then
    kubectl create secret generic rabbitmq-secrets \
        --from-literal=url="amqp://guest:guest@rabbitmq.microservices.svc.cluster.local:5672/" \
        -n microservices
fi

# ==================== 步骤 5: 部署可观测性平台 ====================
echo -e "${YELLOW}📊 步骤 5: 部署可观测性平台...${NC}"

helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

cd helm/observability-platform
helm dependency update
cd ../..

if helm list -n observability | grep -q observability-platform; then
    echo -e "${YELLOW}可观测性平台已安装，跳过...${NC}"
else
    helm install observability-platform ./helm/observability-platform \
        --namespace observability \
        --create-namespace \
        --wait || true
fi

# ==================== 步骤 6: 部署微服务 ====================
echo -e "${YELLOW}🚀 步骤 6: 部署微服务...${NC}"

if helm list -n microservices | grep -q microservices; then
    echo -e "${YELLOW}微服务已安装，跳过...${NC}"
else
    helm install microservices ./helm/microservices \
        --namespace microservices \
        --create-namespace \
        --wait || true
fi

# ==================== 步骤 7: 配置监控和自动扩缩容 ====================
echo -e "${YELLOW}📈 步骤 7: 配置监控和自动扩缩容...${NC}"

kubectl apply -f k8s/monitoring/
kubectl apply -f k8s/autoscaling/

# ==================== 步骤 8: 验证部署 ====================
echo -e "${YELLOW}✅ 步骤 8: 验证部署...${NC}"

echo -e "${BLUE}检查 Pod 状态...${NC}"
kubectl get pods -A

echo -e "${BLUE}等待所有 Pod 就绪...${NC}"
sleep 10

# 检查关键 Pod
echo -e "${BLUE}检查关键服务...${NC}"
kubectl get pods -n microservices
kubectl get pods -n observability
kubectl get pods -n monitoring

echo -e "${GREEN}✅ 部署完成！${NC}"
echo ""
echo -e "${BLUE}📊 访问服务:${NC}"
echo -e "  Grafana:     kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80"
echo -e "  Prometheus:  kubectl port-forward -n monitoring svc/prometheus-operator-kube-prom-prometheus 9090:9090"
echo -e "  Jaeger:      kubectl port-forward -n observability svc/jaeger-query 16686:16686"
echo ""
echo -e "${BLUE}🔍 测试微服务:${NC}"
echo -e "  User Service:    kubectl port-forward -n microservices svc/user-service 8001:8001"
echo -e "  Product Service: kubectl port-forward -n microservices svc/product-service 8002:8002"
echo -e "  Order Service:   kubectl port-forward -n microservices svc/order-service 8003:8003"













