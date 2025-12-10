# 重置 Grafana 密码脚本

Write-Host "=== 重置 Grafana 密码 ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "当前 Grafana 密码信息:" -ForegroundColor Yellow
$currentPassword = kubectl get secret -n monitoring prometheus-operator-grafana -o jsonpath='{.data.admin-password}' 2>$null | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
$currentUser = kubectl get secret -n monitoring prometheus-operator-grafana -o jsonpath='{.data.admin-user}' 2>$null | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

Write-Host "  用户名: $currentUser" -ForegroundColor White
Write-Host "  当前密码: $currentPassword" -ForegroundColor White
Write-Host ""

$newPassword = Read-Host "输入新密码 (直接回车使用 'admin')"
if ([string]::IsNullOrWhiteSpace($newPassword)) {
    $newPassword = "admin"
}

Write-Host "`n正在重置密码为: $newPassword" -ForegroundColor Yellow

try {
    $result = kubectl exec -n monitoring deployment/prometheus-operator-grafana -- grafana-cli admin reset-admin-password $newPassword 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ 密码重置成功！" -ForegroundColor Green
        Write-Host "`n新的登录信息:" -ForegroundColor Cyan
        Write-Host "  用户名: admin" -ForegroundColor White
        Write-Host "  密码: $newPassword" -ForegroundColor Yellow
        Write-Host "`n现在可以登录 Grafana 了: http://localhost:3000" -ForegroundColor Green
    } else {
        Write-Host "`n❌ 密码重置失败" -ForegroundColor Red
        Write-Host "错误信息: $result" -ForegroundColor Red
        Write-Host "`n请使用当前密码登录: $currentPassword" -ForegroundColor Yellow
    }
} catch {
    Write-Host "`n❌ 执行失败: $_" -ForegroundColor Red
    Write-Host "`n请手动运行:" -ForegroundColor Yellow
    Write-Host "kubectl exec -n monitoring deployment/prometheus-operator-grafana -- grafana-cli admin reset-admin-password admin" -ForegroundColor White
}
















