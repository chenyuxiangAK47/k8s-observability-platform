# Quick Deploy to EKS - Fast Setup and Teardown
# This script quickly deploys services to EKS and provides cleanup commands

Write-Host "🚀 Quick Deploy to EKS" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Check kubectl connection
Write-Host "`n📋 Step 1: Checking kubectl connection..." -ForegroundColor Blue
$kubectlCheck = kubectl cluster-info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ kubectl not connected. Run: aws eks update-kubeconfig --region us-east-1 --name observability-platform" -ForegroundColor Red
    exit 1
}
Write-Host "✅ kubectl connected" -ForegroundColor Green

# Create namespaces
Write-Host "`n📋 Step 2: Creating namespaces..." -ForegroundColor Blue
kubectl create namespace microservices --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
Write-Host "✅ Namespaces created" -ForegroundColor Green

# Deploy PostgreSQL
Write-Host "`n📋 Step 3: Deploying PostgreSQL..." -ForegroundColor Blue
$postgresYaml = @"
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
"@
$postgresYaml | kubectl apply -f -
Write-Host "✅ PostgreSQL deployed" -ForegroundColor Green

# Wait for PostgreSQL
Write-Host "`n⏳ Waiting for PostgreSQL to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=postgresql -n microservices --timeout=120s

# Deploy RabbitMQ
Write-Host "`n📋 Step 4: Deploying RabbitMQ..." -ForegroundColor Blue
$rabbitmqYaml = @"
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
"@
$rabbitmqYaml | kubectl apply -f -
Write-Host "✅ RabbitMQ deployed" -ForegroundColor Green

# Deploy microservices using Helm
Write-Host "`n📋 Step 5: Deploying microservices with Helm..." -ForegroundColor Blue
$imageRegistry = "324025606388.dkr.ecr.us-east-1.amazonaws.com"

# Check if Helm chart exists
if (Test-Path "helm/microservices") {
    helm upgrade --install microservices ./helm/microservices `
        --namespace microservices `
        --set global.imageRegistry=$imageRegistry `
        --set database.host=postgresql.microservices.svc.cluster.local `
        --set database.password=postgres `
        --create-namespace
    Write-Host "✅ Microservices deployed with Helm" -ForegroundColor Green
} else {
    Write-Host "⚠️  Helm chart not found, skipping microservices deployment" -ForegroundColor Yellow
}

Write-Host "`n✅ Quick Deploy Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`n📊 Check status:" -ForegroundColor Cyan
Write-Host "  kubectl get pods -n microservices" -ForegroundColor White
Write-Host "`n🗑️  To delete everything and save costs:" -ForegroundColor Yellow
Write-Host "  .\scripts\quick-destroy-eks.ps1" -ForegroundColor White
Write-Host "  OR" -ForegroundColor White
Write-Host "  terraform destroy -auto-approve" -ForegroundColor White

