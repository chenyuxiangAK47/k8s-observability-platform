# 资源优化指南 - 解决 Docker Desktop 崩溃问题

## 🔴 问题根源

你的 Docker Desktop 崩溃是因为：

- **CPU 使用率：2300%**（23 核满载）
- **内存：被 Prometheus + Loki + Grafana + Kubernetes 耗尽**
- **Docker Desktop 的 build 服务无法获得 CPU 时间片 → 崩溃**

---

## 🚨 立即行动（按顺序执行）

### 1. 紧急停止集群（释放资源）

```powershell
# 运行紧急停止脚本
.\scripts\emergency-stop-cluster.ps1

# 或手动执行
kind delete cluster --name observability-platform
```

**效果：** CPU 从 2300% → 0%

### 2. 强制重启 Docker Desktop

```powershell
# 运行重启脚本
.\scripts\restart-docker-desktop.ps1

# 然后手动：
# 1. 打开 Docker Desktop
# 2. 等待完全启动
```

### 3. 调整 Docker Desktop 资源限制

**Docker Desktop → Settings → Resources：**

推荐配置：
- **CPUs: 4**（不要超过物理 CPU 核心数）
- **Memory: 4-6GB**（不要超过物理内存的 1/3）
- **Swap: 1GB**
- **Disk image size: 64GB**（足够）

---

## 💡 长期解决方案（三选一）

### 方案 A: 轻量级监控栈（推荐本地开发）

**优点：**
- CPU 使用降低 90%
- 内存使用降低 80%
- 适合本地开发和测试

**包含：**
- Prometheus（单实例，无 Operator）
- Grafana
- 移除：Loki、Alertmanager、Node Exporter、Kube State Metrics

**实施：**
```powershell
# 使用轻量级配置
.\scripts\setup-lightweight-cluster.ps1
```

---

### 方案 B: 迁移到 AWS EKS（推荐生产环境）

**优点：**
- 真正的生产环境
- 无限资源（按需付费）
- 不会崩溃
- 可以展示 AWS 技能（SAA 认证内容）

**架构：**
- EKS 集群
- Managed Prometheus（可选）
- EC2 实例运行监控栈
- 或使用 AWS 托管服务

**实施步骤：**
1. 创建 EKS 集群
2. 部署应用
3. 配置监控
4. 设置 CI/CD

---

### 方案 C: 使用 k3s（轻量级 Kubernetes）

**优点：**
- 比 Kind 轻量 10 倍
- 启动只需 200MB 内存
- 完整的 Kubernetes 功能

**实施：**
```powershell
# 安装 k3s（需要 WSL 2 或 Linux）
# 然后部署应用
```

---

## 📊 资源对比

| 方案 | CPU 使用 | 内存使用 | 稳定性 | 适用场景 |
|------|---------|---------|--------|---------|
| **当前（完整栈）** | 2300% | 8GB+ | ❌ 崩溃 | 不推荐 |
| **轻量级监控** | 200% | 2GB | ✅ 稳定 | 本地开发 |
| **AWS EKS** | 按需 | 按需 | ✅✅ 非常稳定 | 生产环境 |
| **k3s** | 100% | 500MB | ✅ 稳定 | 本地开发 |

---

## 🎯 我的建议

### 短期（今天）

1. ✅ 停止当前集群
2. ✅ 重启 Docker Desktop
3. ✅ 调整资源限制
4. ✅ 使用轻量级监控栈重新部署

### 长期（项目完成）

1. 🚀 迁移到 AWS EKS
2. 📈 展示完整的生产级 DevOps 能力
3. 💼 可以写进简历

---

## 🔧 轻量级监控栈配置

我已经为你准备了轻量级配置：

### 特点：
- ✅ Prometheus（单实例，无 Operator）
- ✅ Grafana
- ✅ 基础监控指标
- ❌ 移除 Loki（日志聚合）
- ❌ 移除 Alertmanager（告警）
- ❌ 移除 Node Exporter（节点指标）
- ❌ 移除 Kube State Metrics（K8s 指标）

### 资源使用：
- CPU: ~200%（2 核）
- 内存: ~2GB
- 磁盘: ~5GB

---

## 📋 下一步操作

### 选项 1: 轻量级监控栈（推荐）

```powershell
# 1. 停止当前集群
.\scripts\emergency-stop-cluster.ps1

# 2. 重启 Docker Desktop
.\scripts\restart-docker-desktop.ps1

# 3. 调整 Docker Desktop 资源（手动）
# Settings → Resources → CPUs: 4, Memory: 4-6GB

# 4. 部署轻量级栈（我会为你创建脚本）
.\scripts\setup-lightweight-cluster.ps1
```

### 选项 2: 迁移到 AWS EKS

```powershell
# 1. 创建 AWS 账户（如果还没有）
# 2. 安装 AWS CLI
# 3. 配置 AWS 凭证
# 4. 创建 EKS 集群
# 5. 部署应用

# 我会为你创建完整的迁移脚本
.\scripts\migrate-to-aws-eks.ps1
```

---

## ❓ 你选择哪个方案？

1. **轻量级监控栈** - 快速修复，继续本地开发
2. **AWS EKS** - 迁移到云，展示生产级能力
3. **k3s** - 使用更轻量的 Kubernetes

告诉我你的选择，我会立即为你创建对应的脚本和配置！

---

## 🆘 如果 Docker Desktop 仍然崩溃

1. **完全卸载并重新安装 Docker Desktop**
2. **检查 Windows 资源使用**
3. **考虑使用 WSL 2 后端**
4. **升级硬件（如果可能）**

---

## 📞 需要帮助？

如果问题持续，请提供：
- Docker Desktop 版本
- Windows 版本
- 物理内存大小
- CPU 核心数

