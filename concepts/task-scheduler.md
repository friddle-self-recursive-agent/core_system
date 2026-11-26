# TaskScheduler — 多任务并发调度（无关任务并行 agent，相关任务串行/等待）

| 项 | 值 |
|---|---|
| K8s 对照 | Job/queue controller（并发度可调 + 依赖/互斥） |
| 形态 | `Task` 文档对象 + cored 调度器 + 宿主 agent spawn 桥；任务状态落 ops/Status |
| 作用域 | Global / System / Instance（按 Task.scopeRef） |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. 定义

TaskScheduler 把"要做的事"变成可并发的任务队列：**没有相关性的任务同时开 agent 跑，相关的任务排队/串行**。并发度可调（全局/服务/仓库/单任务），失败隔离，结果经 Apply/合并队列落地。

一句话：**不是所有活都塞进一个自循环会话；无关任务并行，相关任务排队。**

## 2. 边界

**是**：任务的依赖/写集/互斥声明、就绪判定、并发度控制、agent 拉起、租约与失败隔离、任务状态与观测。

**不是**：
- 不是 Workflow 相位机（Workflow 是一条循环规则；Task 是队列里的一次工作）；
- 不是 TaskScheme（TaskScheme 是单任务内的确定性步骤图；Task 是跨任务调度单位）；
- 不是权限/Apply 旁路（任务产物仍经 Apply/审批/合并队列落地）；
- 不是无限并发（默认有上限与背压；可调但不鼓励打满）。

## 3. 结构

### 3.1 Task 对象

```yaml
apiVersion: core/v1
kind: Task
metadata: {name: "fix-gate-123", scope: self-recursive-core}
spec:
  title: "修复 developer-system 门禁连续失败"
  summary: "定位并修复 gate 失败；验收=连续 3 轮 dev-delivery 绿"
  source: proposal | event | drift | manual | loop
  sourceRef: proposal/global/xxx | event/evt-... | DriftReport/...
  scopeRef: {kind: ServiceDesc, name: developer-system}   # 影响域
  dependsOn: [task/global/upgrade-base]                   # 依赖 DAG（可跨 scope）
  touches:                                                # 写集（冲突判定）
    repos: [core_system_workservice]
    paths: [internal/workflow/, cmd/cored/]
    objects: [Workflow/global/dev-delivery]
    exclusive: [deploy/prod]                              # 独占资源（同值互斥）
  priority: low | normal | high | critical
  agent: agent/global/dev-1                               # 可选：指定执行 agent
  workspace: {mode: worktree | inplace, base: main, branch: "task/<name>"}
  limits: {maxConcurrent: 1, timeout: 45m}                # 可选：单任务覆写
status:
  phase: queued | ready | blocked | running | verifying | done | failed | canceled
  attempts: 0
  agentSession: session-...                               # 宿主会话 ID
  dependsOn: [...]                                        # 依赖现势投影
  lastAction: "..."                                       # 一句话（人看）
  lastError: "..."                                        # 失败原因（人看）
```

### 3.2 调度器配置（scheme.runtime.taskScheduler）

```yaml
runtime:
  taskScheduler:
    enabled: true
    maxConcurrent: 4            # 全局并发上限（可调）
    perService: 2               # 同服务并发上限
    perRepo: 1                  # 同仓默认串行（worktree/合并安全；可调）
    strategy: independent-first # 先跑无依赖且写集不相交的任务
    conflictPolicy: serialize-overlap  # dependsOn 交叠 / touches 交叠 / exclusive 同值 → 串行/阻塞
    leaseTtl: 30m               # 任务租约（防僵尸）
    maxAttempts: 2              # 失败重试（隔离，不拖垮无关任务）
    spawn: "host:/task/spawn"   # 宿主 agent spawn 桥（每任务一个 dsh session）
```

**可调**：全局/服务/仓库上限、租约、重试、冲突策略均来自 scheme（Apply 生效）；单任务 `limits` 可覆写（只收紧不放宽全局硬上限）。

### 3.3 相关性/冲突判定

两个任务可并发，当且仅当：

1. `dependsOn` 无（传递闭包）未完成依赖；
2. `touches.repos/paths/objects` 不相交；
3. `touches.exclusive` 无同值（如 `deploy/prod`、`db/migrate`）；
4. 不突破 `maxConcurrent/perService/perRepo`。

默认保守：**同一 repo 即使 paths 不相交也按 `perRepo:1` 串行**；要放开需显式调 `perRepo` 并配合 worktree/合并队列。不同服务、写集不相交 → 可并行。

### 3.4 执行拓扑

```
Task(queued) → 调度器（依赖/写集/上限）
  → ready → 租约 → 宿主 /task/spawn（每任务一个 agent session）
  → agent 执行（worktree/branch 或 Apply）
  → 任务 Verify（按 rule-verification：code/agent/human）
  → 合并/Apply 落地（相关落地串行）
  → done / failed → 解锁依赖任务
```

