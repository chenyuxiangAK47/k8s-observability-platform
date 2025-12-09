# Quick Fix Cluster Connection (Windows PowerShell)
# This script checks Docker, restarts cluster if needed, and verifies connection

$ErrorActionPreference = "Continue"

Write-Host "🔧 Quick Fix: Checking cluster connection..." -ForegroundColor Blue

# Step 1: Check Docker
Write-Host "`n📋 Step 1: Checking Docker Desktop..." -ForegroundColor Yellow

$dockerRunning = $false
try {
    $null = docker ps 2>&1
    if ($LASTEXITCODE -eq 0) {
        $dockerRunning = $true
        Write-Host "✅ Docker Desktop is running" -ForegroundColor Green
    }
} catch {
    $dockerRunning = $false
}

if (-not $dockerRunning) {
    Write-Host "❌ Docker Desktop is NOT running!" -ForegroundColor Red
    Write-Host "`n📝 Please do the following:" -ForegroundColor Yellow
    Write-Host "1. Open Docker Desktop application" -ForegroundColor White
    Write-Host "2. Wait for Docker to fully start (whale icon in system tray)" -ForegroundColor White
    Write-Host "3. Run this script again: .\scripts\quick-fix-cluster.ps1" -ForegroundColor White
    Write-Host "`nOr run: .\scripts\setup-and-deploy.ps1 (will recreate cluster)" -ForegroundColor Cyan
    exit 1
}

# Step 2: Check Kind cluster
Write-Host "`n📋 Step 2: Checking Kind cluster..." -ForegroundColor Yellow

$clusters = kind get clusters 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Cannot list clusters. Checking if cluster container exists..." -ForegroundColor Yellow
    
    # Check if kind container exists
    $kindContainer = docker ps -a --filter "name=observability-platform" --format "{{.Names}}" 2>&1
    if ($kindContainer -match "observability-platform") {
        Write-Host "Found cluster container, checking status..." -ForegroundColor Cyan
        
        $containerStatus = docker ps --filter "name=observability-platform" --format "{{.Status}}" 2>&1
        if ($containerStatus -match "Up") {
            Write-Host "✅ Cluster container is running" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Cluster container exists but is not running" -ForegroundColor Yellow
            Write-Host "Starting cluster container..." -ForegroundColor Cyan
            docker start observability-platform-control-plane 2>&1 | Out-Null
            Start-Sleep -Seconds 5
        }
    } else {
        Write-Host "❌ Cluster does not exist!" -ForegroundColor Red
        Write-Host "`n📝 You need to recreate the cluster:" -ForegroundColor Yellow
        Write-Host ".\scripts\setup-and-deploy.ps1" -ForegroundColor Cyan
        exit 1
    }
} else {
    $clusterName = "observability-platform"
    if ($clusters -match $clusterName) {
        Write-Host "✅ Cluster '$clusterName' exists" -ForegroundColor Green
    } else {
        Write-Host "❌ Cluster '$clusterName' not found" -ForegroundColor Red
        Write-Host "`n📝 You need to create the cluster:" -ForegroundColor Yellow
        Write-Host ".\scripts\setup-and-deploy.ps1" -ForegroundColor Cyan
        exit 1
    }
}

# Step 3: Verify kubectl connection
Write-Host "`n📋 Step 3: Verifying kubectl connection..." -ForegroundColor Yellow

$maxAttempts = 10
$attempt = 0
$connected = $false

while ($attempt -lt $maxAttempts -and -not $connected) {
    $clusterInfo = kubectl cluster-info --context kind-observability-platform 2>&1
    if ($LASTEXITCODE -eq 0) {
        $connected = $true
        Write-Host "✅ Successfully connected to cluster!" -ForegroundColor Green
    } else {
        $attempt++
        Write-Host "Waiting for API server... ($attempt/$maxAttempts)" -ForegroundColor Cyan
        Start-Sleep -Seconds 3
    }
}

if (-not $connected) {
    Write-Host "❌ Cannot connect to cluster API server" -ForegroundColor Red
    Write-Host "`n📝 Try these steps:" -ForegroundColor Yellow
    Write-Host "1. Restart Docker Desktop" -ForegroundColor White
    Write-Host "2. Wait 1-2 minutes for Docker to fully start" -ForegroundColor White
    Write-Host "3. Run: .\scripts\setup-and-deploy.ps1 (will recreate cluster)" -ForegroundColor Cyan
    exit 1
}

# Step 4: Check cluster nodes
Write-Host "`n📋 Step 4: Checking cluster nodes..." -ForegroundColor Yellow

$nodes = kubectl get nodes 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Cluster nodes:" -ForegroundColor Green
    Write-Host $nodes -ForegroundColor White
} else {
    Write-Host "⚠️ Cannot get nodes, but connection seems OK" -ForegroundColor Yellow
}

# Summary
Write-Host "`n" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ Cluster Connection Fixed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nYou can now run kubectl commands:" -ForegroundColor Yellow
Write-Host "kubectl get pods -A" -ForegroundColor White
Write-Host "kubectl get nodes" -ForegroundColor White

