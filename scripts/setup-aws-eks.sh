#!/bin/bash
# Setup AWS EKS Cluster (Bash version for AWS CloudShell)
# This script guides you through setting up AWS EKS using Terraform

set -e

echo ""
echo "=== AWS EKS 集群设置 ==="
echo ""

# Step 1: Check prerequisites
echo "📋 Step 1: Checking prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found"
    exit 1
else
    echo "✅ AWS CLI installed: $(aws --version)"
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found"
    echo "   Install: https://www.terraform.io/downloads"
    exit 1
else
    echo "✅ Terraform installed: $(terraform --version | head -n1)"
fi

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found"
    echo "   Install: https://kubernetes.io/docs/tasks/tools/"
    exit 1
else
    echo "✅ kubectl installed: $(kubectl version --client --short)"
fi

# Step 2: Check AWS credentials
echo ""
echo "📋 Step 2: Checking AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    echo "✅ AWS credentials configured"
    IDENTITY=$(aws sts get-caller-identity)
    echo "   Account: $(echo $IDENTITY | jq -r '.Account')"
    echo "   User/Role: $(echo $IDENTITY | jq -r '.Arn')"
else
    echo "❌ AWS credentials not configured"
    exit 1
fi

# Step 3: Get AWS region
echo ""
echo "📋 Step 3: Getting AWS region..."
REGION=$(aws configure get region || echo "us-east-1")
echo "✅ AWS region: $REGION"

# Step 4: Initialize Terraform
echo ""
echo "📋 Step 4: Initializing Terraform..."
cd terraform/eks

if [ ! -d ".terraform" ]; then
    echo "Running: terraform init"
    terraform init
    if [ $? -ne 0 ]; then
        echo "❌ Terraform init failed"
        exit 1
    fi
    echo "✅ Terraform initialized"
else
    echo "✅ Terraform already initialized"
fi

# Step 5: Show plan
echo ""
echo "📋 Step 5: Showing Terraform plan..."
echo "This will show what resources will be created."
echo "Review the plan carefully!"
echo ""
read -p "Press Enter to continue..."

terraform plan

# Step 6: Confirm apply
echo ""
echo "📋 Step 6: Apply Terraform configuration?"
echo "This will create:"
echo "  - VPC with subnets"
echo "  - EKS Cluster"
echo "  - EC2 Node Group (2x t3.medium)"
echo "  - ECR Repositories (3 repositories)"
echo "  - IAM Roles and Policies"
echo ""
echo "Estimated cost: ~$200/month"
echo "Estimated time: 15-20 minutes"
echo ""

read -p "Do you want to proceed? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# Step 7: Apply Terraform
echo ""
echo "📋 Step 7: Applying Terraform configuration..."
echo "This will take 15-20 minutes. Please wait..."

terraform apply -auto-approve

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ EKS cluster created successfully!"
    
    # Step 8: Configure kubectl
    echo ""
    echo "📋 Step 8: Configuring kubectl..."
    CONFIGURE_CMD=$(terraform output -raw configure_kubectl)
    eval $CONFIGURE_CMD
    
    # Step 9: Verify cluster
    echo ""
    echo "📋 Step 9: Verifying cluster..."
    sleep 10
    kubectl get nodes
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Cluster is ready!"
        
        # Show outputs
        echo ""
        echo "📊 Cluster Information:"
        terraform output
        
        echo ""
        echo "📝 Next Steps:"
        echo "1. Deploy applications using Helm"
        echo "2. Configure ArgoCD for GitOps"
        echo ""
        echo "See docs/AWS_MIGRATION_GUIDE.md for details"
    else
        echo "⚠️  Cluster created but nodes may still be joining"
        echo "   Wait a few minutes and run: kubectl get nodes"
    fi
else
    echo ""
    echo "❌ Terraform apply failed"
    echo "Check the error messages above"
fi

cd ../..

echo ""
echo "✅ Setup script completed!"

