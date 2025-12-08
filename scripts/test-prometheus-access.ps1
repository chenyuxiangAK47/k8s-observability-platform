# Test Prometheus Access Script

Write-Host "🔍 Testing Prometheus Access..." -ForegroundColor Cyan
Write-Host ""

# Method 1: Through Service
Write-Host "Method 1: Port-forward through Service" -ForegroundColor Yellow
Write-Host "Command: kubectl port-forward -n monitoring svc/prometheus-operator-kube-p-prometheus 9090:9090" -ForegroundColor White
Write-Host ""

# Method 2: Direct to Pod
Write-Host "Method 2: Port-forward directly to Pod (if Method 1 doesn't work)" -ForegroundColor Yellow
$prometheusPod = kubectl get pod -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>&1
if ($prometheusPod -and $prometheusPod -ne "") {
    Write-Host "Prometheus Pod: $prometheusPod" -ForegroundColor Green
    Write-Host "Command: kubectl port-forward -n monitoring $prometheusPod 9090:9090" -ForegroundColor White
} else {
    Write-Host "Could not find Prometheus pod" -ForegroundColor Red
}
Write-Host ""

# Check service status
Write-Host "Checking Service Status..." -ForegroundColor Cyan
kubectl get svc -n monitoring prometheus-operator-kube-p-prometheus
Write-Host ""

# Check pod status
Write-Host "Checking Pod Status..." -ForegroundColor Cyan
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
Write-Host ""

# Check endpoints
Write-Host "Checking Endpoints..." -ForegroundColor Cyan
kubectl get endpoints -n monitoring prometheus-operator-kube-p-prometheus
Write-Host ""

Write-Host "💡 If port-forward doesn't work, try:" -ForegroundColor Yellow
Write-Host "   1. Check if port 9090 is already in use: netstat -ano | findstr :9090" -ForegroundColor White
Write-Host "   2. Try a different local port: kubectl port-forward -n monitoring svc/prometheus-operator-kube-p-prometheus 9091:9090" -ForegroundColor White
Write-Host "   3. Use direct pod forwarding (Method 2 above)" -ForegroundColor White

