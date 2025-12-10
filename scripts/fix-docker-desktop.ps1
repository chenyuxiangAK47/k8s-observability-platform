# Fix Docker Desktop Error
# This script helps diagnose and fix Docker Desktop issues

Write-Host "`n=== Docker Desktop 错误修复 ===" -ForegroundColor Cyan

# Step 1: Check if Docker Desktop process is running
Write-Host "`n📋 Step 1: Checking Docker Desktop process..." -ForegroundColor Yellow
$dockerProcess = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
if ($dockerProcess) {
    Write-Host "⚠️  Docker Desktop 进程仍在运行，正在关闭..." -ForegroundColor Yellow
    Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
    Write-Host "✅ Docker Desktop 已关闭" -ForegroundColor Green
} else {
    Write-Host "✅ Docker Desktop 进程未运行" -ForegroundColor Green
}

# Step 2: Check Docker service
Write-Host "`n📋 Step 2: Checking Docker service..." -ForegroundColor Yellow
$dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
if ($dockerService) {
    Write-Host "   Docker 服务状态: $($dockerService.Status)" -ForegroundColor Cyan
    if ($dockerService.Status -ne "Running") {
        Write-Host "   正在启动 Docker 服务..." -ForegroundColor Gray
        Start-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
    }
}

# Step 3: Clear Docker Desktop cache (optional)
Write-Host "`n📋 Step 3: 建议清理 Docker Desktop 缓存..." -ForegroundColor Yellow
Write-Host "   位置: %APPDATA%\Docker" -ForegroundColor Gray
Write-Host "   如果问题持续，可以删除此文件夹（需要先完全关闭 Docker Desktop）" -ForegroundColor Gray

# Step 4: Instructions
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "📝 修复步骤" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n方法 1: 重置到出厂设置（推荐）" -ForegroundColor Green
Write-Host "   1. 打开 Docker Desktop" -ForegroundColor Gray
Write-Host "   2. 点击 Settings (设置)" -ForegroundColor Gray
Write-Host "   3. 点击 'Troubleshoot' (故障排除)" -ForegroundColor Gray
Write-Host "   4. 点击 'Reset to factory defaults' (重置到出厂设置)" -ForegroundColor Gray
Write-Host "   5. 确认重置（这会删除所有容器和镜像）" -ForegroundColor Gray

Write-Host "`n方法 2: 重新安装 Docker Desktop" -ForegroundColor Green
Write-Host "   1. 完全卸载 Docker Desktop" -ForegroundColor Gray
Write-Host "   2. 删除以下文件夹:" -ForegroundColor Gray
Write-Host "      - %APPDATA%\Docker" -ForegroundColor Gray
Write-Host "      - %LOCALAPPDATA%\Docker" -ForegroundColor Gray
Write-Host "      - %PROGRAMDATA%\Docker" -ForegroundColor Gray
Write-Host "   3. 重新下载并安装 Docker Desktop" -ForegroundColor Gray
Write-Host "   4. 重启电脑" -ForegroundColor Gray

Write-Host "`n方法 3: 使用 WSL 2 后端（如果可用）" -ForegroundColor Green
Write-Host "   1. 确保已安装 WSL 2" -ForegroundColor Gray
Write-Host "   2. 在 Docker Desktop Settings → General" -ForegroundColor Gray
Write-Host "   3. 启用 'Use the WSL 2 based engine'" -ForegroundColor Gray
Write-Host "   4. 应用并重启 Docker Desktop" -ForegroundColor Gray

Write-Host "`n方法 4: 收集诊断信息" -ForegroundColor Green
Write-Host "   1. 在错误对话框中点击 'Gather diagnostics'" -ForegroundColor Gray
Write-Host "   2. 将诊断报告发送给 Docker 支持" -ForegroundColor Gray
Write-Host "   3. 或提交 GitHub issue" -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "⚠️  重要提示" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`n重置或重新安装 Docker Desktop 会删除:" -ForegroundColor Red
Write-Host "   - 所有容器（包括 Kind 集群）" -ForegroundColor Gray
Write-Host "   - 所有镜像" -ForegroundColor Gray
Write-Host "   - 所有卷和数据" -ForegroundColor Gray
Write-Host "`n重置后需要重新创建集群:" -ForegroundColor Yellow
Write-Host "   kind create cluster --name observability-platform" -ForegroundColor Gray
Write-Host "   .\scripts\setup-and-deploy.ps1" -ForegroundColor Gray

Write-Host "`n✅ Diagnosis completed!" -ForegroundColor Green

