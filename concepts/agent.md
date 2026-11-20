# Agent — 执行与收敛单元

| 项 | 值 |
|---|---|
| K8s 对照 | Pod/Job（执行体）+ 其 controller 的收敛意识 |
| 形态 | 全局一等对象（**不是** Instance 的内嵌字段，A3） |
| 作用域 | Global（builtinRoot 为 Builtin） |
| 状态 | 设计稿 v0.3（R2 修正：AUTOLEVEL、Session 记录制、Provider、子 agent 机器级） |

## 1. 定义

Agent 是干活的最小自治单元：领任务 → 按需加载文档 → 分析 → 计划 →（按级别询问）→ 执行 → 验证 → 回写 → 记录。它没有自己的意图，**它的意图就是它被绑定的文档**；管 Agent 不靠盯它，靠改它绑定的文档。

**默认实现（R2 强调）**：Agent = 现有 agent + 程序中调用 LLM 来处理，模拟实现需求功能。默认运行时是 **DSH**——系统把自己做到 DSH 里：每个 Agent 就是一个 dsh 进程会话。**dsh agent 派发子 dsh agent 时，子 agent 是机器 instance 级的独立进程（不是 dsh 内部的 subagent）**——不共享进程状态、不省内存（明确接受资源开销，换取隔离与直控）。也可以派发**简单任务**（simple-shot Workflow）；**子 agent 用什么（工具/通道/账号）在 ConnectorOps 中描述**（connector.md：Agent 引用 ops，ops 声明环境与工具）。

**文档按需加载**：Agent 自己按需加载相应文档——由 dsh 本次会话自己实现（会话内决定读什么），不是外部装配强灌。Loop 只派任务与预算。

两类：

- **builtinRoot**（RootAgent）：根 Agent，Builtin scope，管理 Core、Scheme 与其他 Agent 的生死。不可删除、不可停用（权限系统 硬编码兜底）。
- **ServiceAgent**：普通 Agent，被 ServiceInstance 引用而参与收敛；可挂 Parent/Sub 树（父子=机器级进程派发 + owner 链）。

## 2. 边界

**是**：读文档做判断的执行者；权限面=引用的 ConnectorOps + Ref + Provider + Bind 的并集，再被 权限系统 裁剪（P7）。

**不是**：
- 不是文档的作者：它不篡改 Spec（P6 不变）；其运转以**记录**留痕（见 §6 规则 1）而非逐写审批；
- 不是连接器（它调 ConnectorOps，不自己写胶水代码）；
- 不是 Instance 的属性（A3：全局对象，被引用）；
- 不是常驻守护（按任务拉起；常驻节拍是 Loop 引擎的事）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Agent
metadata:
  name: ci-repair-agent
  scope: global
  labels: {tier: exec, domain: ci}
  ownerRefs: [{kind: Agent, name: dev-ops-root}]     # ParentAgent（owner.md）
