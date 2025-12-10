#!/bin/bash
# Level 1 完整安装脚本
# 安装所有 Level 1 功能：高级自动扩缩容 + Service Mesh

set -e

echo "🚀 Installing Level 1 Complete Features..."
echo "   - Advanced Autoscaling (Prometheus HPA, VPA, KEDA)"
echo "   - Service Mesh (Istio with mTLS and Canary)"
echo ""

# 检查前置条件
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "❌ helm is not installed"
    exit 1
fi

# 1. 安装高级自动扩缩容
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Step 1: Installing Advanced Autoscaling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./scripts/install-advanced-autoscaling.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Step 2: Installing Istio Service Mesh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
./scripts/install-istio.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Level 1 Complete Installation Finished!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Verify all components:"
echo "   # Autoscaling"
echo "   kubectl get hpa -n microservices"
echo "   kubectl get vpa -n microservices"
echo "   kubectl get scaledobject -n microservices"
echo ""
echo "   # Service Mesh"
echo "   kubectl get pods -n istio-system"
echo "   kubectl get peerauthentication -n microservices"
echo "   kubectl get destinationrule -n microservices"
echo "   kubectl get virtualservice -n microservices"
echo ""
echo "📚 Next steps:"
echo "   - Read docs/LEVEL1_COMPLETE.md for usage guide"
echo "   - Test canary deployment: ./scripts/canary-deployment.sh user-service"
echo ""




