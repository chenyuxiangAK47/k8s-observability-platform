# Start only Grafana port forwarding

Write-Host "=== Starting Grafana Port Forwarding ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Starting Grafana port forwarding..." -ForegroundColor Green
Write-Host "Access Grafana at: http://localhost:3000" -ForegroundColor Yellow
Write-Host "Username: admin" -ForegroundColor Gray
Write-Host "Password: kLroxB5N2vTDsfo8g21No0ExXike3QJZlazZv8Uy" -ForegroundColor Gray
Write-Host "`nPress Ctrl+C to stop..." -ForegroundColor Yellow
Write-Host ""

kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80














