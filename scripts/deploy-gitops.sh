#!/bin/bash
# 部署 GitOps Applications 脚本

set -e

echo "🚀 Deploying GitOps Applications..."

# 检查 kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    exit 1
fi

# 检查 ArgoCD 是否运行
if ! kubectl get namespace argocd &> /dev/null; then
    echo "❌ ArgoCD namespace not found. Please install ArgoCD first:"
    echo "   ./scripts/install-argocd.sh"
    exit 1
fi

# 部署 Applications
echo "📦 Deploying microservices application..."
kubectl apply -f gitops/apps/microservices-app.yaml

echo "📦 Deploying observability platform application..."
kubectl apply -f gitops/apps/observability-app.yaml

# 等待 Applications 创建
echo "⏳ Waiting for applications to be created..."
sleep 5

# 显示状态
echo ""
echo "✅ Applications deployed!"
echo ""
echo "📊 Application status:"
kubectl get applications -n argocd

echo ""
echo "📝 To view detailed status:"
echo "   kubectl get application microservices -n argocd -o yaml"
echo ""
echo "📝 To sync manually (if needed):"
echo "   argocd app sync microservices"
echo "   argocd app sync observability-platform"
echo ""





