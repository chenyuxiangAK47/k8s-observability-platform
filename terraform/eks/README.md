# EKS Terraform Configuration

This directory contains Terraform configuration to create a complete EKS cluster on AWS.

## 📋 Prerequisites

1. **AWS Account**
   - Create an AWS account if you don't have one
   - Get AWS Access Key ID and Secret Access Key

2. **AWS CLI**
   ```powershell
   choco install awscli
   # or download from https://aws.amazon.com/cli/
   ```

3. **Configure AWS Credentials**
   ```powershell
   aws configure
   # Enter Access Key ID
   # Enter Secret Access Key
   # Choose region (e.g., us-east-1)
   # Choose output format (json)
   ```

4. **Terraform**
   ```powershell
   choco install terraform
   # or download from https://www.terraform.io/downloads
   ```

5. **kubectl**
   ```powershell
   choco install kubernetes-cli
   ```

## 🚀 Quick Start

### Step 1: Initialize Terraform

```powershell
cd terraform/eks
terraform init
```

### Step 2: Review Plan

```powershell
terraform plan
```

This will show you what resources will be created:
- VPC with public/private subnets
- EKS Cluster
- EKS Node Group (2x t3.medium instances)
- ECR Repositories (3 repositories)
- IAM Roles and Policies
- Security Groups

### Step 3: Apply Configuration

```powershell
terraform apply
```

Type `yes` when prompted. This will take **15-20 minutes** to create all resources.

### Step 4: Configure kubectl

After Terraform completes, run the command shown in the output:

```powershell
aws eks update-kubeconfig --region us-east-1 --name observability-platform
```

Or use the output from Terraform:

```powershell
terraform output configure_kubectl
# Then run the command it shows
```

### Step 5: Verify Cluster

```powershell
kubectl get nodes
kubectl get pods -A
```

## 📊 Created Resources

### Networking
- VPC (10.0.0.0/16)
- 2 Public Subnets (for ALB)
- 2 Private Subnets (for EKS nodes)
- Internet Gateway
- 2 NAT Gateways
- Route Tables

### EKS
- EKS Cluster (control plane)
- Node Group (2x t3.medium instances)
- IAM Roles (cluster and node)

### ECR
- user-service repository
- product-service repository
- order-service repository

### Monitoring
- CloudWatch Log Group for EKS

## 💰 Cost Estimate

| Resource | Monthly Cost |
|----------|-------------|
| EKS Control Plane | ~$72 |
| EC2 Nodes (2x t3.medium) | ~$60 |
| NAT Gateways (2x) | ~$65 |
| ECR | Free (first 500MB) |
| CloudWatch | ~$5-10 |
| **Total** | **~$200-210/month** |

**Note:** You can reduce costs by:
- Using Fargate instead of EC2 nodes
- Using single NAT Gateway
- Stopping the cluster when not in use

## 🔧 Customization

Edit `variables.tf` to customize:
- AWS region
- Cluster name
- Node instance type
- Number of nodes
- VPC CIDR

## 🗑️ Destroy Resources

To delete all resources (saves money):

```powershell
terraform destroy
```

Type `yes` when prompted.

## 📝 Next Steps

After creating the EKS cluster:

1. **Update GitHub Actions** to push images to ECR
2. **Deploy applications** using Helm or kubectl
3. **Configure ArgoCD** for GitOps
4. **Set up monitoring** (Prometheus + Grafana)

See `../../docs/AWS_MIGRATION_GUIDE.md` for complete migration steps.

## 🆘 Troubleshooting

### Error: "Unable to locate credentials"

```powershell
aws configure
```

### Error: "Region not found"

Make sure you're using a valid AWS region (e.g., us-east-1, us-west-2).

### Error: "Insufficient permissions"

Your AWS user needs these permissions:
- AmazonEKSClusterPolicy
- AmazonEKSWorkerNodePolicy
- AmazonEC2FullAccess (for VPC, subnets, etc.)
- AmazonEC2ContainerRegistryFullAccess (for ECR)

### Cluster creation takes too long

EKS cluster creation typically takes 15-20 minutes. This is normal.

### Nodes not joining cluster

Check node group status:
```powershell
aws eks describe-nodegroup --cluster-name observability-platform --nodegroup-name observability-platform-nodes
```

