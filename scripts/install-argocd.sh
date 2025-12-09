#!/bin/bash

# Install ArgoCD on Kubernetes Cluster (Linux/Mac)
# This script installs ArgoCD and sets up GitOps for the observability platform

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Installing ArgoCD for GitOps deployment...${NC}"

# Check prerequisites
echo -e "\n${YELLOW}📋 Step 1: Checking prerequisites...${NC}"

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ $1 is installed${NC}"
}

check_command kubectl

# Check if cluster is accessible
echo -e "\n${YELLOW}🔍 Checking cluster connectivity...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    echo -e "${YELLOW}Please ensure your cluster is running and kubectl is configured${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Cluster is accessible${NC}"

# Create ArgoCD namespace
echo -e "\n${YELLOW}📦 Step 2: Creating ArgoCD namespace...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✅ Namespace created${NC}"

# Install ArgoCD
echo -e "\n${YELLOW}📥 Step 3: Installing ArgoCD...${NC}"
echo -e "${CYAN}This may take 3-5 minutes...${NC}"

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -e "${GREEN}✅ ArgoCD installation started${NC}"

# Wait for ArgoCD to be ready
echo -e "\n${YELLOW}⏳ Step 4: Waiting for ArgoCD to be ready...${NC}"
echo -e "${CYAN}This may take 3-5 minutes...${NC}"

kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd || {
    echo -e "${YELLOW}⚠️ ArgoCD is taking longer than expected. Please check manually:${NC}"
    echo -e "${CYAN}kubectl get pods -n argocd${NC}"
}

echo -e "${GREEN}✅ ArgoCD is ready!${NC}"

# Get ArgoCD admin password
echo -e "\n${YELLOW}🔑 Step 5: Getting ArgoCD admin password...${NC}"

PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null)
if [ -n "$PASSWORD" ]; then
    DECODED_PASSWORD=$(echo $PASSWORD | base64 -d)
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}ArgoCD Admin Credentials${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${NC}Username: admin${NC}"
    echo -e "${NC}Password: $DECODED_PASSWORD${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "\n${YELLOW}💾 Save this password! You'll need it to access ArgoCD UI${NC}"
else
    echo -e "${YELLOW}⚠️ Could not retrieve password. It may not be ready yet.${NC}"
    echo -e "${CYAN}Try again in a few minutes with:${NC}"
    echo -e "${CYAN}kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d${NC}"
fi

# Deploy ArgoCD Applications
echo -e "\n${YELLOW}📋 Step 6: Deploying ArgoCD Applications...${NC}"

if [ -f "gitops/apps/microservices-app.yaml" ]; then
    echo -e "${CYAN}Applying microservices application...${NC}"
    kubectl apply -f gitops/apps/microservices-app.yaml
    echo -e "${GREEN}✅ Microservices application created${NC}"
else
    echo -e "${YELLOW}⚠️ gitops/apps/microservices-app.yaml not found, skipping...${NC}"
fi

if [ -f "gitops/apps/observability-app.yaml" ]; then
    echo -e "${CYAN}Applying observability application...${NC}"
    kubectl apply -f gitops/apps/observability-app.yaml
    echo -e "${GREEN}✅ Observability application created${NC}"
else
    echo -e "${YELLOW}⚠️ gitops/apps/observability-app.yaml not found, skipping...${NC}"
fi

# Port forwarding instructions
echo -e "\n${YELLOW}🌐 Step 7: Access ArgoCD UI${NC}"
echo -e "\n${CYAN}To access ArgoCD UI, run this command in a separate terminal:${NC}"
echo -e "${NC}kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
echo -e "\n${CYAN}Then open: https://localhost:8080${NC}"
echo -e "${CYAN}Username: admin${NC}"
echo -e "${CYAN}Password: (use the password shown above)${NC}"

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ ArgoCD Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "${NC}1. Access ArgoCD UI (see instructions above)${NC}"
echo -e "${NC}2. Check application status: kubectl get applications -n argocd${NC}"
echo -e "${NC}3. View application details: kubectl get application microservices -n argocd -o yaml${NC}"
echo -e "\n${CYAN}For more information, see: gitops/README.md${NC}"
