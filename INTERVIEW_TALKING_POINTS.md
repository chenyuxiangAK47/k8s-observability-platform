# 面试话术指南 - STAR 方法

本文档帮助你用 STAR（Situation-Task-Action-Result）方法讲述项目故事。

---

## 项目：k8s-observability-platform

### 🎯 一句话总结
"我将 Docker Compose 的微服务架构迁移到 Kubernetes，并实现了完整的可观测性平台，包括 Prometheus Operator、OpenTelemetry 分布式追踪和自动化部署。"

---

### 📖 完整故事（STAR）

#### **Situation（情况）**
- 有两个独立的项目：一个是 Docker Compose 的可观测性平台，一个是微服务应用
- 需要将它们整合并迁移到 Kubernetes，实现生产级的部署
- 需要实现完整的可观测性（Metrics、Logs、Traces）来监控微服务

#### **Task（任务）**
- 设计 Kubernetes 部署架构（命名空间、Service、Deployment）
- 集成 Prometheus Operator，实现自动指标发现
- 配置 OpenTelemetry 分布式追踪
- 使用 Helm Chart 管理所有组件
- 实现 HPA 自动扩缩容
- 编写自动化部署脚本

#### **Action（行动）**
1. **架构设计**：
   - 创建三个命名空间：`observability`、`microservices`、`monitoring`
   - 使用 Helm Chart 模块化管理组件
   - 配置 ServiceMonitor 实现 Prometheus 自动发现

2. **技术实现**：
   - 修复 Prometheus 指标重复注册问题（实现 `get_or_create_counter` 函数）
   - 修复 ServiceMonitor 配置（正确匹配 Service 标签）
   - 修复 API 定义（使用 Pydantic 模型接收请求体）
   - 配置 OpenTelemetry 自动检测 FastAPI 和 SQLAlchemy

3. **问题排查**：
   - 解决了 PostgreSQL 连接问题（使用 `POSTGRES_MULTIPLE_DATABASES` 环境变量）
   - 解决了 Grafana 数据源配置问题（使用集群内 Service URL）
   - 所有问题都有详细的问题排查文档

4. **工程化**：
   - 编写一键部署脚本（PowerShell 和 Bash）
   - 编写镜像构建脚本
   - 编写 API 测试脚本
   - **实现 CI/CD 流程**：使用 GitHub Actions 自动验证 Kubernetes YAML、Helm Charts、Python 代码和 Dockerfile

#### **Result（结果）**
- ✅ 成功部署完整的可观测性平台到 Kubernetes
- ✅ 实现了零配置的指标采集（ServiceMonitor 自动发现）
- ✅ 完整的 Trace 链路追踪（跨服务追踪）
- ✅ 所有服务正常运行，指标正常采集
- ✅ 创建了完整的问题排查文档，便于后续维护
- ✅ **实现了 CI/CD 自动化**：每次代码提交自动验证，确保代码质量
- ✅ 项目已推送到 GitHub，代码和文档完整

---

### 💡 技术亮点（可以深入展开的话题）

#### 1. Prometheus Operator 的使用
**问题：** 如何实现自动指标发现？  
**答案：** 
- 使用 ServiceMonitor CRD，通过标签选择器自动发现需要监控的服务
- 配置正确的 `selector` 和 `port`，Prometheus Operator 会自动创建 scrape_configs
- 这样新增服务时，只需要添加 ServiceMonitor，无需修改 Prometheus 配置

#### 2. OpenTelemetry 分布式追踪
**问题：** 如何实现跨服务追踪？  
**答案：**
- 使用 OpenTelemetry Python SDK
- 配置自动检测（Auto-instrumentation）FastAPI 和 SQLAlchemy
- 通过 HTTP headers（traceparent）传递 Trace ID
- 所有 Trace 数据发送到 Jaeger，可以在 Grafana 中统一查看

#### 3. Helm Chart 设计
**问题：** 为什么使用 Helm Chart？  
**答案：**
- 实现配置与代码分离，通过 values.yaml 管理不同环境的配置
- 使用模板函数实现 DRY（Don't Repeat Yourself）
- 支持依赖管理（通过 Chart.yaml 的 dependencies）
- 便于版本管理和回滚

#### 4. 问题排查能力
**问题：** 遇到问题时如何排查？  
**答案：**
- 查看 Pod 日志：`kubectl logs`
- 检查 ServiceMonitor 配置：`kubectl get servicemonitor -o yaml`
- 在 Prometheus UI 中查看 Targets 状态
- 使用 `kubectl describe` 查看资源详情
- 所有排查过程都记录在 `docs/TROUBLESHOOTING.md` 中

