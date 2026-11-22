# Agent — 执行与收敛单元

| 项 | 值 |
|---|---|
| K8s 对照 | Pod/Job（执行体）+ 其 controller 的收敛意识 |
| 形态 | 全局一等对象（不是 Instance 的内嵌字段） |
| 作用域 | Global（builtinRoot 为 Builtin） |
| 状态 | 定稿（终态制，rule.md） |

## 1. 定义

Agent 是干活的最小自治单元：领任务 → 按需加载文档 → 分析 → 计划 →（按级别询问）→ 执行 → 验证 → 回写 → 记录。它没有自己的意图，**它的意图就是它被绑定的文档**；管 Agent 不靠盯它，靠改它绑定的文档。

**默认实现**：Agent = 现有 agent + 程序中调用 LLM 来处理，模拟实现需求功能。默认运行时是 **DSH**——系统把自己做到 DSH 里：每个 Agent 就是一个 dsh 进程会话。**派发子 agent 时，子 agent 是机器 instance 级的独立进程（不是运行时内部的 subagent）**——不共享进程状态、不省内存（明确接受资源开销，换取隔离与直控）。**子 agent 的运行时不限于 dsh**：自写 agent、opencode 等任何 agent 运行时都可以——用什么运行时、什么工具、什么通道账号，一律在其引用的 **ConnectorOps 中描述或调用**（connector.md：Agent 引用 ops，ops 声明环境与工具；spawn 子 agent 本身也是一次 ConnectorOps 调用，与调外部工具同一语义）。简单任务派发走 simple-shot Workflow。

**文档按需加载**：Agent 自己按需加载相应文档——由 dsh 本次会话自己实现（会话内决定读什么），不是外部装配强灌。Workflow 只派任务与预算。

**一个 Service 一个 Agent**：每个 Service（系统）一个负责 Agent（ServiceAgent）；**Agent↔Service 沟通协议的完整设计见 instance 仓 runtime/agent-service-protocol.md**。要点：
- **上下文预插入**：Agent 处理意图时，Service 内资源按上下文先插入"大概描述"（资源清单+关系摘要），Agent 据此**自行导入**相关内容（文档按需加载不变）；
- **Service 内 Agent 信息不隔离**：不做 SubAgent 级信息隔离——ServiceAgent 自己判断读什么、给谁看；
- **一个意图 = 一次 session**（session 粒度=意图，不是消息）；
- Service 可在运行中**提议更新文档**（提议理论上都应落在 Docs 中），也可**在运行时提交 Ref 类型**记录（解析到的资源随手入册）；
- **默认记忆系统就在 Service 的文档管理中**：Agent 的记忆（经验/偏好/上下文延续）以文档形式存 Service 文档域（Memory DocType），随 docs_operator 管理——不建独立记忆库。

**默认 Skill（系统文档查询）**：agent 被调用（root/上游派任务）时，默认把"查本系统"作为 skill 喂给它——一组命令式工具（按 scope/name/DocType 取文档与文档信息、读 Status/最近事件），agent 靠调用命令获取文档与文档信息，不靠记忆猜。该 skill 属 builtin 基础循环调用代码（concepts/builtin.md），随代码自带、自动生效。

**检索（简单 RAG，分页）**：Session/Doc/TaskScheme 更新时由 LLM **自动打 tag + 评判重要程度**（tags[]/importance 1-5/一句话标题描述——conventions.tags，scheme.yaml）。Agent 查历史靠检索工具（tag 过滤+重要度×时间衰减排序），**一律分页**：默认每页 10 条（可调），列表只给 `[标题+简单描述+重要度+时间]`，Agent 按需拉全文。**结果不对就继续找**：换 tag/翻页迭代（工具与提示词见 instance 仓 runtime/agent-session.md §5）——不导入全量。

两类：

- **builtinRoot**（RootAgent）：根 Agent，Builtin scope，管理 Core、Scheme 与其他 Agent 的生死。**有权限标志**：挂内置 role `global/admin`（最高权限、默认内置、绑定不可更改），走统一权限管理，无旁路。**AUTOLEVEL 与普通 Agent 同一机制**：autoLevel 可配置（默认 ask，也可 auto/all，all 需显式授权，A64）。不可删除、不可停用（权限系统硬规则兜底）。
- **ServiceAgent**：普通 Agent，被 ServiceInstance 引用而参与收敛；可挂 Parent/Sub 树（父子=机器级进程派发 + owner 链）。

## 2. 边界

**是**：读文档做判断的执行者；权限面=引用的 ConnectorOps + Ref + Provider + Role 挂载的并集，再被权限系统裁剪（P7）。

**不是**：
- 不是文档的作者：它不篡改 Spec（P6 不变）；其运转以**记录**留痕（见 §6 规则 1）而非逐写审批；
- 不是连接器（它调 ConnectorOps，不自己写胶水代码）；
- 不是 Instance 的属性（全局对象，被引用）；
- 不是常驻守护（按任务拉起；常驻节拍是 Workflow 引擎的事）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Agent
metadata:
 name: ci-repair-agent
 scope: global
 labels: {tier: exec, domain: ci}
 ownerRefs: [{kind: Agent, name: dev-ops-root}] # ParentAgent
