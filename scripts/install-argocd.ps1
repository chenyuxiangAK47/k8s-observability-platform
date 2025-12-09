# Install ArgoCD on Kubernetes Cluster (Windows PowerShell)
# This script installs ArgoCD and sets up GitOps for the observability platform

$ErrorActionPreference = "Continue"

Write-Host "🚀 Installing ArgoCD for GitOps deployment..." -ForegroundColor Blue

# Check prerequisites
Write-Host "`n📋 Step 1: Checking prerequisites..." -ForegroundColor Yellow

function Test-Command {
    param($CommandName)
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Host "✅ $CommandName is installed" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ $CommandName is not installed" -ForegroundColor Red
        return $false
    }
}

if (-not (Test-Command "kubectl")) {
    Write-Host "Please install kubectl first" -ForegroundColor Red
    exit 1
}

# Check if cluster is accessible
Write-Host "`n🔍 Checking cluster connectivity..." -ForegroundColor Yellow
$clusterInfo = kubectl cluster-info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Cannot connect to Kubernetes cluster" -ForegroundColor Red
    Write-Host "Please ensure your cluster is running and kubectl is configured" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Cluster is accessible" -ForegroundColor Green

# Create ArgoCD namespace
Write-Host "`n📦 Step 2: Creating ArgoCD namespace..." -ForegroundColor Yellow
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
Write-Host "✅ Namespace created" -ForegroundColor Green

# Install ArgoCD
Write-Host "`n📥 Step 3: Installing ArgoCD..." -ForegroundColor Yellow
Write-Host "This may take 3-5 minutes..." -ForegroundColor Cyan

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install ArgoCD" -ForegroundColor Red
    exit 1
}

Write-Host "✅ ArgoCD installation started" -ForegroundColor Green

# Wait for ArgoCD to be ready
Write-Host "`n⏳ Step 4: Waiting for ArgoCD to be ready..." -ForegroundColor Yellow
Write-Host "This may take 3-5 minutes..." -ForegroundColor Cyan

$maxAttempts = 30
$attempt = 0
$ready = $false

while ($attempt -lt $maxAttempts -and -not $ready) {
    $status = kubectl get deployment argocd-server -n argocd -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>&1
    if ($status -eq "True") {
        $ready = $true
        Write-Host "✅ ArgoCD is ready!" -ForegroundColor Green
    } else {
        $attempt++
        Write-Host "Waiting... ($attempt/$maxAttempts)" -ForegroundColor Cyan
        Start-Sleep -Seconds 10
    }
}

if (-not $ready) {
    Write-Host "⚠️ ArgoCD is taking longer than expected. Please check manually:" -ForegroundColor Yellow
    Write-Host "kubectl get pods -n argocd" -ForegroundColor Cyan
} else {
    Write-Host "✅ ArgoCD is ready!" -ForegroundColor Green
}

# Get ArgoCD admin password
Write-Host "`n🔑 Step 5: Getting ArgoCD admin password..." -ForegroundColor Yellow

$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>&1
if ($LASTEXITCODE -eq 0 -and $password) {
    $decodedPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
    Write-Host "`n" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "ArgoCD Admin Credentials" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Username: admin" -ForegroundColor White
    Write-Host "Password: $decodedPassword" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "`n💾 Save this password! You'll need it to access ArgoCD UI" -ForegroundColor Yellow
} else {
    Write-Host "⚠️ Could not retrieve password. It may not be ready yet." -ForegroundColor Yellow
    Write-Host "Try again in a few minutes with:" -ForegroundColor Cyan
    Write-Host "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }" -ForegroundColor Cyan
}

# Deploy ArgoCD Applications
Write-Host "`n📋 Step 6: Deploying ArgoCD Applications..." -ForegroundColor Yellow

if (Test-Path "gitops/apps/microservices-app.yaml") {
    Write-Host "Applying microservices application..." -ForegroundColor Cyan
    kubectl apply -f gitops/apps/microservices-app.yaml
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Microservices application created" -ForegroundColor Green
    }
} else {
    Write-Host "⚠️ gitops/apps/microservices-app.yaml not found, skipping..." -ForegroundColor Yellow
}

if (Test-Path "gitops/apps/observability-app.yaml") {
    Write-Host "Applying observability application..." -ForegroundColor Cyan
    kubectl apply -f gitops/apps/observability-app.yaml
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Observability application created" -ForegroundColor Green
    }
} else {
    Write-Host "⚠️ gitops/apps/observability-app.yaml not found, skipping..." -ForegroundColor Yellow
}

# Port forwarding instructions
Write-Host "`n🌐 Step 7: Access ArgoCD UI" -ForegroundColor Yellow
Write-Host "`nTo access ArgoCD UI, run this command in a separate terminal:" -ForegroundColor Cyan
Write-Host "kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor White
Write-Host "`nThen open: https://localhost:8080" -ForegroundColor Cyan
Write-Host "Username: admin" -ForegroundColor Cyan
Write-Host "Password: (use the password shown above)" -ForegroundColor Cyan

# Summary
Write-Host "`n" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ ArgoCD Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Access ArgoCD UI (see instructions above)" -ForegroundColor White
Write-Host "2. Check application status: kubectl get applications -n argocd" -ForegroundColor White
Write-Host "3. View application details: kubectl get application microservices -n argocd -o yaml" -ForegroundColor White
Write-Host "`nFor more information, see: gitops/README.md" -ForegroundColor Cyan