- 宿主 spawn 桥与 `LoopRequested` wake 桥同族：固定命令/参数、载荷不进 shell、单飞、租约。
- 同一写集/同一对象/同一独占资源永不并发；冲突即 `blocked`（人可见），不是静默排队。
- 失败隔离：一个任务失败只阻塞其依赖者，其余无关任务继续；重试上限后 `failed` + Escalate/通知。

## 4. 生命周期

1. 任务来源：Proposal 批准、Event/Drift、手动、loop 交接拆项；写入 Task 对象（Apply）。
2. 调度器 tick：重算依赖/写集/上限 → 选 ready 集 → 租约 → spawn。
3. 执行体：agent 会话；状态/心跳/最后动作回写 Task.status（系统写）。
4. Verify：按规则验证（code → ConnectorOps；agent → agent）；失败 → failed/重试/升级。
5. 落地：代码走 worktree/branch + 合并队列；文档走 Apply；落地成功 → done → 解锁依赖。
6. 取消/超时：租约过期 → 回收/重派（幂等）；人可 cancel。

## 5. 与其他概念的关系

- **Workflow**：Workflow 负责"何时看/怎么循环"；TaskScheduler 负责"多件事怎么并行做"。`LoopRequested` 是单循环点火；多任务由 Task 队列驱动。
- **Proposal**：批准后的 Proposal 可生成 Task（source=proposal），保留 acceptance/landing。
- **Agent**：每个任务一个 agent session（或指定 agent）；并发受 Agent/池容量约束。
- **ConnectorOps**：任务执行/合并/验证的代码承载；spawn 桥属宿主工具面（不新建 connector 驱动）。
- **Apply / 合并队列**：任务产物唯一落地路径；并发写同一对象/路径被写集互斥阻止。
- **Console**：任务中心 `#/tasks` / `#/task/:id` 展示并发车道、状态、节点、会话、审批；见 console-ui §16。
- **Permission**：任务创建/调度/取消按 Role；agent 权限仍按挂载并集，不因并发扩大。

## 6. 设计规则

1. **无关才并发**：无依赖 ∧ 写集不相交 ∧ 独占资源不冲突；任一不满足即串行/阻塞。
2. **默认保守**：`perRepo:1`、同服务上限 2、全局上限 4；放宽走 Apply，留痕可回滚。
3. **可调**：全局/服务/仓库/任务四级上限；只收紧不放宽硬上限；配置变更=Apply。
4. **隔离工作区**：代码任务 worktree/branch；不得并发写 main；落地走合并队列，冲突显式 blocked。
5. **每任务一个 agent session**：宿主 spawn 桥固定命令/参数；载荷不进 shell；单飞+租约+幂等。
6. **失败隔离**：失败只阻塞依赖者；无关任务继续；重试上限后 failed+Escalate，不静默重试。
7. **任务状态系统写**：phase/lastAction/agentSession 只能由调度器/执行体回写；人只改 spec。
8. **可观测**：Task.status + `TaskStateChanged` 事件 + 任务中心；任意进行中任务可一处看到"在做什么/卡在哪/谁在做/下一步"。
9. **不绕过验证**：任务完成前必须过 Verify（code/agent/human，R-TYPE-3）；验证失败不得 done。
10. **预算与背压**：并发受 LLM/机器/配额约束；超限排队，不刷额度；队列积压可见。

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 并发写冲突 | ❗高 | 多 agent 同 repo/路径互踩 | 写集互斥 + worktree/branch + 合并队列 + perRepo 默认 1 |
| 依赖判定错误 | ⚠️中 | 漏声明依赖导致乱序 | dependsOn 显式声明 + touches 保守冲突 + blocked 可见 |
| 资源/配额打满 | ⚠️中 | 多 agent 同时调用 LLM/机器 | 全局/服务/仓库上限 + 预算/背压 + 配额 hold |
| 任务僵尸/租约泄漏 | ⚠️中 | agent 崩溃/失联 | leaseTtl + 回收重派（幂等）+ 心跳/最后动作 |
| 合并冲突 | ⚠️中 | 并行分支落地冲突 | 合并队列串行 + rebase 重试上限 + 人工升级 |
| 观测碎片 | ⚠️中 | 多任务多会话找不到 | 任务中心 + session/workflow 双向链接 + 状态事件 |
| 权限放大 | ❗高 | 并发 agent 共享凭据 | 每任务主体/挂载并集不变；spawn 桥固定命令；不共享 secret |
| 调度器复杂度 | ⚠️中 | 新组件 | 薄调度器：DAG+写集+上限；执行/验证/落地复用既有 Agent/Apply/Verify |

**结论：可行。调度器只做"选任务+限并发+拉起"，执行/验证/落地全部复用既有 Agent/Apply/Verify；最大风险是写冲突，用写集互斥+worktree/合并队列兜住。**

## 8. 待决问题

见 [open-questions.md#task-scheduler](../open-questions.md)（并发上限默认值、任务 DAG 持久化、spawn 桥会话关联、合并队列实现）。

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
