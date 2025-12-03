# Build Docker Images Script (Windows PowerShell)

$ErrorActionPreference = "Stop"

# Configuration
$IMAGE_TAG = if ($env:IMAGE_TAG) { $env:IMAGE_TAG } else { "latest" }
$KIND_CLUSTER_NAME = if ($env:KIND_CLUSTER_NAME) { $env:KIND_CLUSTER_NAME } else { "monitoring-learning" }

Write-Host "Starting Docker image build..." -ForegroundColor Green

# Check if Docker is running
try {
    docker info | Out-Null
} catch {
    Write-Host "Error: Docker is not running" -ForegroundColor Red
    exit 1
}

# Build user-service
Write-Host "Building user-service..." -ForegroundColor Yellow
Set-Location services/user-service
docker build -t "user-service:$IMAGE_TAG" .
Write-Host "user-service build completed" -ForegroundColor Green
Set-Location ../..

# Build product-service
Write-Host "Building product-service..." -ForegroundColor Yellow
Set-Location services/product-service
docker build -t "product-service:$IMAGE_TAG" .
Write-Host "product-service build completed" -ForegroundColor Green
Set-Location ../..

# Build order-service
Write-Host "Building order-service..." -ForegroundColor Yellow
Set-Location services/order-service
docker build -t "order-service:$IMAGE_TAG" .
Write-Host "order-service build completed" -ForegroundColor Green
Set-Location ../..

# Load images into Kind cluster
Write-Host "Loading images into Kind cluster..." -ForegroundColor Yellow

# Check if Kind cluster exists
$clusters = kind get clusters 2>$null
if ($clusters -notcontains $KIND_CLUSTER_NAME) {
    Write-Host "Warning: Kind cluster '$KIND_CLUSTER_NAME' not found" -ForegroundColor Yellow
    Write-Host "Please create the cluster first: kind create cluster --name $KIND_CLUSTER_NAME" -ForegroundColor Yellow
    exit 1
}

Write-Host "Loading user-service image..." -ForegroundColor Cyan
kind load docker-image "user-service:$IMAGE_TAG" --name $KIND_CLUSTER_NAME

Write-Host "Loading product-service image..." -ForegroundColor Cyan
kind load docker-image "product-service:$IMAGE_TAG" --name $KIND_CLUSTER_NAME

Write-Host "Loading order-service image..." -ForegroundColor Cyan
kind load docker-image "order-service:$IMAGE_TAG" --name $KIND_CLUSTER_NAME

Write-Host "`nAll images loaded successfully!" -ForegroundColor Green
Write-Host "`nImage list:" -ForegroundColor Green
docker images | Select-String "user-service|product-service|order-service"

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Restart deployments to use new images:" -ForegroundColor White
Write-Host "   kubectl rollout restart deployment -n microservices user-service product-service order-service" -ForegroundColor Yellow
Write-Host "`n2. Wait for pods to be ready:" -ForegroundColor White
Write-Host "   kubectl get pods -n microservices -w" -ForegroundColor Yellow
