#!/bin/bash
# 安装高级自动扩缩容组件（Prometheus Adapter, VPA, KEDA）

set -e

echo "🚀 Installing Advanced Autoscaling Components..."

# 检查 kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    exit 1
fi

# 1. 安装 Prometheus Adapter
echo "📦 Installing Prometheus Adapter..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install prometheus-adapter prometheus-community/prometheus-adapter \
  --namespace kube-system \
  --set prometheus.url=http://prometheus.observability.svc.cluster.local \
  --set prometheus.port=9090 \
  --set logLevel=4 \
  --wait

echo "✅ Prometheus Adapter installed"

# 2. 安装 VPA
echo "📦 Installing VPA (Vertical Pod Autoscaler)..."
git clone --depth 1 --branch vpa-release-0.14 https://github.com/kubernetes/autoscaler.git /tmp/vpa 2>/dev/null || true

if [ -d "/tmp/vpa/vertical-pod-autoscaler" ]; then
    kubectl apply -f /tmp/vpa/vertical-pod-autoscaler/hack/vpa-process-yaml.sh
    echo "✅ VPA installed"
else
    echo "⚠️  VPA installation skipped (requires manual installation)"
    echo "   See: https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler"
fi

# 3. 安装 KEDA
echo "📦 Installing KEDA..."
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm upgrade --install keda kedacore/keda \
  --namespace kube-system \
  --wait

echo "✅ KEDA installed"

# 4. 应用配置
echo "📝 Applying autoscaling configurations..."
kubectl apply -f k8s/autoscaling/prometheus-adapter.yaml || true
kubectl apply -f k8s/autoscaling/prometheus-metrics-hpa.yaml || true
kubectl apply -f k8s/autoscaling/vpa.yaml || true
kubectl apply -f k8s/autoscaling/keda-redis-scaler.yaml || true

echo ""
echo "✅ Advanced Autoscaling Components installed!"
echo ""
echo "📊 Verify installation:"
echo "   kubectl get pods -n kube-system | grep -E 'prometheus-adapter|vpa|keda'"
echo "   kubectl get hpa -n microservices"
echo "   kubectl get vpa -n microservices"
echo "   kubectl get scaledobject -n microservices"
echo ""

