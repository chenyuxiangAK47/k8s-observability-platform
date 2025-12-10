#!/bin/bash
# 金丝雀发布脚本
# 逐步将流量从旧版本切换到新版本

set -e

SERVICE_NAME=${1:-user-service}
NAMESPACE=${2:-microservices}
V1_WEIGHT=${3:-90}
V2_WEIGHT=${4:-10}

echo "🚀 Starting Canary Deployment for $SERVICE_NAME"
echo "   V1 Weight: ${V1_WEIGHT}%"
echo "   V2 Weight: ${V2_WEIGHT}%"

# 更新 VirtualService
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ${SERVICE_NAME}-canary
  namespace: ${NAMESPACE}
spec:
  hosts:
  - ${SERVICE_NAME}
  http:
  - route:
    - destination:
        host: ${SERVICE_NAME}
        subset: v2
      weight: ${V2_WEIGHT}
    - destination:
        host: ${SERVICE_NAME}
        subset: v1
      weight: ${V1_WEIGHT}
EOF

echo "✅ Canary deployment updated"
echo ""
echo "📊 Check traffic distribution:"
echo "   kubectl get virtualservice ${SERVICE_NAME}-canary -n ${NAMESPACE} -o yaml"
echo ""
echo "💡 To increase v2 traffic, run:"
echo "   ./scripts/canary-deployment.sh ${SERVICE_NAME} ${NAMESPACE} 50 50  # 50/50 split"
echo "   ./scripts/canary-deployment.sh ${SERVICE_NAME} ${NAMESPACE} 0 100  # 100% v2"




