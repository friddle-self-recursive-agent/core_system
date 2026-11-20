# ServiceInstance — 声明的现实化

| 项 | 值 |
|---|---|
| K8s 对照 | Pod（运行实例 + status + 探针数据） |
| 形态 | ServiceDesc 目录下的 `instances/<name>/` 子目录 |
| 作用域 | 隶属某个 ServiceDesc（owner） |
| 状态 | 设计稿 v1 |

## 1. 定义

ServiceInstance 是一个 ServiceDesc 在现实世界的**一次落地**及其证据：谁（Agent 引用）按什么方式（实现侧 Docs）实现了声明的功能、现实运行数据（MetricsInfo）如何、与声明的差距（Status/DriftReport）多少。

Desc 回答"应该是什么"，Instance 回答"我现在是怎么实现/保障的，以及现实测得什么"。

## 2. 边界

**是**：
- **Agent 引用**（agentRefs，A3）：本实例由哪些 Agent 负责收敛；
- **实现侧 Docs**：ImplDoc（我怎么实现这些功能）+ VerifyDoc（我怎么约束/保障/验证）；
- **MetricsInfo**：采集到的现实数据（A17：数据不是文档，见 §3）；
- **Status**：Conditions、observedGeneration、drift 摘要——现实压缩回文档的标准形态。

**不是**：
- 不改意图：发现 Spec 该改 → 走提案 Event，不改 Spec（P6）；
- 不是外部系统（外部是 WorkService，A11）；
- MetricsInfo 不是 .md 文档：数据落 metrics/ 数据区或 TSDB 引用，文档里只存"查询入口声明"。

## 3. 对象结构

```yaml
# systems/developer-system/instances/ci/instance.yaml
apiVersion: core/v1
kind: ServiceInstance
metadata:
  name: developer-system/ci
  ownerRefs: [{kind: ServiceDesc, name: developer-system}]   # 级联
spec: {}                       # v1：实例无独立 Spec，完全跟随 owner Desc（简化）
status:
  observedGeneration: 12       # 已收敛到的 Desc 代数
  phase: InSync | Drifting | Remediating | Failed | Escalated
  drift:
    summary: "3 项偏差：runner 数不足/1 条 rule 未满足/…"
    reportRef: docs/drift-2026-11-20.md     # DriftReport 文档（Loop 生成）
  conditions:
    - {type: Ready,        status: "False", reason: runners-shortage}
    - {type: RulesHeld,    status: "True"}
    - {type: MetricsFlow,  status: "True"}
agentRefs: [agent/ci-repair-agent, agent/ci-verifier]
docs:
  impl:  docs/how-ci-works.md        # ImplDoc：如何实现
  verify: docs/how-ci-is-guaranteed.md # VerifyDoc：如何保障/验证
metricsInfo:                          # A17：查询入口声明，非数据本体
  store: tsdb/prometheus-main
  queries:
    runners: "sum(ci_runners_active)"
    p95:   "histogram_quantile(0.95, ...)"
```

## 4. 生命周期

```
由 Desc 的 instances 段声明 → Loop 创建 → 持续对账（Drifting↔InSync↔Remediating）
→ Failed（重试超限）→ Escalated（等 Bind 的人）→ 人介入后恢复
随 owner Desc 删除而级联删除（Finalizer 先清外部副作用）
```

## 5. 与其他概念的关系

- owner 是 ServiceDesc；引用全局 Agent；MetricsInfo 指向观测面存储。
- DriftReport 是 Instance 侧最重要的产物：它既是 Loop 的分析输出，也是下一次任务的压缩上下文（防上下文膨胀的关键层）。

## 6. 设计规则

1. Instance 目录里允许存在的文档类型白名单：ImplDoc、VerifyDoc、DriftReport、Runbook（按 DocType 注册）。
2. Status 只由 Loop/Agent 经 Core 回写，人写 Policy 拒绝（P2）。
3. MetricsInfo 只存查询声明与最近摘要（如 24h 概要），原始序列在观测面。
4. 一个 Instance 的 Agent 集合变更 = 实例配置变更，走 Apply。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 实现侧 Docs 腐化 | ⚠️ 中 | 代码改了文档没改，ImplDoc 说谎 | ImplDoc 与 Connector 版本号联动校验；Loop 对账把"文档过期"也当作一种 drift |
| MetricsInfo 与文档的边界被侵蚀 | ⚠️ 中 | 图省事把数据写进 .md | Policy Lint：Instance 下 .md 出现指标序列表即警告 |
| 多实例语义 | ⚠️ 低 | v1 无实例级 Spec，实例间只差名字 | 如需差异化，升级为实例级 Spec 覆盖（overlay），列入 open-questions |

**结论：可行。ImplDoc 防腐化是长期工程问题，机制上以"文档过期=drift"兜住。**

## 8. 原始设计标注

- A3：内嵌 Agent → agentRefs 引用。
- A17：MetricsInfo 定为"数据+查询声明"，不进文档对象库。
- 原稿"DOCS[我怎么实现这些功能的。怎么进行约束保障的]" → 拆为 ImplDoc + VerifyDoc 两类。

## 9. 待决问题

见 open-questions.md#serviceinstance

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
