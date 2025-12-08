#!/bin/bash
# 安装 Istio Service Mesh

set -e

echo "🚀 Installing Istio Service Mesh..."

# 检查 kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    exit 1
fi

# 检查 istioctl
if ! command -v istioctl &> /dev/null; then
    echo "📥 Installing istioctl..."
    
    # 下载 Istio
    ISTIO_VERSION="1.20.0"
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
    
    # 添加到 PATH
    export PATH="$PWD/istio-$ISTIO_VERSION/bin:$PATH"
    
    echo "✅ istioctl installed"
else
    echo "✅ istioctl already installed"
fi

# 安装 Istio
echo "📦 Installing Istio..."
istioctl install --set profile=default -y

# 等待 Istio 就绪
echo "⏳ Waiting for Istio to be ready..."
kubectl wait --for=condition=ready pod -l app=istiod -n istio-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=istio-ingressgateway -n istio-system --timeout=300s

# 启用命名空间自动注入
echo "📝 Enabling sidecar auto-injection for microservices namespace..."
kubectl label namespace microservices istio-injection=enabled --overwrite

# 应用 Istio 配置
echo "📝 Applying Istio configurations..."
kubectl apply -f k8s/service-mesh/mtls-policy.yaml
kubectl apply -f k8s/service-mesh/destination-rules.yaml
kubectl apply -f k8s/service-mesh/virtual-services.yaml
kubectl apply -f k8s/service-mesh/gateway.yaml

echo ""
echo "✅ Istio installed successfully!"
echo ""
echo "📊 Verify installation:"
echo "   kubectl get pods -n istio-system"
echo "   kubectl get peerauthentication -n microservices"
echo "   kubectl get destinationrule -n microservices"
echo "   kubectl get virtualservice -n microservices"
echo ""
echo "🌐 Access services via Istio Gateway:"
echo "   kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80"
echo "   curl http://localhost:8080/api/users/health"
echo ""

