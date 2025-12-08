# 测试所有微服务的 PowerShell 脚本

Write-Host "=== 测试所有微服务 ===" -ForegroundColor Cyan
Write-Host ""

# 检查端口转发
Write-Host "检查端口转发状态..." -ForegroundColor Yellow
$ports = @(8001, 8002, 8003)
$portForwards = @()

foreach ($port in $ports) {
    $pf = Get-Process -Name kubectl -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*port-forward*$port*" }
    if ($pf) {
        Write-Host "  ✓ 端口 $port 已转发" -ForegroundColor Green
        $portForwards += $port
    } else {
        Write-Host "  ✗ 端口 $port 未转发" -ForegroundColor Red
        Write-Host "    运行: kubectl port-forward -n microservices svc/user-service $port`:$port" -ForegroundColor Gray
    }
}

if ($portForwards.Count -eq 0) {
    Write-Host "`n请先启动端口转发！" -ForegroundColor Red
    Write-Host "在单独的 PowerShell 窗口中运行:" -ForegroundColor Yellow
    Write-Host "  kubectl port-forward -n microservices svc/user-service 8001:8001" -ForegroundColor White
    Write-Host "  kubectl port-forward -n microservices svc/product-service 8002:8002" -ForegroundColor White
    Write-Host "  kubectl port-forward -n microservices svc/order-service 8003:8003" -ForegroundColor White
    exit 1
}

Write-Host "`n开始测试..." -ForegroundColor Cyan

# 测试 user-service
if (8001 -in $portForwards) {
    Write-Host "`n--- 测试 User Service ---" -ForegroundColor Yellow
    & "$PSScriptRoot\test-api.ps1" -Service "user-service" -Port 8001
}

# 测试 product-service
if (8002 -in $portForwards) {
    Write-Host "`n--- 测试 Product Service ---" -ForegroundColor Yellow
    Write-Host "创建商品..." -ForegroundColor Gray
    try {
        $productBody = @{
            name = "MacBook Pro"
            description = "Apple Laptop"
            price = 12999.0
            stock = 50
        } | ConvertTo-Json
        
        $product = Invoke-RestMethod -Uri "http://localhost:8002/api/products/" -Method POST -ContentType "application/json" -Body $productBody
        Write-Host "  ✓ 商品创建成功: $($product.name) - ¥$($product.price)" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ 创建商品失败: $_" -ForegroundColor Red
    }
}

# 测试 order-service
if (8003 -in $portForwards) {
    Write-Host "`n--- 测试 Order Service ---" -ForegroundColor Yellow
    Write-Host "创建订单..." -ForegroundColor Gray
    try {
        $orderBody = @{
            user_id = 1
            product_id = 1
            quantity = 3
        } | ConvertTo-Json
        
        $order = Invoke-RestMethod -Uri "http://localhost:8003/api/orders" -Method POST -ContentType "application/json" -Body $orderBody
        Write-Host "  ✓ 订单创建成功: Order #$($order.id)" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ 创建订单失败: $_" -ForegroundColor Red
    }
}

Write-Host "`n=== 测试完成 ===" -ForegroundColor Cyan













