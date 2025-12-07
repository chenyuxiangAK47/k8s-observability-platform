# 验证部署脚本 (Windows PowerShell)
# 检查所有组件是否正常运行

$ErrorActionPreference = "Continue"

Write-Host "🔍 开始验证部署..." -ForegroundColor Yellow

# 检查命名空间
Write-Host "检查命名空间..." -ForegroundColor Yellow
$namespaces = @("microservices", "observability", "monitoring")
foreach ($ns in $namespaces) {
    $nsExists = kubectl get namespace $ns 2>$null
    if ($nsExists) {
        Write-Host "✅ 命名空间 $ns 存在" -ForegroundColor Green
    } else {
        Write-Host "❌ 命名空间 $ns 不存在" -ForegroundColor Red
    }
}

# 检查 Pod 状态
Write-Host "检查 Pod 状态..." -ForegroundColor Yellow
$pods = kubectl get pods -A --no-headers 2>$null
$runningPods = $pods | Select-String "Running" | Measure-Object
$totalPods = $pods | Measure-Object
Write-Host "运行中的 Pod: $($runningPods.Count)/$($totalPods.Count)" -ForegroundColor $(if ($runningPods.Count -eq $totalPods.Count) { "Green" } else { "Yellow" })

# 检查微服务
Write-Host "检查微服务..." -ForegroundColor Yellow
$services = @("user-service", "product-service", "order-service")
foreach ($svc in $services) {
    $deployment = kubectl get deployment $svc -n microservices 2>$null
    if ($deployment) {
        $replicas = kubectl get deployment $svc -n microservices -o jsonpath='{.status.readyReplicas}' 2>$null
        $desired = kubectl get deployment $svc -n microservices -o jsonpath='{.spec.replicas}' 2>$null
        if ($replicas -eq $desired) {
            Write-Host "✅ $svc`: $replicas/$desired 副本就绪" -ForegroundColor Green
        } else {
            Write-Host "⚠️  $svc`: $replicas/$desired 副本就绪" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ $svc 部署不存在" -ForegroundColor Red
    }
}

# 检查数据库和消息队列
Write-Host "检查基础设施..." -ForegroundColor Yellow
$postgres = kubectl get pod -n microservices -l app=postgresql --field-selector=status.phase=Running 2>$null
if ($postgres) {
    Write-Host "✅ PostgreSQL 运行正常" -ForegroundColor Green
} else {
    Write-Host "❌ PostgreSQL 未运行" -ForegroundColor Red
}

$rabbitmq = kubectl get pod -n microservices -l app=rabbitmq --field-selector=status.phase=Running 2>$null
if ($rabbitmq) {
    Write-Host "✅ RabbitMQ 运行正常" -ForegroundColor Green
} else {
    Write-Host "❌ RabbitMQ 未运行" -ForegroundColor Red
}

# 检查可观测性组件
Write-Host "检查可观测性组件..." -ForegroundColor Yellow
$jaeger = kubectl get pod -n observability -l app.kubernetes.io/name=jaeger --field-selector=status.phase=Running 2>$null
if ($jaeger) {
    Write-Host "✅ Jaeger 运行正常" -ForegroundColor Green
} else {
    Write-Host "⚠️  Jaeger 可能未运行" -ForegroundColor Yellow
}

$prometheus = kubectl get pod -n monitoring -l app.kubernetes.io/name=prometheus --field-selector=status.phase=Running 2>$null
if ($prometheus) {
    Write-Host "✅ Prometheus 运行正常" -ForegroundColor Green
} else {
    Write-Host "⚠️  Prometheus 可能未运行" -ForegroundColor Yellow
}

# 检查 ServiceMonitor
Write-Host "检查 ServiceMonitor..." -ForegroundColor Yellow
$sm = kubectl get servicemonitor -n microservices microservices-metrics 2>$null
if ($sm) {
    Write-Host "✅ ServiceMonitor 已配置" -ForegroundColor Green
} else {
    Write-Host "⚠️  ServiceMonitor 未配置" -ForegroundColor Yellow
}

# 检查 HPA
Write-Host "检查 HPA..." -ForegroundColor Yellow
$hpas = kubectl get hpa -n microservices --no-headers 2>$null
if ($hpas) {
    $hpaCount = ($hpas | Measure-Object).Count
    Write-Host "✅ 找到 $hpaCount 个 HPA 配置" -ForegroundColor Green
    kubectl get hpa -n microservices
} else {
    Write-Host "⚠️  未找到 HPA 配置" -ForegroundColor Yellow
}

Write-Host "✅ 验证完成！" -ForegroundColor Green
Write-Host ""
Write-Host "📊 查看详细状态:" -ForegroundColor Yellow
Write-Host "  kubectl get pods -A"
Write-Host "  kubectl get svc -A"
Write-Host "  kubectl get hpa -A"












