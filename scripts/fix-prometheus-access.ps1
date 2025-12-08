# Fix Prometheus Access - Multiple Methods

Write-Host "🔧 Prometheus Access Fix Guide" -ForegroundColor Cyan
Write-Host ""

# Check if port is in use
Write-Host "Step 1: Checking if port 9090 is available..." -ForegroundColor Yellow
$portCheck = netstat -ano | findstr :9090
if ($portCheck) {
    Write-Host "⚠️  Port 9090 is already in use:" -ForegroundColor Yellow
    Write-Host $portCheck -ForegroundColor Gray
    Write-Host ""
    Write-Host "Solution: Use a different local port (e.g., 9091)" -ForegroundColor Cyan
    Write-Host "   kubectl port-forward -n monitoring svc/prometheus-operator-kube-p-prometheus 9091:9090" -ForegroundColor White
    Write-Host "   Then access: http://localhost:9091" -ForegroundColor Gray
} else {
    Write-Host "✅ Port 9090 is available" -ForegroundColor Green
}
Write-Host ""

# Method 1: Service port-forward
Write-Host "Method 1: Port-forward through Service" -ForegroundColor Yellow
Write-Host "Run this command in a new terminal:" -ForegroundColor White
Write-Host "   kubectl port-forward -n monitoring svc/prometheus-operator-kube-p-prometheus 9090:9090" -ForegroundColor Cyan
Write-Host ""

# Method 2: Direct Pod port-forward (More reliable)
Write-Host "Method 2: Port-forward directly to Pod (Recommended if Method 1 fails)" -ForegroundColor Yellow
$pod = kubectl get pod -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>&1
if ($pod -and $pod -ne "") {
    Write-Host "Prometheus Pod found: $pod" -ForegroundColor Green
    Write-Host "Run this command in a new terminal:" -ForegroundColor White
    Write-Host "   kubectl port-forward -n monitoring $pod 9090:9090" -ForegroundColor Cyan
} else {
    Write-Host "❌ Could not find Prometheus pod" -ForegroundColor Red
}
Write-Host ""

# Method 3: Alternative port
Write-Host "Method 3: Use alternative local port (if 9090 is busy)" -ForegroundColor Yellow
Write-Host "   kubectl port-forward -n monitoring svc/prometheus-operator-kube-p-prometheus 9091:9090" -ForegroundColor Cyan
Write-Host "   Then access: http://localhost:9091" -ForegroundColor Gray
Write-Host ""

# Verify service
Write-Host "Current Prometheus Status:" -ForegroundColor Cyan
kubectl get svc -n monitoring prometheus-operator-kube-p-prometheus
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
Write-Host ""

Write-Host "💡 Tips:" -ForegroundColor Yellow
Write-Host "   - Keep the terminal window open while port-forwarding" -ForegroundColor White
Write-Host "   - Press Ctrl+C to stop port-forwarding" -ForegroundColor White
Write-Host "   - If connection drops, restart the port-forward command" -ForegroundColor White

