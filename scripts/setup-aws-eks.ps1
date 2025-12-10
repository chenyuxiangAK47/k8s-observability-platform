# Setup AWS EKS Cluster
# This script guides you through setting up AWS EKS using Terraform

Write-Host "`n=== AWS EKS 集群设置 ===" -ForegroundColor Cyan

# Step 1: Check prerequisites
Write-Host "`n📋 Step 1: Checking prerequisites..." -ForegroundColor Yellow

# Check AWS CLI
$awsCli = Get-Command aws -ErrorAction SilentlyContinue
if (-not $awsCli) {
    Write-Host "❌ AWS CLI not found" -ForegroundColor Red
    Write-Host "   Install: choco install awscli" -ForegroundColor Gray
    exit 1
} else {
    Write-Host "✅ AWS CLI installed: $($awsCli.Version)" -ForegroundColor Green
}

# Check Terraform
$terraform = Get-Command terraform -ErrorAction SilentlyContinue
if (-not $terraform) {
    Write-Host "❌ Terraform not found" -ForegroundColor Red
    Write-Host "   Install: choco install terraform" -ForegroundColor Gray
    exit 1
} else {
    Write-Host "✅ Terraform installed" -ForegroundColor Green
}

# Check kubectl
$kubectl = Get-Command kubectl -ErrorAction SilentlyContinue
if (-not $kubectl) {
    Write-Host "❌ kubectl not found" -ForegroundColor Red
    Write-Host "   Install: choco install kubernetes-cli" -ForegroundColor Gray
    exit 1
} else {
    Write-Host "✅ kubectl installed" -ForegroundColor Green
}

# Step 2: Check AWS credentials
Write-Host "`n📋 Step 2: Checking AWS credentials..." -ForegroundColor Yellow
$awsIdentity = aws sts get-caller-identity 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ AWS credentials configured" -ForegroundColor Green
    $identity = $awsIdentity | ConvertFrom-Json
    Write-Host "   Account: $($identity.Account)" -ForegroundColor Gray
    Write-Host "   User/Role: $($identity.Arn)" -ForegroundColor Gray
} else {
    Write-Host "❌ AWS credentials not configured" -ForegroundColor Red
    Write-Host "   Run: aws configure" -ForegroundColor Gray
    Write-Host "   You need:" -ForegroundColor Yellow
    Write-Host "   - AWS Access Key ID" -ForegroundColor Gray
    Write-Host "   - AWS Secret Access Key" -ForegroundColor Gray
    Write-Host "   - Default region (e.g., us-east-1)" -ForegroundColor Gray
    exit 1
}

# Step 3: Get AWS region
Write-Host "`n📋 Step 3: Getting AWS region..." -ForegroundColor Yellow
$region = aws configure get region
if ($region) {
    Write-Host "✅ AWS region: $region" -ForegroundColor Green
} else {
    Write-Host "⚠️  No default region set" -ForegroundColor Yellow
    $region = Read-Host "Enter AWS region (e.g., us-east-1)"
    aws configure set region $region
}

# Step 4: Initialize Terraform
Write-Host "`n📋 Step 4: Initializing Terraform..." -ForegroundColor Yellow
Push-Location terraform/eks

if (-not (Test-Path ".terraform")) {
    Write-Host "Running: terraform init" -ForegroundColor Gray
    terraform init
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform init failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Write-Host "✅ Terraform initialized" -ForegroundColor Green
} else {
    Write-Host "✅ Terraform already initialized" -ForegroundColor Green
}

# Step 5: Show plan
Write-Host "`n📋 Step 5: Showing Terraform plan..." -ForegroundColor Yellow
Write-Host "This will show what resources will be created." -ForegroundColor Gray
Write-Host "Review the plan carefully!" -ForegroundColor Yellow
Write-Host "`nPress Enter to continue..." -ForegroundColor Cyan
Read-Host

terraform plan

# Step 6: Confirm apply
Write-Host "`n📋 Step 6: Apply Terraform configuration?" -ForegroundColor Yellow
Write-Host "This will create:" -ForegroundColor Cyan
Write-Host "  - VPC with subnets" -ForegroundColor Gray
Write-Host "  - EKS Cluster" -ForegroundColor Gray
Write-Host "  - EC2 Node Group (2x t3.medium)" -ForegroundColor Gray
Write-Host "  - ECR Repositories (3 repositories)" -ForegroundColor Gray
Write-Host "  - IAM Roles and Policies" -ForegroundColor Gray
Write-Host "`nEstimated cost: ~$200/month" -ForegroundColor Yellow
Write-Host "Estimated time: 15-20 minutes" -ForegroundColor Yellow

$confirm = Read-Host "`nDo you want to proceed? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    Pop-Location
    exit 0
}

# Step 7: Apply Terraform
Write-Host "`n📋 Step 7: Applying Terraform configuration..." -ForegroundColor Yellow
Write-Host "This will take 15-20 minutes. Please wait..." -ForegroundColor Gray

terraform apply -auto-approve

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ EKS cluster created successfully!" -ForegroundColor Green
    
    # Step 8: Configure kubectl
    Write-Host "`n📋 Step 8: Configuring kubectl..." -ForegroundColor Yellow
    $configureCmd = terraform output -raw configure_kubectl
    Invoke-Expression $configureCmd
    
    # Step 9: Verify cluster
    Write-Host "`n📋 Step 9: Verifying cluster..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    kubectl get nodes
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Cluster is ready!" -ForegroundColor Green
        
        # Show outputs
        Write-Host "`n📊 Cluster Information:" -ForegroundColor Cyan
        terraform output
        
        Write-Host "`n📝 Next Steps:" -ForegroundColor Yellow
        Write-Host "1. Update GitHub Actions to push to ECR" -ForegroundColor Gray
        Write-Host "2. Deploy applications using Helm" -ForegroundColor Gray
        Write-Host "3. Configure ArgoCD for GitOps" -ForegroundColor Gray
        Write-Host "`nSee docs/AWS_MIGRATION_GUIDE.md for details" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️  Cluster created but nodes may still be joining" -ForegroundColor Yellow
        Write-Host "   Wait a few minutes and run: kubectl get nodes" -ForegroundColor Gray
    }
} else {
    Write-Host "`n❌ Terraform apply failed" -ForegroundColor Red
    Write-Host "Check the error messages above" -ForegroundColor Yellow
}

Pop-Location

Write-Host "`n✅ Setup script completed!" -ForegroundColor Green

