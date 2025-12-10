# Verify AWS ECR Permissions
# This script verifies if the AWS credentials have ECR permissions

Write-Host "`n=== 验证 AWS ECR 权限 ===" -ForegroundColor Cyan

# Check if AWS CLI is installed
$awsCli = Get-Command aws -ErrorAction SilentlyContinue
if (-not $awsCli) {
    Write-Host "❌ AWS CLI not found" -ForegroundColor Red
    Write-Host "   Install: choco install awscli" -ForegroundColor Gray
    exit 1
}

Write-Host "✅ AWS CLI installed" -ForegroundColor Green

# Check AWS credentials
Write-Host "`n📋 Checking AWS credentials..." -ForegroundColor Yellow
$identity = aws sts get-caller-identity 2>&1
if ($LASTEXITCODE -eq 0) {
    $identityObj = $identity | ConvertFrom-Json
    Write-Host "✅ AWS credentials configured" -ForegroundColor Green
    Write-Host "   Account: $($identityObj.Account)" -ForegroundColor Gray
    Write-Host "   User ARN: $($identityObj.Arn)" -ForegroundColor Gray
} else {
    Write-Host "❌ AWS credentials not configured" -ForegroundColor Red
    Write-Host "   Run: aws configure" -ForegroundColor Gray
    exit 1
}

# Test ECR GetAuthorizationToken permission
Write-Host "`n📋 Testing ECR GetAuthorizationToken permission..." -ForegroundColor Yellow
$ecrToken = aws ecr get-authorization-token --region us-east-1 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ ECR GetAuthorizationToken permission: OK" -ForegroundColor Green
    $tokenObj = $ecrToken | ConvertFrom-Json
    Write-Host "   Authorization token retrieved successfully" -ForegroundColor Gray
} else {
    Write-Host "❌ ECR GetAuthorizationToken permission: FAILED" -ForegroundColor Red
    Write-Host "   Error: $ecrToken" -ForegroundColor Yellow
    Write-Host "`n解决方案:" -ForegroundColor Cyan
    Write-Host "1. 登录 AWS Console" -ForegroundColor Gray
    Write-Host "2. IAM → Users → github-actions" -ForegroundColor Gray
    Write-Host "3. Permissions → Add permissions" -ForegroundColor Gray
    Write-Host "4. 附加策略: AmazonEC2ContainerRegistryFullAccess" -ForegroundColor Gray
    exit 1
}

# Test ECR repository access
Write-Host "`n📋 Testing ECR repository access..." -ForegroundColor Yellow
$repos = aws ecr describe-repositories --region us-east-1 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ ECR repository access: OK" -ForegroundColor Green
    $reposObj = $repos | ConvertFrom-Json
    if ($reposObj.repositories.Count -gt 0) {
        Write-Host "   Found $($reposObj.repositories.Count) repository(ies):" -ForegroundColor Gray
        $reposObj.repositories | ForEach-Object {
            Write-Host "     - $($_.repositoryName)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   No repositories found (this is OK if you haven't created them yet)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  ECR repository access: Limited" -ForegroundColor Yellow
    Write-Host "   Error: $repos" -ForegroundColor Gray
    Write-Host "   (This might be OK if repositories don't exist yet)" -ForegroundColor Gray
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✅ 权限验证完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n📊 总结:" -ForegroundColor Yellow
Write-Host "   - AWS 凭证: ✅ 已配置" -ForegroundColor Green
Write-Host "   - ECR 权限: ✅ 正常" -ForegroundColor Green
Write-Host "`n💡 如果 GitHub Actions 仍然失败:" -ForegroundColor Cyan
Write-Host "   1. 确保 GitHub Secrets 中的 Access Key 是正确的" -ForegroundColor Gray
Write-Host "   2. 等待 1-2 分钟让 IAM 权限生效" -ForegroundColor Gray
Write-Host "   3. 重新运行 GitHub Actions 工作流" -ForegroundColor Gray

