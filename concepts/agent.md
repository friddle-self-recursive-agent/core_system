# Agent — 执行与收敛单元

| 项 | 值 |
|---|---|
| K8s 对照 | Pod/Job（执行体）+ 其 controller 的收敛意识 |
| 形态 | 全局一等对象（不是 Instance 的内嵌字段） |
| 作用域 | Global（builtinRoot 为 Builtin） |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. 定义

Agent 是干活的最小自治单元：领任务 → 按需加载文档 → 分析 → 计划 →（按级别询问）→ 执行 → 验证 → 回写 → 记录。它没有自己的意图，**它的意图就是它被绑定的文档**；管 Agent 不靠盯它，靠改它绑定的文档。

**默认实现**：Agent = 现有 agent + 程序中调用 LLM 来处理，模拟实现需求功能。默认运行时是 **DSH**——系统把自己做到 DSH 里：每个 Agent 就是一个 dsh 进程会话。**派发子 agent 时，子 agent 是机器 instance 级的独立进程（不是运行时内部的 subagent）**——不共享进程状态、不省内存（明确接受资源开销，换取隔离与直控）。**子 agent 的运行时不限于 dsh**：自写 agent、opencode 等任何 agent 运行时都可以——用什么运行时、什么工具、什么通道账号，一律在其引用的 **ConnectorOps 中描述或调用**（connector.md：Agent 引用 ops，ops 声明环境与工具；spawn 子 agent 本身也是一次 ConnectorOps 调用，与调外部工具同一语义）。简单任务派发走 simple-shot Workflow。

**两类形态（2026-11-27 用户裁决）：对话 agent 与后台执行（headless）agent，内置都用 DSH 实现**：

- **对话 agent**：与人对话的交互面——dsh 会话挂人（控制台对话面），多轮问答、可直接在会话内问人（挂起等人回话）；
- **后台执行 agent（headless）**：无人值守执行体——loop 自循环、Task 派发、Workflow run 的落地执行都由它承担（宿主 core-headless 拉起的 dsh 进程）；
- **两者的模式与询问不一致**：headless 没有在场的人——对话 agent「会话内直接问人」的词形在 headless 不成立（无人回话=死等）；headless 的询问一律走**两个默认工具**：**通知**（该让人知道的事送达，Notification 面）与**审批**（`ApprovalNeeded` 提升→`AwaitingApproval` 挂起→role 持有者批）——两工具**默认加入 headless agent 的 tools**（与「默认 Skill」同一 builtin 注入位）；
- **默认 Workflow 只可能是后台执行（headless）agent**：Workflow run 不落对话 agent（§4；workflow.md §5）；
- 与既有「两类」（builtinRoot/ServiceAgent）正交：那是 scope 分类，这是执行形态分类——每个 scope 类都可落 chat 或 headless 形态。

**三段式 Session 与上下文按需装配（R-CTX-4）**：一个逻辑意图/任务由**三段式 Session** 完成（统一原按需加载、Catalog 预插与 Tag-RAG）：
1. **第一段·获取上下文 Session（侦察段）**：预插**基础命令使用规范（默认查询 Skill）+ 顶层目录 Index（Service Catalog 货架摘要）**；先按任务 Tag 细粒度触发 `TagCtxShard` 缓存分片（可动态调整拿到的 `takeBudget`），仅对未命中/stale 的差量 Tag 自主调用检索命令拉取完整 Tag/TagRule、四族对象（Rule/Doc、Scheme、Provider、ServiceDesc）、近期关联 Event、**近期相关 Session** 及各对象 `importance (0-100)` 与 `Relevance(A,B) (0-100)`，产出 `ContextPack`；
2. **第二段·任务执行 Session（执行段）**：以 `ContextPack` 起步执行；**多轮对话与连续推进始终复用当前 Session 本身（保 Prefix KV Cache）**，按需触发任务缓存并支持中途动态增量更新（JIT 调用上下文工具补拉），记录每个引用块的真实归因轨迹（`used_effective / queried_irrelevant / missed_in_phase1`）；
3. **第三段·总结与演化 Session（异步后台段 + 独立审核 Agent 裁决）**：第二段结束即异步拉起（零主链路延迟），固定执行三件事：①对真实阻塞/规则冲突/实测不一致提 **Proposal**（先跑 `Relevance ≥ 85` 查重合并）；②**正向归因裁剪**生成/补充记忆缓存（`TagCtxShard` 与会话缓存）；③**防同质任务刷分的 Importance / TagRelevance Rerank**（叠加跨任务多样性折扣 $w_{\text{div}}$ 与界面人类审核评论因子 `humanScore`），产出必须经**另一独立审核 Agent（Judge Agent）**裁决通过后方可 Apply。

