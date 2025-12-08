# 访问可观测性平台的脚本

Write-Host "=== 可观测性平台访问指南 ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "📊 可观测性平台包含以下组件:" -ForegroundColor Yellow
Write-Host "  1. Grafana - 统一可视化平台（推荐从这里开始）" -ForegroundColor White
Write-Host "  2. Prometheus - 指标查询" -ForegroundColor White
Write-Host "  3. Jaeger - 分布式追踪" -ForegroundColor White
Write-Host "  4. Loki - 日志聚合（通过 Grafana 访问）" -ForegroundColor White
Write-Host ""

Write-Host "🚀 快速启动（在单独的 PowerShell 窗口中运行）:" -ForegroundColor Green
Write-Host ""

Write-Host "# 1. Grafana（统一可视化，推荐）" -ForegroundColor Cyan
Write-Host "kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80" -ForegroundColor White
Write-Host "# 然后访问: http://localhost:3000" -ForegroundColor Gray
Write-Host "# 用户名: admin, 密码: admin" -ForegroundColor Gray
Write-Host ""

Write-Host "# 2. Prometheus（指标查询）" -ForegroundColor Cyan
Write-Host "kubectl port-forward -n monitoring svc/prometheus-operator-kube-prom-prometheus 9090:9090" -ForegroundColor White
Write-Host "# 然后访问: http://localhost:9090" -ForegroundColor Gray
Write-Host ""

Write-Host "# 3. Jaeger（分布式追踪）" -ForegroundColor Cyan
Write-Host "kubectl port-forward -n observability svc/observability-platform-jaeger-query 16686:16686" -ForegroundColor White
Write-Host "# 然后访问: http://localhost:16686" -ForegroundColor Gray
Write-Host ""

Write-Host "💡 提示:" -ForegroundColor Yellow
Write-Host "  - Swagger UI (http://localhost:8001/docs) 是 API 文档，用于测试接口" -ForegroundColor White
Write-Host "  - Observability Platform 是监控平台，用于查看系统运行状态" -ForegroundColor White
Write-Host "  - 建议先访问 Grafana，它集成了 Prometheus 和 Loki 的数据" -ForegroundColor White
Write-Host ""

$choice = Read-Host "是否现在启动 Grafana 端口转发? (Y/N)"
if ($choice -eq "Y" -or $choice -eq "y") {
    Write-Host "`n启动 Grafana 端口转发..." -ForegroundColor Green
    Write-Host "访问地址: http://localhost:3000" -ForegroundColor Yellow
    Write-Host "用户名: admin, 密码: admin" -ForegroundColor Yellow
    Write-Host "`n按 Ctrl+C 停止端口转发" -ForegroundColor Gray
    kubectl port-forward -n monitoring svc/prometheus-operator-grafana 3000:80
}













