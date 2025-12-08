#!/bin/bash
# 安装 ArgoCD 脚本

set -e

echo "🚀 Installing ArgoCD..."

# 检查 kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    exit 1
fi

# 创建命名空间
echo "📦 Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# 安装 ArgoCD
echo "📥 Installing ArgoCD manifests..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 等待 ArgoCD 就绪
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd || true
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd || true
kubectl wait --for=condition=available --timeout=300s deployment/argocd-application-controller -n argocd || true

# 获取初始密码
echo ""
echo "🔑 ArgoCD Initial Admin Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

# 显示访问信息
echo "✅ ArgoCD installed successfully!"
echo ""
echo "📝 To access ArgoCD UI:"
echo "   1. Port forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   2. Open browser: https://localhost:8080"
echo "   3. Username: admin"
echo "   4. Password: (see above)"
echo ""
echo "📝 To install ArgoCD CLI:"
echo "   - macOS: brew install argocd"
echo "   - Linux: curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
echo "   - Windows: Download from https://github.com/argoproj/argo-cd/releases"
echo ""


