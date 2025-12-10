# Quick Destroy EKS Resources - Save Costs Immediately
# This script quickly deletes all resources to stop AWS charges

Write-Host "🗑️  Quick Destroy EKS Resources" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host "⚠️  WARNING: This will delete ALL resources!" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Type 'DELETE' to confirm"
if ($confirm -ne "DELETE") {
    Write-Host "❌ Cancelled" -ForegroundColor Red
    exit 0
}

Write-Host "`n📋 Step 1: Deleting Kubernetes resources..." -ForegroundColor Blue
kubectl delete namespace microservices --ignore-not-found=true
kubectl delete namespace observability --ignore-not-found=true
Write-Host "✅ Kubernetes resources deleted" -ForegroundColor Green

Write-Host "`n📋 Step 2: Destroying Terraform resources..." -ForegroundColor Blue
Set-Location terraform/eks
terraform destroy -auto-approve
Set-Location ../..

Write-Host "`n✅ All resources destroyed!" -ForegroundColor Green
Write-Host "💰 AWS charges will stop immediately" -ForegroundColor Green
Write-Host "`n📊 Verify deletion:" -ForegroundColor Cyan
Write-Host "  aws eks list-clusters --region us-east-1" -ForegroundColor White