spec:
 runtime: dsh # rootAgent 默认=dsh 的 plugin；子 agent 看实现：可自写 go agent、直接调 opencode、或继续 dsh（经 ConnectorOps 描述）
 autoLevel: auto # AUTOLEVEL：ask | auto | all（§3.1）
 connectorOps: # 默认挂 ConnectorOps（不是 Provider 类型）
 - {ops: onedev-ci, as: onedev} # 子 agent 用什么在这里描述（ops 声明工具与环境）
 providers: # Provider 绑定：API 账号/接口（concepts/provider.md）
 - provider/llm-main
 refs: [ref/jenkins-docs]
 roles: [role/ci-approver] # ：对象挂 role（Role.on 反向引用；此处为提示性冗余）
 escalate: root # 默认上溯 root agent；挂了 role 则双通道同达
 docs权限系统:
 read: [{scope: systems/developer-system/*}]
 onDemand: true # 按需加载：dsh 会话自实现
 subAgents:
 - {name: ci-verifier, spawn: machine-instance} # 机器级子进程；运行时不限 dsh（opencode/自写 agent 均可），派发/调用经 ConnectorOps 描述
 retry: {maxAttempts: 3, backoff: 30s*2^n, escalateTo: root} # ：默认 root，bind 可选插入
status: # 由 Workflow 引擎回写
 phase: Idle | Analyzing | Planning | AwaitingApproval | Executing | Verifying | Reporting | Failed
 workflow: default-task # 当前运转的 Workflow（agent.md 任务态机=default-task）
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

**默认级别**：

| Agent | 默认 AUTOLEVEL | 理由 |
|---|---|---|
| RootAgent（builtinRoot） | `ask`（默认，可配置） | 与普通 Agent 同一机制：Root 也可配 auto/all（all 需显式授权）；ask 时无上级→问 Bind 的人 |
| ServiceAgent | `auto` | 常规任务在 TaskScheme+预算内自动；高危仍被 权限系统拦 |

`all` 永远需要显式声明 + 权限系统 放行（P8：模型越强，级别可上调，机制不变）。

## 4. 生命周期（= Workflow `default-task`）

任务态机即 builtin Workflow（concepts/workflow.md §1），Agent 不自定义态机，只引用：

```
Idle → (派发) Analyzing → Planning → [权限系统命中→AwaitingApproval→人批/驳回]
 → Executing → Verifying → Reporting → Idle
任意态 → Failed → backoff 重试 → 超限 Escalate（Bind 的人）→ Idle
```

简单派发走 `simple-shot`（Idle→Executing→Reporting）。任务幂等可重入：任务带 taskId 与断点，Agent 崩溃后由 Workflow 重新派发续跑。

## 5. 与其他概念的关系

- 被 ServiceInstance **引用**（agentRefs），被 Workflow 引擎派发任务。
- 经 ConnectorOps 打外部（工具与环境在 ops 声明）；经 Provider 拿账号；Bind 是 role 绑定（人经用户系统解析）；Escalate 默认上溯 root，有 Bind 则 role 持有者同达（Notification 送达）。
- 子 agent：机器 instance 级独立进程，**运行时不限于 dsh**（自写 agent、opencode 等均可），派发/调用经 ConnectorOps 描述或调用；由父经直控通道派发/中断/查询；权限=父权限裁剪（只减不增）。
- builtinRoot 的删除/禁用请求一律 权限系统 拒绝（硬编码）；其权限绑定（内置 role `global/admin`，A63）同样不可更改/换绑/降权。

## 6. 设计规则（ 修订）

1. Agent 的每一次 PLAN、以及每完成一次 Session（粒度看实现），必须记录文档，记在 ServiceInstance 里（PlanDoc / SessionLog）。记录写入走 Apply（存储机制）——事后留痕，不是逐写审批。
2. 文档按需加载由 dsh 会话自己实现（docs权限系统.onDemand）；Workflow 只保证 L0 最低必载（Goal.acceptance + Rule 摘要）。
3. 使用 ConnectorOps 要权限（ops 并集 + 权限系统裁剪，P7 落点）；`undo:none` 的 ops 每次调用人审。
4. 子 agent 一律机器级进程派发（spawn: machine-instance），禁用任何运行时内部的 subagent 共享进程——隔离与直控优先于内存开销。**子 agent 运行时不限于 dsh**（自写 agent、opencode 等皆可）；其派发与调用经 ConnectorOps 描述/调用，与调用外部工具同一语义。
5. SubAgent 权限=Parent 裁剪，只减不增；环状父子拒绝入库。
6. AUTOLEVEL 变更走 Apply+权限系统（提权动作）；`all` 需显式授权。
7. builtinRoot 不可删（硬规则不变）。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| LLM 不保证收敛 | ❗高（机制兜底） | 修复可能失败/震荡/越改越坏 | Workflow onFailed（backoff+上限）+ dry-run + undo + Escalate（ 结论不变） |
| Session 记录被省略 | ⚠️ 中 | "看实现"的粒度容易松 | PlanDoc/SessionLog 为 Instance 必备 docType；缺记录=drift（Workflow 对账） |
| 机器级子进程开销 | ⚠️ 低（已接受） | 每 agent 一进程，内存翻倍 | 已明确接受（架构决议）；换取崩溃隔离+直控+无共享状态 |
| 按需加载读漏关键约束 | ⚠️ 中 | 会话自主决定读什么可能漏 Rule | L0 最低必载由 Workflow 注入（规则 2）；SessionLog 记录 docsLoaded 可审计"读了什么" |
| Provider/ops 引用膨胀 | ⚠️ 低 | 权限面变大 | 并集+权限系统裁剪不变；无引用 Provider 告警 |

**结论：可行。本设计放松了写路径管制、换上"记录+分级"治理——与 AUTOLEVEL 一样，都是 P8（机制不假设模型能力）的落地。**

## 8. 待决问题

见 open-questions.md#agent

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
