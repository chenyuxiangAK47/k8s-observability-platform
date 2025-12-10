# Grafana Query Builder 使用指南

## 🚨 问题：Builder 模式的限制

### 为什么你的查询被限制？

你的查询：
```promql
rate(container_cpu_usage_seconds_total{namespace="microservices", pod=~"user-service.*"}[5m])
```

**问题原因：**
- Builder 模式**不支持正则表达式匹配**（`=~` 和 `!~`）
- Builder 模式只支持**精确匹配**（`=`）和**不等于**（`!=`）
- 当你使用 `pod=~"user-service.*"` 时，Builder 模式无法处理

---

## ✅ 解决方案

### 方法 1：切换到 Code 模式（推荐）

**步骤：**
1. 在 Grafana 查询编辑器中，找到 **"Builder"** 和 **"Code"** 标签
2. 点击 **"Code"** 标签
3. 直接在代码编辑器中输入你的查询：
   ```promql
   rate(container_cpu_usage_seconds_total{namespace="microservices", pod=~"user-service.*"}[5m])
   ```

**优点：**
- ✅ 支持所有 PromQL 语法
- ✅ 可以使用正则表达式
- ✅ 更灵活，功能完整

**缺点：**
- 需要了解 PromQL 语法

---

### 方法 2：在 Builder 模式中使用精确匹配

如果你必须在 Builder 模式中使用，可以：

**步骤：**
1. 在 **Metric** 下拉框中选择：`container_cpu_usage_seconds_total`
2. 在 **Label filters** 中：
   - 第一个过滤器：`namespace` = `microservices`
   - 第二个过滤器：`pod` = `user-service-xxx`（具体 Pod 名称）
3. 在 **Operations** 中添加 `rate()` 函数
4. 设置时间范围：`[5m]`

**限制：**
- ❌ 只能匹配单个 Pod，不能匹配所有 `user-service.*` 的 Pod
- ❌ 如果 Pod 名称变化，需要手动更新

**变通方法：**
- 为每个 Pod 创建单独的查询
- 或者使用变量（Variables）来动态选择 Pod

---

### 方法 3：使用 Grafana 变量（Variables）

创建一个变量来动态选择 Pod：

**步骤：**
1. 进入 Dashboard 设置 → Variables
2. 添加新变量：
   - **Name**: `pod`
   - **Type**: Query
   - **Data source**: Prometheus
   - **Query**: 
     ```promql
     label_values(container_cpu_usage_seconds_total{namespace="microservices"}, pod)
     ```
   - **Regex**: `user-service.*`（过滤出 user-service 相关的 Pod）
3. 在查询中使用变量：
   ```promql
   rate(container_cpu_usage_seconds_total{namespace="microservices", pod=~"$pod"}[5m])
   ```

**优点：**
- ✅ 可以动态选择 Pod
- ✅ 支持正则表达式（在变量定义中）

---

## 📊 Builder vs Code 模式对比

| 功能 | Builder 模式 | Code 模式 |
|------|------------|----------|
| 精确匹配 (`=`) | ✅ | ✅ |
| 不等于 (`!=`) | ✅ | ✅ |
| 正则匹配 (`=~`) | ❌ | ✅ |
| 正则不匹配 (`!~`) | ❌ | ✅ |
| 复杂函数 | 部分支持 | ✅ 完全支持 |
| 聚合函数 | 部分支持 | ✅ 完全支持 |
| 易用性 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| 灵活性 | ⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## 🎯 推荐做法

### 对于初学者
1. **先用 Builder 模式**学习基本查询
2. **遇到限制时切换到 Code 模式**
3. 逐步学习 PromQL 语法

### 对于进阶用户
1. **直接使用 Code 模式**
2. 利用 PromQL 的完整功能
3. 创建更复杂的查询

---

## 💡 实用技巧

### 技巧 1：在 Code 模式中使用自动补全
- 输入 `container_` 然后按 `Ctrl+Space` 查看可用指标
- 输入 `{` 查看可用标签
- 输入函数名查看函数参数

### 技巧 2：混合使用
- 在 Builder 模式中构建基础查询
- 切换到 Code 模式添加正则表达式
- 再切换回 Builder 查看可视化效果

### 技巧 3：保存常用查询
- 在 Code 模式中写好查询
- 添加到查询库（Query Library）
- 以后可以直接复用

---

## 🔧 你的具体查询解决方案

### 完整步骤（Code 模式）

1. **切换到 Code 模式**
   - 点击查询编辑器顶部的 **"Code"** 标签

2. **输入查询**
   ```promql
   rate(container_cpu_usage_seconds_total{namespace="microservices", pod=~"user-service.*"}[5m])
   ```

3. **如果需要按 Pod 分组显示**
   ```promql
   sum(rate(container_cpu_usage_seconds_total{namespace="microservices", pod=~"user-service.*"}[5m])) by (pod)
   ```

4. **如果需要计算所有 user-service Pod 的总和**
   ```promql
   sum(rate(container_cpu_usage_seconds_total{namespace="microservices", pod=~"user-service.*"}[5m]))
   ```

5. **如果需要显示为百分比（相对于 CPU 限制）**
   ```promql
   sum(rate(container_cpu_usage_seconds_total{namespace="microservices", pod=~"user-service.*"}[5m])) / 
   sum(kube_pod_container_resource_limits{namespace="microservices", pod=~"user-service.*", resource="cpu"}) * 100
   ```

---

## 📚 相关资源

- [PromQL 正则表达式文档](https://prometheus.io/docs/prometheus/latest/querying/basics/#regular-expressions)
- [Grafana Query Editor 文档](https://grafana.com/docs/grafana/latest/panels/query-a-data-source/use-expressions-to-manipulate-data/)
- [PromQL 函数参考](https://prometheus.io/docs/prometheus/latest/querying/functions/)

---

## ✅ 快速检查清单

- [ ] 理解 Builder 模式的限制
- [ ] 知道如何切换到 Code 模式
- [ ] 掌握基本的 PromQL 正则表达式语法
- [ ] 能够创建包含正则表达式的查询
- [ ] 了解何时使用 Builder，何时使用 Code

---

## 🎓 练习建议

1. **练习 1**: 在 Code 模式中创建你的查询
2. **练习 2**: 尝试不同的正则表达式模式
3. **练习 3**: 创建包含多个标签过滤器的查询
4. **练习 4**: 使用聚合函数处理结果

记住：**Code 模式是你的朋友**，当 Builder 模式不够用时，切换到 Code 模式！




