# 全链路可观测性平台 - 一键启动脚本
# 自动启动所有 Docker 服务和微服务

param(
    [switch]$SkipDocker,  # 跳过 Docker 服务启动（如果已经启动）
    [switch]$SkipMicroservices  # 跳过微服务启动
)

$ErrorActionPreference = "Stop"

Write-Host "`n🚀 全链路可观测性平台 - 一键启动" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# ==================== Step 1: 检查 Docker ====================
if (-not $SkipDocker) {
    Write-Host "`n📦 Step 1: 检查 Docker Desktop..." -ForegroundColor Yellow
    try {
        docker info | Out-Null
        Write-Host "  ✅ Docker Desktop 正在运行" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Docker Desktop 未运行！" -ForegroundColor Red
        Write-Host "  请先启动 Docker Desktop，然后重新运行此脚本" -ForegroundColor Yellow
        pause
        exit 1
    }
}

# ==================== Step 2: 创建必要目录 ====================
Write-Host "`n📁 Step 2: 创建必要目录..." -ForegroundColor Yellow
$dirs = @("services\logs", "grafana\dashboards")
foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  ✅ 创建目录: $dir" -ForegroundColor Green
    } else {
        Write-Host "  ✓ 目录已存在: $dir" -ForegroundColor Gray
    }
}

# ==================== Step 3: 启动 Docker Compose ====================
if (-not $SkipDocker) {
    Write-Host "`n🐳 Step 3: 启动 Docker Compose 服务..." -ForegroundColor Yellow
    
    # 检查是否已有服务运行
    $running = docker-compose ps -q 2>$null
    if ($running) {
        Write-Host "  ⚠️  检测到已有 Docker 服务运行，先停止..." -ForegroundColor Yellow
        docker-compose down | Out-Null
        Start-Sleep -Seconds 2
    }
    
    Write-Host "  启动 Prometheus, Grafana, Loki, Jaeger..." -ForegroundColor Gray
    docker-compose up -d | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Docker 服务启动成功" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Docker 服务启动失败" -ForegroundColor Red
        exit 1
    }
    
    # 等待服务启动
    Write-Host "  ⏳ 等待服务就绪（10秒）..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
    
    # 检查服务状态
    Write-Host "`n  📊 Docker 服务状态:" -ForegroundColor Cyan
    docker-compose ps --format "table {{.Name}}\t{{.Status}}"
} else {
    Write-Host "`n⏭️  Step 3: 跳过 Docker 服务启动" -ForegroundColor Gray
}

