#!/bin/bash
# Deploy Everything to EKS: Microservices + ArgoCD + Test CI/CD
# This script does everything in one go

set -e

echo "🚀 Deploying Everything to EKS"
echo "========================================"

# Check kubectl connection
echo ""
echo "📋 Step 1: Checking kubectl connection..."
if ! kubectl cluster-info &>/dev/null; then
    echo "❌ kubectl not connected. Run: aws eks update-kubeconfig --region us-east-1 --name observability-platform"
    exit 1
fi
echo "✅ kubectl connected"

# Create namespaces
echo ""
echo "📋 Step 2: Creating namespaces..."
kubectl create namespace microservices --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespaces created"

# Deploy PostgreSQL
echo ""
echo "📋 Step 3: Deploying PostgreSQL..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
  namespace: microservices
spec:
  serviceName: postgresql
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:15-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: postgres
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: microservices
spec:
  selector:
    app: postgresql
  ports:
  - port: 5432
    targetPort: 5432
EOF
echo "✅ PostgreSQL deployed"

# Wait for PostgreSQL
echo ""
echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql -n microservices --timeout=120s || true

# Create databases
echo ""
echo "📋 Step 4: Creating databases..."
kubectl exec -n microservices -it $(kubectl get pod -n microservices -l app=postgresql -o jsonpath='{.items[0].metadata.name}') -- \
  psql -U postgres -c "CREATE DATABASE users_db;" 2>/dev/null || echo "Database may already exist"
kubectl exec -n microservices -it $(kubectl get pod -n microservices -l app=postgresql -o jsonpath='{.items[0].metadata.name}') -- \
  psql -U postgres -c "CREATE DATABASE products_db;" 2>/dev/null || echo "Database may already exist"
kubectl exec -n microservices -it $(kubectl get pod -n microservices -l app=postgresql -o jsonpath='{.items[0].metadata.name}') -- \
  psql -U postgres -c "CREATE DATABASE orders_db;" 2>/dev/null || echo "Database may already exist"
echo "✅ Databases created"

# Deploy RabbitMQ
echo ""
echo "📋 Step 5: Deploying RabbitMQ..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
  namespace: microservices
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
      - name: rabbitmq
        image: rabbitmq:3-management-alpine
        ports:
        - containerPort: 5672
        - containerPort: 15672
        env:
        - name: RABBITMQ_DEFAULT_USER
          value: admin
        - name: RABBITMQ_DEFAULT_PASS
          value: admin
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
  namespace: microservices
spec:
  selector:
    app: rabbitmq
  ports:
  - port: 5672
    targetPort: 5672
  - port: 15672
    targetPort: 15672
EOF
echo "✅ RabbitMQ deployed"

# Install ArgoCD
echo ""
echo "📋 Step 6: Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "✅ ArgoCD installation started"

# Wait for ArgoCD to be ready
echo ""
echo "⏳ Waiting for ArgoCD to be ready (this may take 2-3 minutes)..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s || echo "ArgoCD still starting..."

# Get ArgoCD admin password
echo ""
echo "📋 Step 7: Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "password-not-ready")
echo "========================================"
echo "ArgoCD Admin Credentials"
echo "========================================"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo "========================================"
echo ""
echo "To access ArgoCD UI, run:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then open: https://localhost:8080"
echo ""

# Deploy microservices using Helm (if chart exists)
echo ""
echo "📋 Step 8: Deploying microservices with Helm..."
IMAGE_REGISTRY="324025606388.dkr.ecr.us-east-1.amazonaws.com"

if [ -d "helm/microservices" ]; then
    # Check if images exist in ECR, if not use latest tags
    helm upgrade --install microservices ./helm/microservices \
        --namespace microservices \
        --set global.imageRegistry=$IMAGE_REGISTRY \
        --set database.host=postgresql.microservices.svc.cluster.local \
        --set database.password=postgres \
        --set userService.image.tag=latest \
        --set productService.image.tag=latest \
        --set orderService.image.tag=latest \
        --create-namespace \
        --timeout 5m
    echo "✅ Microservices deployed with Helm"
else
    echo "⚠️  Helm chart not found, skipping microservices deployment"
fi

# Create ArgoCD Applications
echo ""
echo "📋 Step 9: Creating ArgoCD Applications..."
if [ -f "gitops/apps/microservices-app.yaml" ]; then
    kubectl apply -f gitops/apps/microservices-app.yaml
    echo "✅ Microservices ArgoCD application created"
fi

if [ -f "gitops/apps/observability-app.yaml" ]; then
    kubectl apply -f gitops/apps/observability-app.yaml
    echo "✅ Observability ArgoCD application created"
fi

# Summary
echo ""
echo "✅ Deployment Complete!"
echo "========================================"
echo ""
echo "📊 Check status:"
echo "  kubectl get pods -n microservices"
echo "  kubectl get pods -n argocd"
echo "  kubectl get applications -n argocd"
echo ""
echo "🔐 ArgoCD Access:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""
echo "🧪 Test CI/CD:"
echo "  1. Make a code change"
echo "  2. Push to GitHub"
echo "  3. GitHub Actions will build and push to ECR"
echo "  4. ArgoCD will auto-sync the new image"
echo ""
echo "🗑️  To delete everything:"
echo "  ./scripts/quick-destroy-eks.sh"

