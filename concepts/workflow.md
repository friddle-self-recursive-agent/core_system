# Workflow — 执行态机 + 触发规则（吸收 Loop，v0.8）

| 项 | 值 |
|---|---|
| K8s 对照 | Controller/Reconciler（触发+对账+刹车）与 Pod 相位机的合体 |
| 形态 | 对象：`global/workflows/`（builtin）与 `systems/<s>/workflows/<name>.yaml`（系统自定义） |
| 作用域 | Global（builtin）/ System |
| 状态 | 设计稿 v0.8（R7：Loop 并入，A41） |

## 1. 定义

Workflow 是**完整的循环流程**：**触发规则 → 事件整理 → 事件处理（相位态机）→ 文档回归**（R7 原文："Loop 本质是触发规则、事件整理事件规则、事件处理、文档回归的整个 workflow 流程"）。

**Loop 一词保留为口语**：一个带触发规则的 Workflow 实例就是一个 loop——**developer_system 就是一种 loop**。不再有独立的 Loop 概念/Kind（原 concepts/loop.md 已并入本文件，A41）。

### 内置最核心 workflow：`core-loop`

```
event（触发规则命中）
  → analysis（分析：读文档 L0/L1，对比现实）
  → 【自己处理 | 上报】（AUTOLEVEL/权限系统 决定：auto 直接处理；ask/高危 → 上报走审批或上溯 root）
  → plan / auto（计划；或 auto 直执行 TaskScheme）
  → 直接调用 developer_system / agent / 系统（经 ConnectorOps/子 agent）
  → 更新服务状态（Status 回写）
  → 满足现有系统在文档上描述的需求（文档回归：DriftReport/SessionLog 归档）
```

builtin 集合：`core-loop`（上述全流程）、`default-task`（单任务态机，Agent 引用）、`simple-shot`（简单派发）、`watch-only`（只观察不执行）。

## 2. 边界

**是**：触发规则 + 事件整理规则 + 相位态机 + 刹车与成本 + 文档回归，五件事一个对象。

**不是**：
- 不是可执行业务编排（无业务 if-else；迁移条件只有事件与策略——反模式不变）；
- 不是 TaskScheme（TaskScheme 是 Executing 相位内的步骤图；Workflow 是包着它的整个循环）；
- 不是 WorkflowDesign 文档（那是给人看的功能流设计）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Workflow
metadata:
  name: developer-system-loop        # "developer_system 是一种 loop" 的落地形态
  scope: builtin-developer-system
spec:
  triggers:                          # ① 触发规则（原 Loop.watch）
    events:  {types: [ExternalChanged, MetricThreshold], minLevel: warn}   # 按类型+owner 路由（A47）
    timer:   {resync: 10m}           # 巡检兜底（level-triggered 保险丝）
  ingest:                            # ② 事件整理规则
    dedup: {window: 5m}
    group: {by: dedupKey, max: 100}
    filterLevels: [info, warn, error, fatal]
  phases: [Idle, Analyzing, Planning, AwaitingApproval, Executing, Verifying, Reporting, Failed]
  onFailed: {backoff: 30s*2^n, maxAttempts: 3, escalate: {to: root, notify: bind-role}}
  brakes:                            # ③ 刹车（R7 确认保留，原 Loop 机制）
    cooldown: 2m                     # 成功后最小间隔（防震荡）
    maxMutationsPerTick: 10          # 单轮最大变更数
    avoidRepeatFix: true             # DriftReport 记录"改过什么"，避免重复同类修复
  cost:                              # ④ 一次 loop 的成本
    budget: {minutes: 20, tokens: 200k, mutations: 10}
    record: budget_log               # 每轮成本入 ops DB（tokens/变更数/墙钟）
  regression:                        # ⑤ 文档回归
    statusWriteback: true            # Status/Conditions/observedGeneration
    reports: [DriftReport, SessionLog]