spec:
  runtime: dsh                          # 默认 DSH（R2）
  autoLevel: auto                       # AUTOLEVEL：ask | auto | all（§3.1）
  connectorOps:                         # 默认挂 ConnectorOps（不是 Provider 类型）
    - {ops: onedev-ci, as: onedev}      # 子 agent 用什么在这里描述（ops 声明工具与环境）
  providers:                            # Provider 绑定：API 账号/接口（concepts/provider.md）
    - provider/llm-main
  refs: [ref/jenkins-docs]
  roles: [role/ci-approver]             # v0.13 A49：对象挂 role（Role.on 反向引用；此处为提示性冗余）
  escalate: root                        # 默认上溯 root agent；挂了 role 则双通道同达（A35）
  docs权限系统:
    read:  [{scope: systems/developer-system/*}]
    onDemand: true                      # 按需加载：dsh 会话自实现（R2）
  subAgents:
    - {name: ci-verifier, spawn: machine-instance}   # 机器级子进程，非 dsh 内部 subagent
  retry: {maxAttempts: 3, backoff: 30s*2^n, escalateTo: root}   # v0.4：默认 root，bind 可选插入（A35）
status:                                 # 由 Loop 引擎回写
  phase: Idle | Analyzing | Planning | AwaitingApproval | Executing | Verifying | Reporting | Failed
  workflow: default-task                # 当前运转的 Workflow（agent.md 任务态机=default-task）
  currentSession: {id, startedAt, docsLoaded: [...]}
  conditions:
    - {type: Healthy, status: "True", reason: heartbeat-ok}
```

### 3.1 AUTOLEVEL（智能/自治级别）

| 级别 | 语义 |
|---|---|
| `ask` | 动作前问上级：上级 agent（有 parent 时）或 Bind 的人 |
| `auto` | 白名单/Scheme/预算内自动执行；出界或失败升级 |
| `all` | 全自动不询问（仅显式授权给低风险封闭域） |

**默认级别（R2 指定，可按 Desc 调整）**：

| Agent | 默认 AUTOLEVEL | 理由 |
|---|---|---|
| RootAgent（builtinRoot） | `ask` | 管的是 builtin 与其他 agent 生死，无上级→问 Bind 的人 |
| ServiceAgent | `auto` | 常规任务在 TaskScheme+预算内自动；高危仍被 权限系统 拦 |

`all` 永远需要显式声明 + 权限系统 放行（P8：模型越强，级别可上调，机制不变）。

## 4. 生命周期（= Workflow `default-task`）

任务态机即 builtin Workflow（concepts/workflow.md §1），Agent 不自定义态机，只引用：

```
Idle → (派发) Analyzing → Planning → [权限系统命中→AwaitingApproval→人批/驳回]
     → Executing → Verifying → Reporting → Idle
任意态 → Failed → backoff 重试 → 超限 Escalate（Bind 的人）→ Idle
```

简单派发走 `simple-shot`（Idle→Executing→Reporting）。任务幂等可重入：任务带 taskId 与断点，Agent 崩溃后由 Loop 重新派发续跑。

## 5. 与其他概念的关系

- 被 ServiceInstance **引用**（agentRefs），被 Loop 引擎派发任务。
- 经 ConnectorOps 打外部（工具与环境在 ops 声明）；经 Provider 拿账号；Bind 是 role 绑定（人经用户系统解析，A34）；Escalate 默认上溯 root，有 Bind 则 role 持有者同达（Notification 送达，A35）。
- 子 agent：机器 instance 级独立 dsh 进程，由父经 control plugin 直控（plugin.md）；权限=父权限裁剪（agent 继承只减不增）。
- builtinRoot 的删除/禁用请求一律 权限系统 拒绝（硬编码）。

## 6. 设计规则（v0.3 修订）

1. ~~Agent 一切写操作经 Apply，违者 权限系统 拒绝~~ **（R2 取消，A29）**。替代：**Agent 的每一次 PLAN、以及每完成一次 Session（看实现粒度），必须记录文档，记在 ServiceInstance 里**（PlanDoc / SessionLog，doctypes 实现侧）。记录写入走 Apply（存储机制），但这是"事后留痕"，不是逐写审批。
2. 文档按需加载由 dsh 会话自己实现（docs权限系统.onDemand）；Loop 只保证 L0 最低必载（Goal.acceptance + Rule 摘要）。
3. 使用 ConnectorOps 要权限（ops 并集 + 权限系统 裁剪，P7 落点）；`undo:none` 的 ops 每次调用人审。
4. 子 agent 一律机器级进程派发（spawn: machine-instance），禁用 dsh 内部 subagent 共享进程——隔离与直控优先于内存开销（R2 明确"不要管浪费内存"）。
5. SubAgent 权限=Parent 裁剪，只减不增；环状父子拒绝入库。
6. AUTOLEVEL 变更走 Apply+权限系统（提权动作）；`all` 需显式授权。
7. builtinRoot 不可删（硬规则不变）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| LLM 不保证收敛 | ❗高（机制兜底） | 修复可能失败/震荡/越改越坏 | Workflow onFailed（backoff+上限）+ dry-run + undo + Escalate（A6 结论不变） |
| Session 记录被省略 | ⚠️ 中 | "看实现"的粒度容易松 | PlanDoc/SessionLog 为 Instance 必备 docType；缺记录=drift（Loop 对账） |
| 机器级子进程开销 | ⚠️ 低（已接受） | 每 agent 一进程，内存翻倍 | R2 明确接受；换取崩溃隔离+直控+无共享状态 |
| 按需加载读漏关键约束 | ⚠️ 中 | 会话自主决定读什么可能漏 Rule | L0 最低必载由 Loop 注入（规则 2）；SessionLog 记录 docsLoaded 可审计"读了什么" |
| Provider/ops 引用膨胀 | ⚠️ 低 | 权限面变大 | 并集+权限系统 裁剪不变；无引用 Provider 告警 |

**结论：可行。v0.3 放松了写路径管制、换上"记录+分级"治理——与 AUTOLEVEL 一样，都是 P8（机制不假设模型能力）的落地。**

## 8. 原始设计标注

- A29（R2）：取消"一切写经 Apply"；Plan/Session 记录制。
- A30（R2）：AUTOLEVEL 三级 + Root/Service 默认级别。
- A31（R2）：子 dsh agent 为机器级进程（非内部 subagent）。
- A3/A16/A21 沿用；connectors 字段改为 connectorOps（A25）。

## 9. 待决问题

见 open-questions.md#agent

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