#### 5. CI/CD 自动化
**问题：** 如何保证代码质量？  
**答案：**
- 使用 GitHub Actions 实现 CI/CD 流程
- 自动验证 Kubernetes YAML 配置（kubectl dry-run）
- 自动验证 Helm Charts（helm lint + template）
- 自动检查 Python 代码语法和风格
- 自动验证 Dockerfile 配置
- 每次代码提交或 PR 创建时自动运行，确保代码质量

---

### 🎤 常见面试问题回答

#### Q1: "为什么选择 Prometheus Operator 而不是直接部署 Prometheus？"
**A:** 
- Prometheus Operator 提供了 CRD（ServiceMonitor、PrometheusRule），让配置更加声明式
- 自动管理 Prometheus 配置，无需手动编辑配置文件
- 支持自动发现和动态配置更新
- 更符合 Kubernetes 的"声明式配置"理念

#### Q2: "如何保证服务的高可用？"
**A:**
- 配置了 HPA（Horizontal Pod Autoscaler），基于 CPU/内存自动扩缩容
- 使用 Kubernetes Service 实现负载均衡
- 配置了 Liveness 和 Readiness Probes，确保不健康的 Pod 被自动替换
- （未来可以添加多副本和反亲和性配置）

#### Q3: "如果 Prometheus 采集不到指标，你会怎么排查？"
**A:**
1. 检查 ServiceMonitor 配置是否正确（selector 是否匹配 Service）
2. 检查 Service 的端口配置是否正确
3. 在 Prometheus UI 中查看 Targets 状态
4. 直接访问 Pod 的 `/metrics` 端点，确认指标是否正常暴露
5. 查看 Prometheus Operator 的日志

#### Q4: "这个项目最大的挑战是什么？"
**A:** 
最大的挑战是 Prometheus 指标重复注册的问题。当应用重启或重新加载时，Prometheus client 会尝试重新注册相同的指标，导致 `ValueError: Duplicated timeseries`。

**解决方案：**
- 实现了 `get_or_create_counter` 函数，在注册前检查指标是否已存在
- 使用 `REGISTRY._names` 检查指标名称
- 如果已存在，直接返回现有指标；否则创建新指标

这个问题让我深入理解了 Prometheus client 库的工作原理。

#### Q5: "你了解 CI/CD 吗？"
**A:** 
是的，我在项目中实现了完整的 CI/CD 流程。使用 GitHub Actions 自动验证 Kubernetes YAML 配置、Helm Charts、Python 代码和 Dockerfile。

**好处：**
- 早期发现问题：在合并前就发现配置错误
- 提高代码质量：强制代码规范检查
- 自动化：不需要手动运行测试
- 可重复：每次运行都得到相同的结果

这让我从"手动检查"到"自动化验证"，大大提高了开发效率。

---

### 📊 项目数据（用于量化成果）

- **代码行数**：7,339 行新增代码
- **文件数量**：99 个文件变更
- **服务数量**：3 个微服务 + 4 个可观测性组件
- **问题解决**：解决了 10+ 个实际问题
- **文档数量**：10+ 篇详细文档

---

### 🔗 相关项目（可以提及）

1. **production-ready-observability-platform**：Docker Compose 版本，用于快速实验
2. **Prometheus-Grafana**：专注于 Prometheus Operator 的教学项目
3. **k8s-observability-platform**：当前项目，最完整的生产级部署

这三个项目展示了从 Docker 到 Kubernetes 的完整技术栈演进。

---

### 💬 收尾话术

**当被问到"还有什么想补充的吗？"时：**

> "这个项目让我从'会用工具'到'理解原理'再到'能解决实际问题'，形成了完整的知识体系。特别是问题排查的过程，让我深入理解了 Prometheus Operator、OpenTelemetry 等工具的工作原理。所有的问题和解决方案我都详细记录在文档中，这也体现了我的文档编写能力。"

---

## 📝 使用建议

1. **提前准备**：熟记 STAR 故事，但不要死记硬背，要自然讲述
2. **技术细节**：准备 2-3 个可以深入展开的技术点
3. **量化成果**：用具体数字说明项目规模（代码行数、服务数量等）
4. **问题导向**：强调你解决了什么问题，而不是你用了什么工具
5. **持续学习**：提到你从项目中学到了什么，展示了学习能力

---

**最后更新：2025-12-03**

