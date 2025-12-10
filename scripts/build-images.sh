#!/bin/bash

# 构建 Docker 镜像脚本
# 
# 为什么需要这个脚本？
# 1. 自动化构建流程
# 2. 统一镜像标签
# 3. 便于 CI/CD 集成

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 配置
IMAGE_TAG=${IMAGE_TAG:-"latest"}
KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-"observability-platform"}

echo -e "${GREEN}🐳 开始构建 Docker 镜像...${NC}"

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}错误: Docker 未运行${NC}"
    exit 1
fi

# 构建 user-service
echo -e "${YELLOW}构建 user-service...${NC}"
cd services/user-service
docker build -t user-service:${IMAGE_TAG} .
echo -e "${GREEN}✅ user-service 构建完成${NC}"
cd ../..

# 构建 product-service
echo -e "${YELLOW}构建 product-service...${NC}"
cd services/product-service
docker build -t product-service:${IMAGE_TAG} .
echo -e "${GREEN}✅ product-service 构建完成${NC}"
cd ../..

# 构建 order-service
echo -e "${YELLOW}构建 order-service...${NC}"
cd services/order-service
docker build -t order-service:${IMAGE_TAG} .
echo -e "${GREEN}✅ order-service 构建完成${NC}"
cd ../..

echo -e "${GREEN}✅ 所有镜像构建完成！${NC}"

# 如果是 kind 集群，加载镜像
if command -v kind &> /dev/null; then
    if kind get clusters | grep -q "^${KIND_CLUSTER_NAME}$"; then
        echo -e "${YELLOW}加载镜像到 kind 集群...${NC}"
        kind load docker-image user-service:${IMAGE_TAG} --name ${KIND_CLUSTER_NAME}
        kind load docker-image product-service:${IMAGE_TAG} --name ${KIND_CLUSTER_NAME}
        kind load docker-image order-service:${IMAGE_TAG} --name ${KIND_CLUSTER_NAME}
        echo -e "${GREEN}✅ 镜像已加载到 kind 集群${NC}"
    else
        echo -e "${YELLOW}警告: kind 集群 ${KIND_CLUSTER_NAME} 不存在，跳过镜像加载${NC}"
    fi
else
    echo -e "${YELLOW}提示: kind 未安装，跳过镜像加载${NC}"
fi

echo -e "${GREEN}📦 镜像列表:${NC}"
docker images | grep -E "(user-service|product-service|order-service)"
















