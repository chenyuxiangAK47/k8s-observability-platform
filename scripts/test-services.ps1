# Quick test script to verify services are accessible

Write-Host "🧪 Testing microservices..." -ForegroundColor Cyan
Write-Host ""

# Test user-service
Write-Host "Testing user-service..." -ForegroundColor Yellow
$userService = kubectl get svc user-service -n microservices -o jsonpath='{.spec.clusterIP}' 2>&1
if ($userService -and $userService -ne "") {
    Write-Host "✅ user-service is available at: $userService:8001" -ForegroundColor Green
} else {
    Write-Host "❌ user-service not found" -ForegroundColor Red
}

# Test product-service
Write-Host "Testing product-service..." -ForegroundColor Yellow
$productService = kubectl get svc product-service -n microservices -o jsonpath='{.spec.clusterIP}' 2>&1
if ($productService -and $productService -ne "") {
    Write-Host "✅ product-service is available at: $productService:8002" -ForegroundColor Green
} else {
    Write-Host "❌ product-service not found" -ForegroundColor Red
}

# Test order-service
Write-Host "Testing order-service..." -ForegroundColor Yellow
$orderService = kubectl get svc order-service -n microservices -o jsonpath='{.spec.clusterIP}' 2>&1
if ($orderService -and $orderService -ne "") {
    Write-Host "✅ order-service is available at: $orderService:8003" -ForegroundColor Green
} else {
    Write-Host "❌ order-service not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "📊 Current Pod Status:" -ForegroundColor Cyan
kubectl get pods -n microservices -o wide | Select-String "user-service|product-service|order-service" | Select-String "1/1"

Write-Host ""
Write-Host "🚀 To access services, run in separate terminals:" -ForegroundColor Cyan
Write-Host "   kubectl port-forward -n microservices svc/user-service 8001:8001" -ForegroundColor White
Write-Host "   kubectl port-forward -n microservices svc/product-service 8002:8002" -ForegroundColor White
Write-Host "   kubectl port-forward -n microservices svc/order-service 8003:8003" -ForegroundColor White
Write-Host ""
Write-Host "📊 To access observability:" -ForegroundColor Cyan
Write-Host "   Grafana:     kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80" -ForegroundColor White
Write-Host "   Prometheus:  kubectl port-forward -n monitoring svc/prometheus-operator-kube-p-prometheus 9090:9090" -ForegroundColor White
Write-Host "   Jaeger:      kubectl port-forward -n observability svc/observability-platform-jaeger-query 16686:80" -ForegroundColor White
Write-Host "                (Then access: http://localhost:16686)" -ForegroundColor Gray

