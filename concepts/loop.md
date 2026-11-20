# Loop — 收敛引擎（一等机制对象）

| 项 | 值 |
|---|---|
| K8s 对照 | Controller / Reconciler（controller-runtime 的 reconcile loop） |
| 形态 | 可配置对象（挂 ServiceDesc/Instance），由 Core 内 Loop 引擎执行 |
| 作用域 | 隶属 ServiceDesc 或 Instance |
| 状态 | 设计稿 v1 |

> 命名说明：保留原稿"LOOP"词汇作为 Kind 名（它是本系统的核心卖点）；K8s 习惯叫 Controller/Reconciler，语义同源。详细管线见 instance 仓 loop/loop.md，本文件只定概念。

## 1. 定义

Loop 是"不停把现实拉齐到声明"的引擎，被显式声明为对象：触发源、节奏、重试、升级策略全部在文档里配置，而不是写死在代码。**每个 ServiceDesc 至少一个 Loop**（对应 K8s "每 CRD 一个 controller"）。

## 2. 边界

**是**：调度与状态机骨架——决定"何时对账、何时重试、何时升级"；具体"怎么分析、怎么修"由它派发的 Agent 读文档完成。

**不是**：
- 不是 Agent（Loop 不读业务文档、不做判断；它是节拍器，不是乐手）；
- 不是定时任务框架（cron 只是触发源之一，语义是收敛而非执行）；
-不含 if-else 业务编排（反模式清单第 1 条）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Loop
metadata:
  name: developer-system-main
  ownerRefs: [{kind: ServiceDesc, name: developer-system}]
spec:
  watch:                          # 触发源（A5 五种）
    events:  {selector: {domain: devtools}}
    timer:   {resync: 10m}        # 巡检兜底（level-triggered 保险丝）
    driftScan: {interval: 1h}     # 全量对账
  workers: 2                      # 并发对账数
  cooldown: 2m                    # 成功后最小间隔（防震荡）
  retry: {maxAttempts: 3, backoff: 30s*2^n}
  escalation:                     # 失败出路（A6）
    on: [retryExhausted, verifyFailed]
    to: bind/developer-system-owners
    sla: 4h
  safety:
    dryRunFirst: true             # 先 plan 预演再执行
    maxMutationsPerTick: 10       # 单轮最大变更数（刹车）
status:
  phase: Idle | Reconciling | CoolingDown | Backoff | Escalated
  lastRun: {at: ..., result: InSync|DriftFixed|Failed}
  consecutiveFailures: 0
```

## 4. 生命周期（实例级状态机）

```
Idle --(触发)--> Reconciling --> InSync --> CoolingDown --> Idle
                     |--> DriftFixed（已修）--> Verifying --> ...
                     |--> Failed --> Backoff（指数退避）--> Reconciling
                     └--> 重试耗尽/验证不过 --> Escalated（等人）--> 人处理后 --> Reconciling
```

## 5. 与其他概念的关系

- 引擎在 Core（提供调度/退避/并发原语），Loop 对象是每个系统的配置。
- 派发对象是 Instance 的 agentRefs。
- 产物：Instance.Status 更新 + DriftReport + Event。
- 与 Policy：执行前若命中风险规则，插入 ApprovalNeeded（AwaitingApproval 态）。

## 6. 设计规则

1. reconcile 函数必须幂等、纯调度视角（同一现实跑两遍结论一致）。
2. 每轮 reconcile 有预算（时间/token/变更数），超预算本轮作废重排——LLM 不确定性下的确定性护栏。
3. Escalated 是一等终态不是异常：等待人也是收敛路径的一部分。
4. Loop 对象自身变更走 Apply+Policy（改重试策略=改系统行为）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 震荡（修了又坏坏了又修） | ⚠️ 中 | 修复互相踩或与现实互踩 | cooldown + maxMutations 刹车 + DriftReport 记录"改过什么"避免重复同类修复 |
| 成本失控（token/外部 API 调用） | ⚠️ 中 | 高频触发×大上下文 | 预算制 + 分层上下文 + no-op 不计费巡检 |
| 多 Loop 交叉管同一对象 | ⚠️ 中 | 两系统 Loop 都去修 gitlab | 规则：变更走唯一 owner 的 Loop；跨系统诉求走 Apply 提案（apply.md §6.4） |

**结论：可行。全部风险都有经典工程解（刹车/预算/单写者），无研究性风险。**

## 8. 原始设计标注

- A6：补失败终止与震荡保护。
- 原稿 LOOP 管线逐句映射见 instance 仓 loop/loop.md §1。

## 9. 待决问题

见 open-questions.md#loop

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