```

## 4. 生命周期

注册（builtin 或系统自定义，Apply）→ 触发规则命中即一轮循环 → 相位运转（SessionLog 记录）→ 回归（Status+DriftReport）→ 冷却 → 待下一触发。相位语义变更需新版本名（只加不改）。

## 5. 与其他概念的关系

- ConnectorOps 必绑 Workflow（缺省 default-task）——op 调用的相位约束。
- Agent 的任务态机=引用 default-task；Workflow 引擎（core plugin 内）统一调度所有 Workflow 实例。
- Escalate 出口：默认上溯 root agent；有 Bind 时 role 持有者经 Notification 同达（A35 不变）。
- TaskScheme 在 Executing 相位内跑；Skill 缓存服务 Agent 层。

## 6. 设计规则

1. 相位/迁移纯声明；每相位有预算；超预算=该轮 Failed 进 onFailed。
2. 刹车三件套（cooldown/maxMutations/avoidRepeatFix）为 Workflow 级强制默认，可收紧不可关闭。
3. 每轮成本必记 budget_log（一次 loop 的成本可查、可聚合）。
4. builtin Workflow（core-loop/default-task/simple-shot/watch-only）修改属高敏 权限系统 项。
5. 触发规则必须与事件 Level 联动（minLevel 过滤，A42）。

## 7. 跨权限完整分析（R7 指定：workflow 跨权限，代码设计与可行性复杂，做完整分析）

Workflow 天生跨权限：一轮 core-loop 要穿过五个权限域。逐点分析：

| # | 穿越点 | 涉及权限 | 谁持有 | 越权风险 | 机制 |
|---|---|---|---|---|---|
| 1 | 事件读取 | bus 订阅（按 selector/level） | Workflow 引擎（core plugin） | 低（读信号非资源） | 引擎统一订阅，按 triggers.minLevel 过滤 |
| 2 | 文档读取 | docs权限系统.read（L0/L1） | 执行 Agent | 中（读越界=信息泄露） | 白名单+按需加载（A31），SessionLog 记 docsLoaded |
| 3 | 计划 | 无副作用 | Agent | 无 | Planning 相位只读 |
| 4 | 执行 | ConnectorOps 并集 | 执行 Agent | **高（核心风险点）** | 见下"三条越权出路" |
| 5 | 状态回写/文档回归 | fieldManager（engine/agent） | 引擎与 Agent 分持 | 中 | Status=engine 专写；Spec 类默认 Agent 无权（P6） |

**执行越权的三条出路（Workflow 不能静默越权）**：

1. **权限齐备**：Workflow 的 owner Agent 引用齐所需 ConnectorOps（权限并集覆盖全部步骤）——常态路径。
2. **跨系统提案**：步骤落在别的系统域 → 不直接执行，Apply 提案进对方待审区，由对方自己的 workflow 处理（系统间调用=互相 Apply 的语义）。
3. **审批提升**：缺权限且必须本 workflow 执行 → AwaitingApproval 相位插入，role 持有者人批（一次一批，token 制可选）。

**委派模型**：子 agent 权限=父裁剪只减不增（A31）——所以**委派不能用来扩权**；扩权只能走 2/3。这是防提权的关键不变量。

**代码设计影响**（复杂度来源与对策）：

- 引擎须按相位做权限校验（Planning 只读放行；Executing 逐步校验 ops 归属）→ 引擎持有权限索引（Agent 引用并集的物化），校验是查表不是即席计算。
- 提案与审批是异步的 → 相位机要有挂起-恢复（AwaitingApproval ↔ 批准/驳回），断点续跑靠 SessionLog。
- 成本归属：跨系统提案的 token/变更数记在谁的 budget_log → 规则：记发起方（提案方付费），被提案方执行轮成本记己方。

**可行性结论：⚠️ 高复杂度，但可行且有清晰分阶段路径**：

| 阶段 | 范围 | 风险 |
|---|---|---|
| v1 | 出路 1（权限齐备）+ 出路 2（提案）；审批仅 权限系统 高危拦截面 | 低——单 owner 权限内执行，引擎校验退化为"步骤 ops ∈ owner 并集"查表 |
| v2 | 出路 3 全量（审批提升 token 制）+ 挂起-恢复完善 | 中 |
| v3 | 委派矩阵与跨系统成本分摊细化 | 中 |

关键判定：**复杂度在权限校验的完备性，不在相位机**（相位机是标准 FSM）。v1 先行不阻塞首圈循环。

## 8. 可行性分析（常规项）

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 震荡 | ⚠️ 中 | 修复互踩 | 刹车三件套（§6.2） |
| 成本失控 | ⚠️ 中 | 高频触发×大上下文 | budget 强制+成本可聚合 |
| 多 workflow 修同一外部资源 | ⚠️ 中 | 交叉写 | 单一 owner Workflow 写；跨域走提案（§7 出路 2） |

## 9. 原始设计标注

- A41（R7）：Loop 并入 Workflow；Loop=带触发规则的 Workflow 实例（developer_system 是一种 loop）；cooldown/maxMutations/DriftReport 防重/每轮成本 全部迁入；内置 core-loop 定义。
- A26 沿用（与 TaskScheme/WorkflowDesign 边界）。

## 10. 待决问题

见 open-questions.md#workflow

## 11. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
