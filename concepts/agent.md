# Agent — 执行与收敛单元

| 项 | 值 |
|---|---|
| K8s 对照 | Pod/Job（执行体）+ 其 controller 的收敛意识 |
| 形态 | 全局一等对象（**不是** Instance 的内嵌字段，A3） |
| 作用域 | Global（builtinRoot 为 Builtin） |
| 状态 | 设计稿 v1 |

## 1. 定义

Agent 是干活的最小自治单元：领任务 → 装配上下文（读文档）→ 分析差距 → 计划 →（审批）→ 执行（经 Connector/Apply）→ 验证 → 回写 Status → 汇报。它没有自己的意图，**它的意图就是它被绑定的文档**；管 Agent 不靠盯它，靠改它绑定的文档。

两类：

- **builtinRoot**：根 Agent，Builtin scope，管理 Core、Scheme 与其他 Agent 的生死。不可删除、不可停用（Policy 硬编码兜底）。
- **普通 Agent**：Global 对象，被 ServiceInstance 引用而参与收敛；可挂 Parent/Sub 树。

## 2. 边界

**是**：读文档做判断的执行者；文档权限面的消费端（能做什么=引用的 Connector+Ref+Bind 交集，P7）。

**不是**：
- 不是文档的作者（只能经 Apply 写，且 Spec 类默认无权写，P6）；
- 不是连接器（它调 Connector，不自己写胶水代码）；
- 不是 Instance 的属性（A3：全局对象，被引用）；
- 不是常驻守护（v1 按任务拉起，任务完即闲；常驻是 Loop 引擎的事）。

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
  connectors:                                          # 能力：type -> 代码（A16）
    - {type: gitlab-driver, version: v1.2}
    - {type: dsh, as: shell}                           # 原稿 DSH 例子：用法与代码在 Connector 仓
  refs: [ref/jenkins-docs]                             # 临时引用，权限随 Ref 的 scope
  binds:                                              # BIND：人绑定（审批/责任/值班）
    - {role: approver, user: u-zhang, policy: high-risk-only}
    - {role: owner,    user: u-li}
  docsPolicy:                                         # 上下文与权限边界
    read:  [{scope: systems/developer-system/*}]
    write: []                                          # 空=纯执行，不能写任何 Spec
  subAgents:
    - {name: ci-verifier, inherit:裁剪}                # 权限 ⊆ Parent
  retry: {maxAttempts: 3, backoff: 30s*2^n, escalateTo: bind/owner}
status:                                               # 由 Loop 引擎回写
  phase: Idle | Analyzing | Planning | AwaitingApproval | Executing | Verifying | Reporting | Failed
  currentTask: {id, loopRef, startedAt}
  conditions:
    - {type: Healthy, status: "True", reason: heartbeat-ok}
```

## 4. 生命周期（任务态机）

```
Idle → (派发) Analyzing → Planning → [Policy命中→AwaitingApproval→人批/驳回]
     → Executing → Verifying → Reporting → Idle
任意态 → Failed → backoff 重试 → 超限 Escalate（Bind 的人）→ Idle
```

任务幂等可重入：任务带 taskId 与断点（写在 Instance 的运行记录里），Agent 崩溃后由 Loop 重新派发，从断点续跑。

## 5. 与其他概念的关系

- 被 ServiceInstance **引用**（agentRefs），被 Loop 引擎派发任务。
- 经 Connector 打外部，经 Apply 写文档，经 Bind 找到人。
- SubAgent 权限 = Parent 权限的子集（声明可裁剪、不可扩张），树根是 builtinRoot。

## 6. 设计规则

1. Agent 一切写操作经 Apply（P4/P7），违者 Policy 拒绝。
2. docsPolicy.read 是白名单；读不到的文档就不存在于它的世界——权限即上下文。
3. SubAgent 继承只能裁剪不能扩张；环状父子拒绝入库。
4. builtinRoot 的删除/禁用请求一律 Policy 拒绝（硬编码，不依赖配置——防止配置被改后自毁）。
5. Agent 不持有长期状态：状态写回文档面/任务记录，Agent 本体可随时重建（无状态化，同 Core）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| LLM 不保证收敛 | ❗高（机制已兜底） | 修复可能失败、震荡、越改越坏 | P3 level-triggered + 重试上限 + dry-run + Escalate 到人 + Verifying 阶段不过即回滚（Connector 留 undo 语义） |
| 上下文膨胀 | ⚠️ 中 | 全量文档塞不进上下文 | 分层装配：Goal/Rule 必读，其余按 gap 类型按需加载；DriftReport 做中间压缩层 |
| 权限模型被绕过 | ⚠️ 中 | Agent 直接跑 shell 绕 Connector | v1 信任模型：执行沙箱仅暴露 Connector 接口；纯约定部分列入已知缺口 |
| SubAgent 树滥用 | ⚠️ 低 | 层数过深难审计 | 限制树深 ≤3；跨树引用需显式授权 |

**结论：可行。收敛性靠机制兜底而非假设，这是 P8 的直接体现。**

## 8. 原始设计标注

- A3：Agent 全局化，Instance 改引用。
- A16：Connector 代码集中入库，Agent 只引 type+version。
- 原稿"builtinRoot Agent 作为最开始" → 落为 Builtin scope 的根 Agent，并加"不可删除"硬规则。

## 9. 待决问题

见 open-questions.md#agent

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