**一个 Service 一个 Agent**：每个 Service（系统）一个负责 Agent（ServiceAgent）；**Agent↔Service 沟通协议的完整设计见 instance 仓 runtime/agent-service-protocol.md**。要点：
- **第一段最小底座预插入**：Agent 处理意图时，第一段先注入基础命令规范与 Service 资源目录 Index（catalog 货架标签），优先触发 `TagCtxShard` 缓存分片，并对差量 Tag 自行拉取全文；
- **Service 内 Agent 信息不隔离**：不做 SubAgent 级信息隔离——ServiceAgent 自己判断读什么、给谁看；
- **一个意图 = 一个三段式逻辑 Session**（侦察段→执行段自复用→异步总结演化段）；
- Service 可在运行或第三段异步总结中**提议更新文档**（Proposal，先查重后提单），也可**在运行时提交 Ref 类型**记录（解析到的资源随手入册）；
- **默认记忆系统就在 Service 的文档管理与 CtxCache 中**：持久经验以文档形式存 Service 文档域（Memory DocType，SQLite `docs DB` 权威 + 定时导出 Git），会话热记忆落按 Tag 分片的 `CtxCache`（容量与提取大小均可调）。

**默认 Skill（系统文档与上下文查询）**：agent 被调用（root/上游派任务）时，默认把"查本系统与上下文"作为 skill 喂给它（第一段预插底座）——一组命令式工具（`context.find / pack / expand`、按 scope/name/DocType 取文档、读 Status/最近事件/近期相关 Session），agent 靠调用命令获取上下文，不靠记忆猜。该 skill 属 builtin 基础循环调用代码（concepts/builtin.md），随代码自带、自动生效。

