#!/bin/bash

# CI/CD 本地测试脚本
# 在提交代码前，本地运行这些检查，确保 CI/CD 会通过

echo ""
echo "🔍 开始本地 CI/CD 检查..."
echo ""
echo "这个脚本会运行与 GitHub Actions 相同的检查"
echo "如果所有检查通过，CI/CD 也应该会通过"
echo ""

ERRORS=0

# 检查 1: Kubernetes YAML 验证
echo ""
echo "[1/4] 验证 Kubernetes YAML 文件..."
if command -v kubectl &> /dev/null; then
    find k8s -name "*.yaml" -o -name "*.yml" | while read file; do
        echo "  检查: $file"
        kubectl apply --dry-run=client -f "$file" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "  ❌ $(basename $file) 验证失败"
            ERRORS=$((ERRORS + 1))
        fi
    done
    if [ $ERRORS -eq 0 ]; then
        echo "  ✅ Kubernetes YAML 验证通过"
    fi
else
    echo "  ⚠️  kubectl 未安装，跳过 Kubernetes YAML 验证"
fi

# 检查 2: Helm Chart 验证
echo ""
echo "[2/4] 验证 Helm Charts..."
if command -v helm &> /dev/null; then
    # 验证 observability-platform
    if [ -f "helm/observability-platform/Chart.yaml" ]; then
        echo "  检查: observability-platform"
        cd helm/observability-platform
        helm lint . > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "  ❌ observability-platform Chart 验证失败"
            ERRORS=$((ERRORS + 1))
        else
            echo "  ✅ observability-platform Chart 验证通过"
        fi
        cd ../..
    fi
    
    # 验证 microservices
    if [ -f "helm/microservices/Chart.yaml" ]; then
        echo "  检查: microservices"
        cd helm/microservices
        helm lint . > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "  ❌ microservices Chart 验证失败"
            ERRORS=$((ERRORS + 1))
        else
            echo "  ✅ microservices Chart 验证通过"
        fi
        cd ../..
    fi
else
    echo "  ⚠️  Helm 未安装，跳过 Helm Chart 验证"
fi

# 检查 3: Python 代码验证
echo ""
echo "[3/4] 验证 Python 代码..."
if command -v python3 &> /dev/null || command -v python &> /dev/null; then
    PYTHON_CMD=$(command -v python3 || command -v python)
    find services -name "*.py" | while read file; do
        echo "  检查: $file"
        $PYTHON_CMD -m py_compile "$file" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "  ❌ $(basename $file) 语法错误"
            ERRORS=$((ERRORS + 1))
        fi
    done
    if [ $ERRORS -eq 0 ]; then
        echo "  ✅ Python 代码验证通过"
    fi
else
    echo "  ⚠️  Python 未安装，跳过 Python 代码验证"
fi

# 检查 4: Dockerfile 验证
echo ""
echo "[4/4] 验证 Dockerfiles..."
find services -name "Dockerfile" | while read dockerfile; do
    echo "  检查: $dockerfile"
    if [ -f "$dockerfile" ]; then
        if grep -q "FROM" "$dockerfile" && (grep -q "COPY" "$dockerfile" || grep -q "ADD" "$dockerfile" || grep -q "RUN" "$dockerfile"); then
            echo "  ✅ $(basename $(dirname $dockerfile))/Dockerfile 基本结构正确"
        else
            echo "  ⚠️  $(basename $(dirname $dockerfile))/Dockerfile 可能缺少必需指令"
        fi
    fi
done

# 总结
echo ""
echo "=================================================="
if [ $ERRORS -eq 0 ]; then
    echo ""
    echo "✅ 所有检查通过！可以安全提交代码了"
    echo ""
    echo "💡 提示：提交代码后，GitHub Actions 会自动运行相同的检查"
else
    echo ""
    echo "❌ 发现 $ERRORS 个错误，请修复后再提交"
    echo ""
    echo "💡 提示：修复错误后重新运行此脚本验证"
fi
echo "=================================================="
echo ""












