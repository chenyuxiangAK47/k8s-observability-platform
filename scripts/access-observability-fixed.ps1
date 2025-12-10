# Fixed Observability Access Script
# Corrected service names and ports

Write-Host "📊 Observability Platform Access Guide" -ForegroundColor Cyan
Write-Host ""

Write-Host "✅ Corrected Commands:" -ForegroundColor Green
Write-Host ""

# Grafana
Write-Host "1. Grafana (Unified Visualization - Recommended)" -ForegroundColor Yellow
Write-Host "   kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80" -ForegroundColor White
Write-Host "   Then access: http://localhost:3000" -ForegroundColor Gray
Write-Host "   Username: admin, Password: admin" -ForegroundColor Gray
Write-Host ""

# Prometheus
Write-Host "2. Prometheus (Metrics Query)" -ForegroundColor Yellow
Write-Host "   kubectl port-forward -n monitoring svc/prometheus-operator-kube-p-prometheus 9090:9090" -ForegroundColor White
Write-Host "   Then access: http://localhost:9090" -ForegroundColor Gray
Write-Host "   Note: Service name is 'prometheus-operator-kube-p-prometheus' (not 'prometheus-operator-kube-prom-prometheus')" -ForegroundColor Gray
Write-Host ""

# Jaeger
Write-Host "3. Jaeger (Distributed Tracing)" -ForegroundColor Yellow
Write-Host "   kubectl port-forward -n observability svc/observability-platform-jaeger-query 16686:80" -ForegroundColor White
Write-Host "   Then access: http://localhost:16686" -ForegroundColor Gray
Write-Host "   Note: Service exposes port 80, but we forward to 16686 for standard Jaeger UI access" -ForegroundColor Gray
Write-Host ""

# Alternative: Direct port-forward to Pod
Write-Host "Alternative: Port-forward directly to Pod (if service doesn't work)" -ForegroundColor Cyan
Write-Host "   # Get Jaeger query pod name" -ForegroundColor Gray
Write-Host "   $pod = kubectl get pod -n observability -l app.kubernetes.io/name=jaeger,app.kubernetes.io/component=query -o jsonpath='{.items[0].metadata.name}'" -ForegroundColor Gray
Write-Host "   kubectl port-forward -n observability `$pod 16686:16686" -ForegroundColor White
Write-Host ""

Write-Host "💡 Tip: Run each command in a separate terminal window" -ForegroundColor Yellow
Write-Host "   Press Ctrl+C to stop port-forwarding" -ForegroundColor Gray




