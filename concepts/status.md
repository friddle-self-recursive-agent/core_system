# Status — 现实压缩回文档的标准形态

| 项 | 值 |
|---|---|
| K8s 对照 | Status 子资源 / Conditions / observedGeneration |
| 形态 | 所有带状态对象的保留字段（`status:`），不是独立对象 |
| 作用域 | 跟随宿主对象 |
| 状态 | 设计稿 v1 |

## 1. 定义

Status 是"现实被压缩回文档"后的标准形态（P2 的右半边）。它回答三件事：

1. **收敛到哪了**：`observedGeneration`（Status 对应 Spec 的第几代）。
2. **现在什么状态**：`phase`（粗）+ `conditions`（细，带 reason）。
3. **差距是什么**：`drift`（摘要 + DriftReport 指针）。

```
收敛进度 = observedGeneration / generation
一致性   = phase == InSync
为什么   = conditions[].reason
```

## 2. 边界

**是**：机器可读的现实摘要，观测面与 Loop 的通用语言。

**不是**：
- 不是人写的内容（权限系统 拒绝人写 Status，P2）；
- 不是数据仓库（时间序列在 MetricsInfo；Status 只有"现在"）；
- 不是日志（过程细节在 DriftReport 与审计，Status 只有结论）。

## 3. 标准结构（所有对象共用）

```yaml
status:
  observedGeneration: 12
  phase: InSync            # 对账态机（loop.md §4）
  conditions:              # 细粒度，K8s 同款约定
    - type: Ready
      status: "True" | "False" | "Unknown"
      reason: runners-shortage     # 机器可枚举
      message: "需要 4 个 runner，实际 3 个"   # 人话
      lastTransitionTime: 2026-11-20T10:00:00Z
  drift:                   # 仅 Instance 必有
    summary: "..."
    reportRef: docs/drift-....md
```

## 4. 生命周期

由 Loop/Agent 经 Apply（fieldManager=系统）回写 → 变更即 Event（供观测面）→ 旧 Status 不保留历史（历史在 git 与 MetricsInfo）。

## 5. 与其他概念的关系

- DriftReport 是它的大文本附件（放 Instance docs）。
- Event 从它的变更产生；观测面以它为权威数据源。
- generation/observedGeneration 的差 = 待收敛工作量，是系统级健康指标。

## 6. 设计规则

1. `reason` 必须取自 Scheme 注册的枚举（可聚合计数）；`message` 随意。
2. conditions 类型集合按对象 Kind 注册（Instance 至少：Ready/RulesHeld/MetricsFlow）。
3. Status 写入权限唯一归属 Loop 引擎的 fieldManager。
4. 禁止把修复步骤写进 Status（那是 DriftReport/审计的事）——Status 只说"现在怎样"。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| Status 膨胀成小作文 | ⚠️ 低 | LLM 爱写字 | 模板校验（权限系统 Lint 字段长度/结构） |
| conditions 语义漂移 | ⚠️ 低 | 同一 reason 各写各的 | 枚举注册制（规则 1） |

**结论：可行。成熟约定照搬。**

## 8. 原始设计标注

- 原稿无此概念（A 类补充）：原稿"更新系统status等"有动作无形态，本概念补其形态。

## 9. 待决问题

见 open-questions.md#status

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
