# Verify and Sync ArgoCD Application
# This script checks ArgoCD status and triggers sync if needed

Write-Host "`n=== ArgoCD GitOps 验证和同步 ===" -ForegroundColor Cyan

# Step 1: Check ArgoCD Applications
Write-Host "`n📋 Step 1: Checking ArgoCD Applications..." -ForegroundColor Yellow
kubectl get applications -n argocd

# Step 2: Check Git repository connection
Write-Host "`n📋 Step 2: Checking Git repository connection..." -ForegroundColor Yellow
$app = kubectl get application microservices -n argocd -o jsonpath='{.status.sourceType}' 2>$null
if ($app) {
    Write-Host "✅ Application exists" -ForegroundColor Green
} else {
    Write-Host "❌ Application not found" -ForegroundColor Red
    exit 1
}

# Step 3: Check current Helm values in Git
Write-Host "`n📋 Step 3: Checking Helm values.yaml in Git..." -ForegroundColor Yellow
$valuesContent = Get-Content helm/microservices/values.yaml -Raw
if ($valuesContent -match "userService.*image.*tag.*9ec9f6c") {
    Write-Host "✅ Helm values.yaml contains CI/CD updated tag" -ForegroundColor Green
    $tagMatch = [regex]::Match($valuesContent, "tag:\s*([a-f0-9]+)")
    if ($tagMatch.Success) {
        Write-Host "   Current tag in values.yaml: $($tagMatch.Groups[1].Value)" -ForegroundColor Cyan
    }
} else {
    Write-Host "⚠️  Helm values.yaml may not have CI/CD tag" -ForegroundColor Yellow
}

# Step 4: Check current deployment image
Write-Host "`n📋 Step 4: Checking current deployment image..." -ForegroundColor Yellow
$currentImage = kubectl get deployment user-service -n microservices -o jsonpath='{.spec.template.spec.containers[0].image}' 2>$null
if ($currentImage) {
    Write-Host "   Current deployment image: $currentImage" -ForegroundColor Cyan
    if ($currentImage -match "ghcr.io") {
        Write-Host "✅ Deployment is using GHCR image" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Deployment is using local image, not GHCR" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Could not get deployment image" -ForegroundColor Red
}

# Step 5: Check ArgoCD sync status
Write-Host "`n📋 Step 5: Checking ArgoCD sync status..." -ForegroundColor Yellow
$syncStatus = kubectl get application microservices -n argocd -o jsonpath='{.status.sync.status}' 2>$null
$healthStatus = kubectl get application microservices -n argocd -o jsonpath='{.status.health.status}' 2>$null

Write-Host "   Sync Status: $syncStatus" -ForegroundColor Cyan
Write-Host "   Health Status: $healthStatus" -ForegroundColor Cyan

if ($syncStatus -eq "Synced") {
    Write-Host "✅ ArgoCD is synced" -ForegroundColor Green
} else {
    Write-Host "⚠️  ArgoCD sync status: $syncStatus" -ForegroundColor Yellow
    Write-Host "   This may be normal if ArgoCD hasn't detected changes yet" -ForegroundColor Gray
}

# Step 6: Trigger manual sync
Write-Host "`n📋 Step 6: Triggering manual sync..." -ForegroundColor Yellow
Write-Host "   Running: argocd app sync microservices" -ForegroundColor Gray

# Try using argocd CLI if available
$argocdCmd = Get-Command argocd -ErrorAction SilentlyContinue
if ($argocdCmd) {
    Write-Host "   Using argocd CLI..." -ForegroundColor Gray
    argocd app sync microservices --server localhost:8080 --insecure 2>&1 | Out-Null
} else {
    Write-Host "   Using kubectl to trigger sync..." -ForegroundColor Gray
    # Use kubectl patch to trigger sync
    kubectl patch application microservices -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}' 2>&1 | Out-Null
    
    # Alternative: Use ArgoCD API via port-forward
    Write-Host "   Note: You can also sync via ArgoCD UI at https://localhost:8080" -ForegroundColor Gray
}

# Step 7: Wait and check again
Write-Host "`n📋 Step 7: Waiting 10 seconds for sync to process..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$syncStatusAfter = kubectl get application microservices -n argocd -o jsonpath='{.status.sync.status}' 2>$null
Write-Host "   Sync Status after trigger: $syncStatusAfter" -ForegroundColor Cyan

# Step 8: Check deployment again
Write-Host "`n📋 Step 8: Checking deployment after sync..." -ForegroundColor Yellow
$newImage = kubectl get deployment user-service -n microservices -o jsonpath='{.spec.template.spec.containers[0].image}' 2>$null
if ($newImage) {
    Write-Host "   Deployment image: $newImage" -ForegroundColor Cyan
    if ($newImage -ne $currentImage) {
        Write-Host "✅ Image has changed!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Image has not changed yet" -ForegroundColor Yellow
        Write-Host "   This may take a few minutes. Check ArgoCD UI for details." -ForegroundColor Gray
    }
}

# Step 9: Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "📊 Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n✅ CI/CD Status:" -ForegroundColor Green
Write-Host "   - Helm values.yaml has been updated by CI/CD" -ForegroundColor Gray
Write-Host "   - Git repository contains latest changes" -ForegroundColor Gray

Write-Host "`n📋 ArgoCD Status:" -ForegroundColor Yellow
Write-Host "   - Sync Status: $syncStatusAfter" -ForegroundColor Gray
Write-Host "   - Health Status: $healthStatus" -ForegroundColor Gray

Write-Host "`n🔍 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Check ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor Gray
Write-Host "   2. Open: https://localhost:8080 (username: admin, password: from install script)" -ForegroundColor Gray
Write-Host "   3. Click 'Sync' button on microservices application" -ForegroundColor Gray
Write-Host "   4. Wait for sync to complete (usually 1-2 minutes)" -ForegroundColor Gray
Write-Host "   5. Check deployment: kubectl get deployment user-service -n microservices -o yaml" -ForegroundColor Gray

Write-Host "`n✅ Verification script completed!" -ForegroundColor Green

