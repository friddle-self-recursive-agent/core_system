# Event — 变化通知

| 项 | 值 |
|---|---|
| K8s 对照 | Event 资源 + watch 通知 |
| 形态 | 短生命周期数据（内存队列 + 滚动归档），**不是文档对象**；队列由 dsh（core plugin）实现，类似 dsh 的 event 队列 |
| 作用域 | 全局命名空间（带来源标注） |
| 状态 | 定稿（终态制，rule.md） |

## 1. 定义

Event 是"世界变了"的一次通知。五种来源：Connector watch 外部变化、Metrics 阈值越线、定时巡检到点、Apply 写入完成、人工触发。

Event **只触发，不修改**：收到事件的反应永远是"触发一次 Workflow 对账"，对账结论才驱动动作。事件可丢、可重、可乱序——系统正确性不依赖它（P3 level-triggered）。

## 2. 边界

**是**：边沿信号 + 审计素材（归档后供观测面看"何时发生过什么"）。

**不是**：
- 不是状态：状态在文档（Status/MetricsInfo）；Event 是状态变化的**影子**；
- 不是指令：没有消费者"必须"做什么；dispatch 只是建议路由；
- 不是文档对象：不进文档库、不 权限系统 校验内容（只校验类型注册）。

## 3. 结构

```yaml
apiVersion: core/v1
kind: Event
metadata:
 name: evt-20261120-000123 # 唯一 id
spec: {}
status:
 type: ExternalChanged # Scheme.eventTypes 之一
 source: {kind: WorkService, name: gitlab, detail: "runner 标签变更"}
 involvedRef: {kind: ServiceInstance, name: developer-system/ci} # 路由按类型+involved/owner+scope
 at: 2026-11-20T10:00:00Z
 dedupKey: "gitlab:runner-label:sha256(...)" # 同因事件聚合
 level: debug | info | warn | error | fatal # Log 式等级（取代原 severity）
```

## 4. 生命周期

产生 → 去重（dedupKey+时间窗聚合，防风暴）→ 按 Scheme.dispatch 路由 → 触发对应 Workflow → 归档（保留 30d，critical 1y）。路由不到 → 死信 + 告警。

## 5. 与其他概念的关系

- Core 是总线；Scheme.dispatch 是路由表（按事件类型+owner/scope 直达， 起）；Connector.watch 是最大生产者。
- Event ≠ Apply：Apply 改文档并顺带产生 `DocApplied` Event；Event 本身永远不改任何东西。
- MetricsInfo 阈值判断后发 `MetricThreshold` Event——数据面到信号面的桥。

## 6. 设计规则

1. dedupKey 强调：同一因由的重复事件在窗口内合并（防外部抖动风暴；配合速率限制与 Workflow 侧冷却期——事件风暴的既有缓解不变）。
1b. **Level 强制**：每个事件必带 log 式等级；消费侧按 level 过滤（debug 默认不入库只进内存队列；fatal 必接 Notification）。
2. 事件不携带大负载：超过 1KB 的上下文放 Ref/DriftReport，Event 只带指针。
3. 消费者不允许"信任事件内容"，只允许"被叫醒后自己看现实"（P3 的落地）。
4. 死信必须可见：观测面死信计数是系统健康指标。
5. **AUTO 处理不了的出口=Escalate 事件**：auto 级 Agent 遇到权限外/能力外/重试耗尽——不自行硬扛，产生 `Escalate` Event（level=error），路由三路齐发：**owner-workflow**（按其 onEscalate 策略决定是否暂停，见 workflow.md）+ **root 上报** + **Notification 送达 Bind role 持有者**。事件只触发不修改——暂停与否是 Workflow 引擎按策略执行的动作，不是事件自带的。
5. **死信熔断要做**：死信率超阈值自动熔断该源（暂停 watch+告警），防止事件风暴拖垮引擎；恢复=人工或冷却后自动半开试探。
6. **dispatch 表 `for:` 谓词机读口径（首段，订阅面 v0.12）**：谓词=`any` 或 `<selector>:<pattern>`（selector ∈ owner/scope）。`any`、`owner:*` 恒命中；`scope:<root>/*` 前缀式命中 involved scope（scope 是路径：global、builtin、systems/<s>，路径=scope）；**`owner:<字面量>` 首段不解析**（owner 解析属引擎主体：involved scope 根 `systems/<s>`→`<s>`，global/builtin 同名）——未激活的行不命中、事件顺延后行。命中=表序首个（`on` 匹配类型 ∧ 谓词命中）行，其 `route:` 即命中行投影（执行=派发，引擎主体）；全表未命中 → `route=dead-letter`（rule 4 死信兜底可见）。订阅集合=表 `on:` 值去重；含 `on: "*"` → 坍缩为单条全类型订阅（通配已覆盖枚举）。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 事件风暴 | ⚠️ 中 | 外部抖动/告警雪崩 | dedupKey 聚合 + 速率限制 + Workflow 冷却期 |
| 事件丢失导致迟收敛 | ⚠️ 低 | 纯边沿会漏 | 定时巡检兜底（level-triggered 的保险丝）：最迟 N 分钟全量对账一次 |
| 内存队列重启丢事件 | ⚠️ 低 | 同上 | 巡检兜底 + 归档落盘 |

**结论：可行。k8s 已验证的模式，加去重与巡检兜底。**

## 8. 待决问题

见 open-questions.md#event

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
