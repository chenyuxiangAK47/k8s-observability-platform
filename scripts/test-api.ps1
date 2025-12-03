# 测试微服务 API 的 PowerShell 脚本

param(
    [string]$Service = "user-service",
    [int]$Port = 8001
)

Write-Host "测试 $Service API..." -ForegroundColor Cyan

# 检查端口转发是否运行
$portForward = Get-Process -Name kubectl -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*port-forward*$Port*" }
if (-not $portForward) {
    Write-Host "警告: 端口转发可能未运行" -ForegroundColor Yellow
    Write-Host "请先运行: kubectl port-forward -n microservices svc/$Service $Port`:$Port" -ForegroundColor Yellow
    Write-Host ""
}

$baseUrl = "http://localhost:$Port"

# 测试健康检查
Write-Host "`n1. 测试健康检查..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method GET
    Write-Host "   ✓ 健康检查通过: $($health | ConvertTo-Json)" -ForegroundColor Green
} catch {
    Write-Host "   ✗ 健康检查失败: $_" -ForegroundColor Red
}

# 测试创建用户
Write-Host "`n2. 测试创建用户..." -ForegroundColor Yellow
try {
    $userBody = @{
        email = "test@example.com"
        name = "Test User"
        password = "123456"
    } | ConvertTo-Json

    $user = Invoke-RestMethod -Uri "$baseUrl/api/users" -Method POST -ContentType "application/json" -Body $userBody
    Write-Host "   ✓ 用户创建成功:" -ForegroundColor Green
    Write-Host "     ID: $($user.id)" -ForegroundColor White
    Write-Host "     邮箱: $($user.email)" -ForegroundColor White
    Write-Host "     姓名: $($user.name)" -ForegroundColor White
    
    $userId = $user.id
} catch {
    Write-Host "   ✗ 创建用户失败: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "     响应: $responseBody" -ForegroundColor Red
    }
    $userId = $null
}

# 测试获取用户
if ($userId) {
    Write-Host "`n3. 测试获取用户..." -ForegroundColor Yellow
    try {
        $user = Invoke-RestMethod -Uri "$baseUrl/api/users/$userId" -Method GET
        Write-Host "   ✓ 获取用户成功:" -ForegroundColor Green
        Write-Host "     $($user | ConvertTo-Json)" -ForegroundColor White
    } catch {
        Write-Host "   ✗ 获取用户失败: $_" -ForegroundColor Red
    }
}

# 测试 Prometheus 指标
Write-Host "`n4. 测试 Prometheus 指标..." -ForegroundColor Yellow
try {
    $metrics = Invoke-WebRequest -Uri "$baseUrl/metrics" -Method GET
    Write-Host "   ✓ 指标端点可访问" -ForegroundColor Green
    $metricLines = $metrics.Content -split "`n" | Select-String "user_service_http_requests_total" | Select-Object -First 3
    if ($metricLines) {
        Write-Host "   示例指标:" -ForegroundColor White
        $metricLines | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
    }
} catch {
    Write-Host "   ✗ 指标端点不可访问: $_" -ForegroundColor Red
}

Write-Host "`n测试完成！" -ForegroundColor Cyan