# ==================== Step 4: 检查 Python 依赖 ====================
if (-not $SkipMicroservices) {
    Write-Host "`n🐍 Step 4: 检查 Python 环境..." -ForegroundColor Yellow
    
    # 检查 Python
    try {
        $pythonVersion = py --version 2>&1
        Write-Host "  ✅ Python: $pythonVersion" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ 未找到 Python，请先安装 Python 3.9+" -ForegroundColor Red
        exit 1
    }
    
    # 检查 pip
    try {
        py -m pip --version | Out-Null
        Write-Host "  ✅ pip 已安装" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  pip 未安装，正在安装..." -ForegroundColor Yellow
        py -m ensurepip --upgrade | Out-Null
    }
    
    # 检查 requirements.txt
    if (-not (Test-Path "services\requirements.txt")) {
        Write-Host "  ❌ 未找到 requirements.txt" -ForegroundColor Red
        exit 1
    }
    
    # 安装依赖
    Write-Host "`n📦 Step 5: 安装 Python 依赖..." -ForegroundColor Yellow
    Write-Host "  这可能需要几分钟，请耐心等待..." -ForegroundColor Gray
    Push-Location services
    try {
        py -m pip install -q -r requirements.txt
        Write-Host "  ✅ 依赖安装完成" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ 依赖安装失败，请检查错误信息" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Pop-Location
} else {
    Write-Host "`n⏭️  Step 4-5: 跳过 Python 检查和微服务启动" -ForegroundColor Gray
}

# ==================== Step 6: 停止旧的微服务进程 ====================
if (-not $SkipMicroservices) {
    Write-Host "`n🛑 Step 6: 清理旧的微服务进程..." -ForegroundColor Yellow
    
    # 查找并停止可能运行的微服务进程
    $processes = Get-Process | Where-Object {
        $_.ProcessName -eq "python" -or $_.ProcessName -eq "py"
    } | Where-Object {
        $_.CommandLine -like "*order_service*" -or 
        $_.CommandLine -like "*product_service*" -or 
        $_.CommandLine -like "*user_service*"
    }
    
    if ($processes) {
        $processes | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host "  ✅ 已停止旧进程" -ForegroundColor Green
    } else {
        Write-Host "  ✓ 没有运行中的旧进程" -ForegroundColor Gray
    }
    
    Start-Sleep -Seconds 1
}

# ==================== Step 7: 启动微服务 ====================
if (-not $SkipMicroservices) {
    Write-Host "`n🌐 Step 7: 启动微服务..." -ForegroundColor Yellow
    
    $services = @(
        @{Name="Order Service"; Port=8000; Script="order_service\main.py"},
        @{Name="Product Service"; Port=8001; Script="product_service\main.py"},
        @{Name="User Service"; Port=8002; Script="user_service\main.py"}
    )
    
    $servicePids = @()
    
    foreach ($service in $services) {
        Write-Host "  启动 $($service.Name) (端口 $($service.Port))..." -ForegroundColor Gray
        
        # 后台启动服务
        $process = Start-Process powershell -ArgumentList @(
            "-WindowStyle", "Hidden",
            "-Command", "cd '$PWD\services'; py $($service.Script)"
        ) -PassThru -ErrorAction SilentlyContinue
        
        if ($process) {
            $servicePids += $process.Id
            Write-Host "    ✅ $($service.Name) 已启动 (PID: $($process.Id))" -ForegroundColor Green
        } else {
            Write-Host "    ⚠️  $($service.Name) 启动可能失败" -ForegroundColor Yellow
        }
        
        Start-Sleep -Seconds 2
    }
    
    # 等待服务启动
    Write-Host "`n  ⏳ 等待微服务就绪（5秒）..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
    
    # 检查服务状态
    Write-Host "`n  📊 微服务状态检查:" -ForegroundColor Cyan
    foreach ($service in $services) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$($service.Port)/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            Write-Host "    ✅ $($service.Name) (端口 $($service.Port)): 运行正常" -ForegroundColor Green
        } catch {
            Write-Host "    ⚠️  $($service.Name) (端口 $($service.Port)): 启动中或出错" -ForegroundColor Yellow
        }
    }
    
    # 保存进程 ID 到文件（方便后续停止）
    $servicePids | Out-File -FilePath ".service-pids.txt" -Encoding utf8
}

# ==================== 完成 ====================
Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
Write-Host "✅ 启动完成！" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Cyan

Write-Host "`n📊 服务访问地址:" -ForegroundColor Cyan
Write-Host "  🐳 Docker 服务:" -ForegroundColor Yellow
Write-Host "    - Grafana:     http://localhost:3000 (admin/admin)" -ForegroundColor White
Write-Host "    - Prometheus:  http://localhost:9090" -ForegroundColor White
Write-Host "    - Jaeger:      http://localhost:16686" -ForegroundColor White
Write-Host "    - Loki:        http://localhost:3100" -ForegroundColor White

if (-not $SkipMicroservices) {
    Write-Host "`n  🐍 微服务:" -ForegroundColor Yellow
    Write-Host "    - Order Service:   http://localhost:8000" -ForegroundColor White
    Write-Host "    - Product Service: http://localhost:8001" -ForegroundColor White
    Write-Host "    - User Service:    http://localhost:8002" -ForegroundColor White
}

Write-Host "`n💡 提示:" -ForegroundColor Cyan
Write-Host "  - 停止所有服务: .\stop-all.ps1" -ForegroundColor Gray
Write-Host "  - 查看服务状态: docker-compose ps" -ForegroundColor Gray
Write-Host "  - 微服务在后台运行，日志在 services\logs\ 目录" -ForegroundColor Gray

Write-Host "`n按任意键退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")


