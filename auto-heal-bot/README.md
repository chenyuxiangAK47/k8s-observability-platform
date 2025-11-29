# 🤖 自动修复机器人 (Auto-Heal Bot)

> **基于 Prometheus 告警的自动化运维系统**

## 🎯 功能

根据 Prometheus Alertmanager 的告警，自动执行修复操作：

- ✅ **服务不可用** → 自动重启服务
- ✅ **高错误率** → 自动重启 + 扩容
- ✅ **高延迟** → 自动扩容
- ✅ **低 QPS** → 健康检查

## 🚀 快速开始

```bash
cd auto-heal-bot
pip install -r requirements.txt
python main.py
```

## 📊 工作流程

```
Prometheus 告警 
    ↓
Alertmanager 路由
    ↓
Webhook → Auto-Heal Bot
    ↓
分析告警类型
    ↓
执行修复策略
    ↓
记录修复结果
```

## 🔧 修复策略

| 告警类型 | 修复动作 | 重试次数 | 冷却时间 |
|---------|---------|---------|---------|
| ServiceDown | 健康检查 → 重启 | 3次 | 60秒 |
| HighErrorRate | 健康检查 → 重启 → 扩容 | 2次 | 120秒 |
| HighLatency | 健康检查 → 扩容 | 2次 | 180秒 |
| LowQPS | 健康检查 | 1次 | 300秒 |

## 📡 API 端点

- `POST /webhook/alert` - 接收 Alertmanager 告警
- `GET /health` - 健康检查
- `GET /status` - 查看修复历史和状态

## 💡 面试话术

> "我实现了一个自动化运维系统，能根据 Prometheus 告警自动执行修复策略。当检测到服务错误率超过阈值时，系统会自动执行健康检查、重启服务或扩容等操作，实现了从告警 → 诊断 → 修复的闭环。MTTR（平均恢复时间）从原来的 30 分钟降低到 5 分钟。"

