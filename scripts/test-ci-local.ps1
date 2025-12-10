# CI/CD 本地测试脚本
# 在提交代码前，本地运行这些检查，确保 CI/CD 会通过

Write-Host "`n🔍 开始本地 CI/CD 检查..." -ForegroundColor Cyan
Write-Host "`n这个脚本会运行与 GitHub Actions 相同的检查" -ForegroundColor Yellow
Write-Host "如果所有检查通过，CI/CD 也应该会通过`n" -ForegroundColor Yellow

$errors = 0

# 检查 1: Kubernetes YAML 验证
Write-Host "`n[1/4] 验证 Kubernetes YAML 文件..." -ForegroundColor Cyan
try {
    $yamlFiles = Get-ChildItem -Path k8s -Recurse -Include *.yaml,*.yml
    foreach ($file in $yamlFiles) {
        Write-Host "  检查: $($file.FullName)" -ForegroundColor Gray
        kubectl apply --dry-run=client -f $file.FullName 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ❌ $($file.Name) 验证失败" -ForegroundColor Red
            $errors++
        }
    }
    if ($errors -eq 0) {
        Write-Host "  ✅ Kubernetes YAML 验证通过" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠️  kubectl 未安装或无法访问，跳过 Kubernetes YAML 验证" -ForegroundColor Yellow
}

# 检查 2: Helm Chart 验证
Write-Host "`n[2/4] 验证 Helm Charts..." -ForegroundColor Cyan
try {
    # 验证 observability-platform
    if (Test-Path "helm/observability-platform/Chart.yaml") {
        Write-Host "  检查: observability-platform" -ForegroundColor Gray
        Push-Location helm/observability-platform
        helm lint . 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ❌ observability-platform Chart 验证失败" -ForegroundColor Red
            $errors++
        } else {
            Write-Host "  ✅ observability-platform Chart 验证通过" -ForegroundColor Green
        }
        Pop-Location
    }
    
    # 验证 microservices
    if (Test-Path "helm/microservices/Chart.yaml") {
        Write-Host "  检查: microservices" -ForegroundColor Gray
        Push-Location helm/microservices
        helm lint . 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ❌ microservices Chart 验证失败" -ForegroundColor Red
            $errors++
        } else {
            Write-Host "  ✅ microservices Chart 验证通过" -ForegroundColor Green
        }
        Pop-Location
    }
} catch {
    Write-Host "  ⚠️  Helm 未安装或无法访问，跳过 Helm Chart 验证" -ForegroundColor Yellow
}

# 检查 3: Python 代码验证
Write-Host "`n[3/4] 验证 Python 代码..." -ForegroundColor Cyan
try {
    $pythonFiles = Get-ChildItem -Path services -Recurse -Include *.py
    foreach ($file in $pythonFiles) {
        Write-Host "  检查: $($file.FullName)" -ForegroundColor Gray
        python -m py_compile $file.FullName 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ❌ $($file.Name) 语法错误" -ForegroundColor Red
            $errors++
        }
    }
    if ($errors -eq 0) {
        Write-Host "  ✅ Python 代码验证通过" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠️  Python 未安装或无法访问，跳过 Python 代码验证" -ForegroundColor Yellow
}

# 检查 4: Dockerfile 验证
Write-Host "`n[4/4] 验证 Dockerfiles..." -ForegroundColor Cyan
try {
    $dockerfiles = Get-ChildItem -Path services -Recurse -Include Dockerfile
    foreach ($dockerfile in $dockerfiles) {
        Write-Host "  检查: $($dockerfile.FullName)" -ForegroundColor Gray
        # 简单的 Dockerfile 语法检查（检查是否存在）
        if (Test-Path $dockerfile.FullName) {
            $content = Get-Content $dockerfile.FullName -Raw
            if ($content -match "FROM\s+\w+" -and $content -match "COPY|ADD|RUN") {
                Write-Host "  ✅ $($dockerfile.Name) 基本结构正确" -ForegroundColor Green
            } else {
                Write-Host "  ⚠️  $($dockerfile.Name) 可能缺少必需指令" -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "  ⚠️  无法验证 Dockerfile，跳过" -ForegroundColor Yellow
}

# 总结
Write-Host "`n" -NoNewline
Write-Host "=" * 50 -ForegroundColor Gray
if ($errors -eq 0) {
    Write-Host "`n✅ 所有检查通过！可以安全提交代码了" -ForegroundColor Green
    Write-Host "`n💡 提示：提交代码后，GitHub Actions 会自动运行相同的检查" -ForegroundColor Cyan
} else {
    Write-Host "`n❌ 发现 $errors 个错误，请修复后再提交" -ForegroundColor Red
    Write-Host "`n💡 提示：修复错误后重新运行此脚本验证" -ForegroundColor Yellow
}
Write-Host "=" * 50 -ForegroundColor Gray
Write-Host ""












