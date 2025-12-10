#!/bin/bash
# Quick Deploy to EKS - Fast Setup
# This script quickly deploys services to EKS

echo "🚀 Quick Deploy to EKS"
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
kubectl wait --for=condition=ready pod -l app=postgresql -n microservices --timeout=120s

# Deploy RabbitMQ
echo ""
echo "📋 Step 4: Deploying RabbitMQ..."
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

# Deploy microservices using Helm
echo ""
echo "📋 Step 5: Deploying microservices with Helm..."
IMAGE_REGISTRY="324025606388.dkr.ecr.us-east-1.amazonaws.com"

if [ -d "helm/microservices" ]; then
    helm upgrade --install microservices ./helm/microservices \
        --namespace microservices \
        --set global.imageRegistry=$IMAGE_REGISTRY \
        --set database.host=postgresql.microservices.svc.cluster.local \
        --set database.password=postgres \
        --create-namespace
    echo "✅ Microservices deployed with Helm"
else
    echo "⚠️  Helm chart not found, skipping microservices deployment"
fi

echo ""
echo "✅ Quick Deploy Complete!"
echo "========================================"
echo ""
echo "📊 Check status:"
echo "  kubectl get pods -n microservices"
echo ""
echo "🗑️  To delete everything and save costs:"
echo "  ./scripts/quick-destroy-eks.sh"
echo "  OR"
echo "  cd terraform/eks && terraform destroy -auto-approve"

