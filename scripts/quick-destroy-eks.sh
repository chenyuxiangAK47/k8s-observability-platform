#!/bin/bash
# Quick Destroy EKS Resources - Save Costs Immediately

echo "🗑️  Quick Destroy EKS Resources"
echo "========================================"
echo "⚠️  WARNING: This will delete ALL resources!"
echo ""

read -p "Type 'DELETE' to confirm: " confirm
if [ "$confirm" != "DELETE" ]; then
    echo "❌ Cancelled"
    exit 0
fi

echo ""
echo "📋 Step 1: Deleting Kubernetes resources..."
kubectl delete namespace microservices --ignore-not-found=true
kubectl delete namespace observability --ignore-not-found=true
echo "✅ Kubernetes resources deleted"

echo ""
echo "📋 Step 2: Destroying Terraform resources..."
cd terraform/eks
terraform destroy -auto-approve
cd ../..

echo ""
echo "✅ All resources destroyed!"
echo "💰 AWS charges will stop immediately"
echo ""
echo "📊 Verify deletion:"
echo "  aws eks list-clusters --region us-east-1"

