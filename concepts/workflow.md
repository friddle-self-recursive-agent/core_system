# Workflow — 执行态机（绑定给 ConnectorOps）

| 项 | 值 |
|---|---|
| K8s 对照 | Pod 的 phase 容器状态机 + Job 的 completion 语义（声明式相位） |
| 形态 | 对象：`global/workflows/<name>.yaml`；builtin 若干 |
| 作用域 | Global（builtin）/ System |
| 状态 | 设计稿 v0.3（R2 新增，A26） |

## 1. 定义

Workflow 是**执行的生命周期态机**：相位集合、相位间迁移、每相位允许的动作、失败出路。每个 ConnectorOps 必绑定一个 Workflow——op 的每次调用都是该 Workflow 的一次实例化运转（不是裸调用）。

builtin 默认态机（即 Agent 任务态机，全系统缺省）：

```
Idle → (派发) Analyzing → Planning → [Policy命中→AwaitingApproval→人批/驳回]
     → Executing → Verifying → Reporting → Idle
任意态 → Failed → backoff 重试 → 超限 Escalate（Bind 的人）→ Idle
```

与 TaskScheme 的分工：**Workflow 管相位（什么时候允许干什么），TaskScheme 管步骤（Executing 相位内具体跑什么）**。TaskScheme 的步骤序列总是在某个 Workflow 的 Executing 段内执行。

## 2. 边界

**是**：态机声明（相位/迁移/onFailed 策略）；builtin 有默认集。

**不是**：
- 不是可执行编排（无业务 if-else——那是反模式清单第 1 条；迁移条件只有事件与策略）；
- 不是 WorkflowDesign 文档（那是给人看的功能流**设计**，doctypes 声明侧；本概念是机器执行的**态机**——同名不同物，A26 备注）；
- 不是 Loop（Loop 管系统级对账节拍；Workflow 管单次调用/任务的相位）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Workflow
metadata:
  name: default-task
  scope: global
  labels: {core/builtin: "true"}
spec:
  phases: [Idle, Analyzing, Planning, AwaitingApproval, Executing, Verifying, Reporting, Failed]
  transitions:
    - {from: Idle,         on: dispatch,   to: Analyzing}
    - {from: Analyzing,    on: done,       to: Planning}
    - {from: Planning,     on: policyHit,  to: AwaitingApproval}
    - {from: AwaitingApproval, on: approved, to: Executing}
    - {from: AwaitingApproval, on: rejected, to: Reporting}   # 驳回也留痕
    - {from: Planning,     on: noDrift,    to: Reporting}
    - {from: Executing,    on: done,       to: Verifying}
    - {from: Verifying,    on: pass,       to: Reporting}
  onFailed:
    backoff: 30s*2^n
    maxAttempts: 3
    escalate: {to: bind, sla: 4h}      # 超限 Escalate（Bind 的人）→ 处理后回 Idle
  phaseBudget: {Analyzing: 5m, Planning: 5m, Executing: 20m, Verifying: 10m}
```

builtin 首批：`default-task`（上述全态机）、`simple-shot`（Idle→Executing→Reporting，简单派发用）、`watch-only`（常驻观察无 Executing）。

## 4. 生命周期

注册（builtin 或系统自定义，经 Apply）→ 被 ConnectorOps/Agent 引用 → 相位运转记录进 SessionLog（每次会话）→ 版本演进只加不改（相位语义变更需新版本名）。

## 5. 与其他概念的关系

- ConnectorOps.spec.workflow 必填（缺省 default-task）。
- Agent 任务态机（agent.md §4）= default-task Workflow 的直接引用，不再单独定义。
- Escalate 出口接 Bind 与 Notification（concepts/notification.md）。
- AwaitingApproval 的进入条件来自 Policy；批准动作=人经 console/Apply。

## 6. 设计规则

1. 相位/迁移必须是纯声明（无脚本）；迁移 on 事件取自 Scheme 注册的事件类型。
2. 每相位有预算；超预算=该次 Failed（进 onFailed）。
3. 态机运转全程写 SessionLog（Instance 内，见 agent.md v0.3）——态机可回放。
4. builtin Workflow 修改属 Builtin 级准入。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 态机表达能力 vs 复杂现实 | ⚠️ 中 | 现实流程常有分支 | 分支=不同 Workflow/或回 onFailed；复杂"流程编排"明确不支持（反模式），那是即兴的温床 |
| 与 TaskScheme 双层概念混淆 | ⚠️ 中 | 使用者易混 | 一句话：Workflow=相位，TaskScheme=步骤；TaskScheme 引用其宿主 Workflow 的 Executing 段 |

**结论：可行。标准有限状态机声明，风险在纪律不在技术。**

## 8. 原始设计标注

- A26（R2）：新增概念；与 WorkflowDesign（设计文档）、TaskScheme（步骤图）三方边界已定。

## 9. 待决问题

见 open-questions.md#workflow

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
