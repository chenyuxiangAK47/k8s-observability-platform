# Start port forwarding for all services

Write-Host "=== Starting Port Forwarding ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Starting port forwarding..." -ForegroundColor Green
Write-Host ""

# Grafana
Write-Host "1. Grafana (port 3000)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80; Write-Host 'Press any key to close...'; Read-Host" -WindowStyle Normal
Write-Host "   Grafana: http://localhost:3000" -ForegroundColor Green

Start-Sleep -Seconds 2

# Prometheus
Write-Host "`n2. Prometheus (port 9090)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n monitoring svc/prometheus-operator-kube-p-prometheus 9090:9090; Write-Host 'Press any key to close...'; Read-Host" -WindowStyle Normal
Write-Host "   Prometheus: http://localhost:9090" -ForegroundColor Green

Start-Sleep -Seconds 2

# Jaeger
Write-Host "`n3. Jaeger (port 16686)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n observability svc/observability-platform-jaeger-query 16686:16686; Write-Host 'Press any key to close...'; Read-Host" -WindowStyle Normal
Write-Host "   Jaeger: http://localhost:16686" -ForegroundColor Green

Start-Sleep -Seconds 2

# Microservices (optional)
Write-Host "`n4. Microservices port forwarding (optional)..." -ForegroundColor Cyan
$choice = Read-Host "Start microservices port forwarding? (Y/N)"
if ($choice -eq "Y" -or $choice -eq "y") {
    Write-Host "   User Service (port 8001)..." -ForegroundColor Gray
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n microservices svc/user-service 8001:8001; Write-Host 'Press any key to close...'; Read-Host" -WindowStyle Normal
    
    Start-Sleep -Seconds 1
    
    Write-Host "   Product Service (port 8002)..." -ForegroundColor Gray
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n microservices svc/product-service 8002:8002; Write-Host 'Press any key to close...'; Read-Host" -WindowStyle Normal
    
    Start-Sleep -Seconds 1
    
    Write-Host "   Order Service (port 8003)..." -ForegroundColor Gray
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n microservices svc/order-service 8003:8003; Write-Host 'Press any key to close...'; Read-Host" -WindowStyle Normal
}

Write-Host "`nPort forwarding started!" -ForegroundColor Green
Write-Host "`nAccess URLs:" -ForegroundColor Cyan
Write-Host "  Grafana: http://localhost:3000" -ForegroundColor White
Write-Host "  Prometheus: http://localhost:9090" -ForegroundColor White
Write-Host "  Jaeger: http://localhost:16686" -ForegroundColor White
Write-Host "`nTip: Each port forward runs in a separate PowerShell window" -ForegroundColor Yellow
Write-Host "Closing the window will stop the corresponding port forward" -ForegroundColor Yellow