**检索（Tag 核心 + 0–100 全局相关性公式）**：Session/Doc/TaskScheme 更新时自动维护 `tags[]`、`tagRelevance (0-100)`、`importance (0-100)`、可选 `humanScore (0-100)` 与 `digest`（导出侧车见 R-DOC-6）。检索与排序统一走全局相关性公式 `Relevance(A, B) ∈ [0, 100]`（非对称 Tag 覆盖率 + 亲和传播 + BM25 + 作用域先验），分页按需拉取，不导入全量。

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
 mode: headless # chat（与人对话）| headless（后台执行，缺省）——询问词形随 mode 分轨：chat 可会话内直接问人；headless 只走默认工具 通知+审批（默认 tools 注入）；默认 workflow 拒绑 chat agent
 subject: {user: builtin-user} # 执行主体身份 bind（2026-11-27 用户裁决：默认 agent 节点 bind 都 bind 内置的这个用户——user-system.md builtin 单用户+token 授权；缺省恒 builtin-user，ldap/sso 阶段才显式覆写）
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
 eventScopes: # 明确该 Agent 可消费/处理的 Event scope 范围（event.md 规则 19）
 - systems/developer-system
 - systems/developer-system/*
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
| `ask` | 动作前问上级：上级 agent（有 parent 时）或挂载 role 的人（经用户系统解析） |
| `auto` | 白名单/Scheme 内自动执行；出界或失败升级 |
| `all` | 全自动不询问（仅显式授权给低风险封闭域） |

**默认级别**：

| Agent | 默认 AUTOLEVEL | 理由 |
|---|---|---|
| RootAgent（builtinRoot） | `ask`（默认，可配置） | 与普通 Agent 同一机制：Root 也可配 auto/all（all 需显式授权）；ask 时无上级→问挂载 role 的人 |
| ServiceAgent | `auto` | 常规任务在 TaskScheme 内自动；高危仍被 权限系统拦 |

`all` 永远需要显式声明 + 权限系统 放行（P8：模型越强，级别可上调，机制不变）。

## 4. 生命周期（= Workflow `default-task`）

任务态机即 builtin Workflow（concepts/workflow.md §1），Agent 不自定义态机，只引用：

**执行载体=后台执行（headless）agent（2026-11-27 用户裁决）**：default-task 与一切 Workflow run 只落 `mode: headless` 的 agent；对话 agent（chat）不承载 Workflow——它是人的交互面。run 内的「问人」由 headless 默认工具承接：通知=Notification 送达面；审批=`AwaitingApproval` 闸锚挂起→role 持有者批（workflow.md 规则 13）。引擎派发时校验 `spec.mode`，默认 workflow 拒绑 chat agent。

```
Idle → (派发) Analyzing → Planning → [权限系统命中→AwaitingApproval→人批/驳回]
 → Executing → Verifying → Reporting → Idle
任意态 → Failed → backoff 重试 → 超限 Escalate（挂载 role 的人）→ Idle
```

简单派发走 `simple-shot`（Idle→Executing→Reporting）。任务幂等可重入：任务带 taskId 与断点，Agent 崩溃后由 Workflow 重新派发续跑。

## 5. 与其他概念的关系

- 被 ServiceInstance **引用**（agentRefs），被 Workflow 引擎派发任务。
- 经 ConnectorOps 打外部（工具与环境在 ops 声明）；经 Provider 拿账号；挂载 role 的人经用户系统解析；Escalate 默认上溯 root，有 role 挂载则 role 持有者同达（Notification 送达）。
- 子 agent：机器 instance 级独立进程，**运行时不限于 dsh**（自写 agent、opencode 等均可），派发/调用经 ConnectorOps 描述或调用；由父经直控通道派发/中断/查询；权限=父**一次性全量下发**（⊆父，只减不增；运行时缺权限直接 ask 上级，上级重新全量申请整包重发，见 workflow.md §7 委派模型）。
- builtinRoot 的删除/禁用请求一律 权限系统 拒绝（硬编码）；其权限绑定（内置 role `global/admin`，A63）同样不可更改/换绑/降权。

## 6. 设计规则（ 修订）

1. Agent 的每一次 PLAN、以及每完成一次 Session（粒度看实现），必须记录文档，记在 ServiceInstance 里（PlanDoc / SessionLog）。记录写入走 Apply（存储机制）——事后留痕，不是逐写审批。
2. 文档按需加载由 dsh 会话自己实现（docs权限系统.onDemand）；Workflow 只保证 L0 最低必载（Goal.acceptance + Rule 摘要）。
3. 使用 ConnectorOps 要权限（ops 并集 + 权限系统裁剪，P7 落点）；`rollback.type: irreversible`（或 `undo:none`，根本无法回滚）的 ops 每次调用人审。
4. 子 agent 一律机器级进程派发（spawn: machine-instance），禁用任何运行时内部的 subagent 共享进程——隔离与直控优先于内存开销。**子 agent 运行时不限于 dsh**（自写 agent、opencode 等皆可）；其派发与调用经 ConnectorOps 描述/调用，与调用外部工具同一语义。
5. SubAgent 权限=Parent 一次性全量下发（⊆父，只减不增；不做按步骤细粒度裁剪），运行时缺权限直接 ask 上级整包重发；环状父子拒绝入库。
6. AUTOLEVEL 变更走 Apply+权限系统（提权动作）；`all` 需显式授权。
7. builtinRoot 不可删（硬规则不变）。
8. **Agent 处理 Event 的 `scope` 范围强制约束（event.md 规则 19）**：每个 Agent 必须通过 `spec.eventScopes` 明确其允许处理的事件 `scope` 范围（ServiceAgent 缺省锁定为其所属 `systems/<s>` 及 `systems/<s>/instances/*`，子 Agent `eventScopes` 必须 $\subseteq$ ParentAgent 的 `eventScopes`；仅 `builtinRoot` 可持 `["*"]`）；派发路由与拉取消费双侧强制校验 `event.metadata.scope ∈ agent.spec.eventScopes`，严禁跨 scope 越界消费事件，且第一段侦察拉取「近期关联事件」时默认只检索本 Agent `eventScopes` 内的非隐藏事件（自动过滤 `Heartbeat` 等 `visibility: default-hidden` 的底层事件）。
9. **进程与会话活性靠 `Heartbeat`（`pingheart`）盯着恢复，本层级不考虑高可用（2026-11-26 用户裁决）**：本层级明确不设计多副本高可用（Non-HA）或复杂级联进程租约；Agent 与机器级子 Agent 活性统一由 `Heartbeat`（`pingheart`）看门狗盯着恢复——失活触发 `SessionStalled` / `HeartbeatLost` 自愈链（先注入「继续」唤醒 → 诊断重启/重派 → 上报）。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| LLM 不保证收敛 | ❗高（机制兜底） | 修复可能失败/震荡/越改越坏 | Workflow onFailed（backoff+上限）+ dry-run + undo + Escalate（ 结论不变） |
| Session 记录被省略 | ⚠️ 中 | "看实现"的粒度容易松 | PlanDoc/SessionLog 为 Instance 必备 docType；缺记录=drift（Workflow 对账） |
| 机器级子进程开销 | ⚠️ 低（已接受） | 每 agent 一进程，内存翻倍 | 已明确接受（架构决议）；换取崩溃隔离+直控+无共享状态 |
| 按需加载读漏关键约束 | ⚠️ 中 | 会话自主决定读什么可能漏 Rule | L0 最低必载由 Workflow 注入（规则 2）；SessionLog 记录 docsLoaded 可审计"读了什么" |
| 对话/headless 询问词形混用 | ⚠️ 中 | headless 误用会话内提问词形=无人应答死等 | 询问词形随 `spec.mode` 分轨：headless tools 无会话提问词形，只有**通知+审批**两个默认工具（builtin 注入）；Workflow 引擎派发校验 mode，默认 workflow 拒绑 chat agent |
| Provider/ops 引用膨胀 | ⚠️ 低 | 权限面变大 | 并集+权限系统裁剪不变；无引用 Provider 告警 |

**结论：可行。本设计放松了写路径管制、换上"记录+分级"治理——与 AUTOLEVEL 一样，都是 P8（机制不假设模型能力）的落地。**

## 8. 待决问题

见 open-questions.md#agent

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
