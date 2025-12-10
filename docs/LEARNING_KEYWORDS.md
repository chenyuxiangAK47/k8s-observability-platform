# 🎓 可观测性学习关键词速查

## 📊 Grafana 关键词

### 核心概念
- **Dashboard（仪表板）**: 多个图表的集合
- **Panel（面板）**: 单个图表/可视化
- **Data Source（数据源）**: Prometheus, Loki, Jaeger
- **Query（查询）**: 数据查询语句
- **Variable（变量）**: 动态参数
- **Alert（告警）**: 基于指标的告警规则
- **Annotation（注释）**: 时间线标记

### 可视化类型
- **Graph（图表）**: 折线图
- **Stat（统计）**: 单个数值
- **Table（表格）**: 数据表格
- **Heatmap（热力图）**: 热力图
- **Logs（日志）**: 日志查看器

### 操作
- **Explore（探索）**: 临时查询界面
- **Alerting（告警）**: 告警管理
- **Administration（管理）**: 系统管理

---

## 📈 Prometheus 关键词

### 核心概念
- **Metric（指标）**: 监控数据点
- **Label（标签）**: 指标的维度
- **Time Series（时间序列）**: 指标 + 标签 + 时间
- **Target（目标）**: 被监控的对象
- **Scrape（抓取）**: 收集指标数据
- **Exporter（导出器）**: 指标导出工具

### 指标类型
- **Counter（计数器）**: 只增不减
- **Gauge（仪表）**: 可增可减
- **Histogram（直方图）**: 分布统计
- **Summary（摘要）**: 带百分位数的统计

### PromQL 函数
- **rate()**: 计算速率
- **increase()**: 计算增量
- **sum()**: 求和
- **avg()**: 平均值
- **max()**: 最大值
- **min()**: 最小值
- **count()**: 计数
- **by**: 分组
- **without**: 排除标签

### 时间范围
- **[5m]**: 过去 5 分钟
- **[1h]**: 过去 1 小时
- **[1d]**: 过去 1 天

---

## 🔍 Jaeger 关键词

### 核心概念
- **Trace（追踪）**: 完整的请求链路
- **Span（跨度）**: 追踪中的一个操作
- **Service（服务）**: 微服务名称
- **Operation（操作）**: API 端点或函数
- **Tag（标签）**: Span 的元数据
- **Log（日志）**: Span 中的日志事件
- **Baggage（行李）**: 在追踪中传递的数据

### Span 类型
- **Client Span**: 客户端发起的操作
- **Server Span**: 服务器处理的操作
- **Internal Span**: 内部操作

### 追踪属性
- **TraceID**: 追踪的唯一标识
- **SpanID**: Span 的唯一标识
- **Parent SpanID**: 父 Span 的 ID
- **Duration**: 持续时间
- **Start Time**: 开始时间
- **Tags**: 标签集合

### 视图
- **Timeline View**: 时间线视图
- **Graph View**: 图形视图
- **Trace Comparison**: 追踪对比

---

## 📝 Logs 关键词

### 核心概念
- **Log Level（日志级别）**: DEBUG, INFO, WARN, ERROR
- **Structured Logging（结构化日志）**: JSON 格式日志
- **Log Aggregation（日志聚合）**: 集中收集日志
- **Log Query（日志查询）**: LogQL 查询语言

### Loki 概念
- **Stream（流）**: 日志流
- **Label（标签）**: 日志标签
- **Query（查询）**: LogQL 查询
- **Range Query（范围查询）**: 时间范围查询

---

## 🔗 整合概念

### 三支柱（Three Pillars）
- **Metrics（指标）**: 数值型数据
- **Logs（日志）**: 文本型数据
- **Traces（追踪）**: 请求链路数据

### 关联概念
- **Correlation（关联）**: 关联不同数据源
- **Context Propagation（上下文传播）**: TraceID 传递
- **Sampling（采样）**: 追踪采样率
- **Instrumentation（插桩）**: 代码埋点

### 最佳实践
- **Golden Signals（黄金信号）**: 延迟、流量、错误、饱和度
- **SLO/SLI（服务级别目标/指标）**: 服务质量指标
- **Error Budget（错误预算）**: 允许的错误率
- **Alert Fatigue（告警疲劳）**: 过多告警导致忽略

---

## 🎯 实践场景关键词

### 性能分析
- **Latency（延迟）**: 响应时间
- **Throughput（吞吐量）**: 处理能力
- **Bottleneck（瓶颈）**: 性能瓶颈
- **Slow Query（慢查询）**: 慢请求

### 问题排查
- **Root Cause（根本原因）**: 问题根源
- **Incident（事件）**: 故障事件
- **Postmortem（事后分析）**: 故障复盘
- **Debugging（调试）**: 问题调试

### 容量规划
- **Capacity Planning（容量规划）**: 资源规划
- **Scaling（扩缩容）**: 扩展或收缩
- **Resource Utilization（资源利用率）**: 资源使用率
- **Trend Analysis（趋势分析）**: 趋势分析

---

## 🛠️ 工具关键词

### Kubernetes 相关
- **Service Monitor**: Prometheus 服务发现
- **Pod Monitor**: Pod 监控
- **Scrape Config**: 抓取配置
- **Service Discovery**: 服务发现

### OpenTelemetry
- **OTEL**: OpenTelemetry 缩写
- **Instrumentation**: 插桩库
- **Collector**: 数据收集器
- **Exporter**: 数据导出器

---

## 📚 学习路径关键词

### 阶段 1: 基础
- 界面熟悉
- 基本查询
- 数据查看

### 阶段 2: 进阶
- 自定义仪表板
- 复杂查询
- 追踪分析

### 阶段 3: 实战
- 问题排查
- 告警设置
- 性能优化

### 阶段 4: 深入
- 架构理解
- 最佳实践
- 生产部署

---

## 💡 记忆技巧

### Metrics
- **C**ounter: 只增（Count up）
- **G**auge: 可增可减（Go up and down）
- **H**istogram: 分布（Histogram distribution）

### 三支柱
- **M**etrics: 数字（Numbers）
- **L**ogs: 文本（Lines of text）
- **T**races: 路径（Trail/Track）

### 工具记忆
- **G**rafana: **G**raphs（图表）
- **P**rometheus: **P**romQL（查询语言）
- **J**aeger: **J**ourney（旅程/追踪）




