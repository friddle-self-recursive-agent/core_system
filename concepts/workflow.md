# Workflow — 循环本体（触发规则→事件整理→处理→文档回归）

| 项 | 值 |
|---|---|
| K8s 对照 | Controller/Reconciler（触发+对账+刹车）与 Pod 相位机的合体 |
| 形态 | 对象：`global/workflows/`（builtin）与 `systems/<s>/workflows/<name>.yaml`（系统自定义） |
| 作用域 | Global（builtin）/ System |
| 状态 | 定稿（终态制，rule.md） |

## 1. 定义

Workflow 是**完整的循环流程**：**触发规则 → 事件整理 → 事件处理（相位态机）→ 文档回归**。一句话：**Workflow 就是一条规则**——声明"何时看、看什么、怎么处理、怎么回归"，引擎按规则执行，规则之外引擎无动作。

**Workflow 可整体开启/关闭**（`spec.enabled`，Apply 切换）：关闭即该规则不再触发、不再消耗，已完成轮次与回归记录保留。**涉及哪些 service、怎么涉及、用哪个 LLM，全部在 Workflow 配置里声明**（`spec.services` / `spec.llm`）——换 LLM、圈 service 都是改配置，不是改代码。

**Workflow 是平台对象，不只是内部机制**：可编辑（spec=文档，Apply 修改，每一步可调整）、可展示（流程图/事件/流转/数据流，见 console）、可被第三方编辑与管理（导入/克隆/触发设置，同走 Apply+权限系统）、可启停（spec.enabled）。**developer_system 就是一种 workflow 实例**；不存在独立的循环 Kind。

### 内置最核心 workflow：`core-workflow`

```
event（触发规则命中）
 → analysis（分析：读文档 L0/L1，对比现实）
 → 【自己处理 | 上报】（AUTOLEVEL/权限系统 决定：auto 直接处理；ask/高危 → 上报走审批或上溯 root）
 → plan / auto（计划；或 auto 直执行 TaskScheme）
 → 直接调用 developer_system / agent / 系统（经 ConnectorOps；派发子 agent 也是 ConnectorOps 调用，子 agent 运行时不限于 dsh）
 → 更新服务状态（Status 回写）
 → 满足现有系统在文档上描述的需求（文档回归：DriftReport/SessionLog 归档）
```

builtin 集合：`core-workflow`（上述全流程）、`default-task`（单任务态机，Agent 引用）、`simple-shot`（简单派发）、`watch-only`（只观察不执行）、`dev-delivery`（默认研发交付 workflow，§1.1）、`apply-workflow`（workflow 落地 agent 的任务态机，§1.2）。

### 1.1 默认研发 workflow：`dev-delivery`（默认文档，每步可调整）

系统自带的完整研发闭环，入口 event（错误日志 ≥error / 新需求 / 用户请求）触发**全自动**流转：

```
触发(event) → Analyze（定位错误/拆解需求） → Gate（高危人批，auto 白名单直过）
 → Plan（选 TaskScheme 模板） → Execute（developer-system pull → 本地 build+test
   红线全绿 → 产物 digest） → Verify（探针复测） → Deploy（deploy-system 按
   DeployDesign.envs 升序发布，prod 人批） → Report（Status 追平+归档+Event）
```

每一步=声明的相位与 TaskScheme 引用，调整=改 spec/模板参数后 Apply；整条可 `enabled: false` 一键停用。

### 1.2 Workflow 落地 = 专用 agent（`apply-workflow`）

把一份 Workflow 声明落到真实系统，本身也是 workflow 干的活——专用 agent 承担：解析 spec 接线触发源（注册 Connector watch）→ 缺的连接层调 **developer-system**（pull/写**自定义 connector** 代码/build，每层调用代码化）→ 落地后注册一条 `watch-only` 监控新 workflow 的成功率/死信/成本（自监控闭环，异常回 Event 走修复循环）。即：**流程实现=代码；写代码=调研发系统；监控 workflow 的=内置 workflow（自举）**。运行时细节见 instance 仓 runtime/workflow-runtime.md。

## 2. 边界

**是**：触发规则 + 事件整理规则 + 相位态机 + 数据流声明 + 刹车 + 文档回归——一个可编辑、可展示、可启停的平台对象。

**不是**：
- 不是自由脚本编排（无业务 if-else；迁移条件只有事件与策略；"可编辑"指声明式 spec 的编辑，一切修改过 Apply+权限系统——反模式不变）；
- 不是 TaskScheme（TaskScheme 是 Executing 相位内的步骤图；Workflow 是包着它的整个循环）；
- 不是 WorkflowDesign 文档（那是给人看的功能流设计）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Workflow
metadata:
 name: developer-system-workflow # "developer_system 是一种 workflow" 的落地形态
 scope: builtin-developer-system
spec:
 enabled: true # 规则开关：false=停用（不触发不消耗；回归记录保留）
 services: # 涉及哪些 service、怎么涉及（规则的数据面）
 involved: [developer-system, deploy-system] # 圈定的 service（空=随 scope）
 mode: observe|act # 怎么涉及：只读观察 / 可执行动作
 llm: {provider: llm-main, model: flash-tier} # 该 workflow 用的 LLM（Agent/生成相位取此配置；具体选型不入公开仓，R-PUB）
 dataflow: # 数据流声明（展示层拼系统级数据流图的依据）
   inputs: [{events: [MetricThreshold], docs: "systems/developer-system/*"}]
   outputs: [{status: self, notify: [bind-role], artifacts: "oss://builds"}]
 triggers: # ① 触发规则（原 Workflow.watch）
 events: {types: [ExternalChanged, MetricThreshold], minLevel: warn} # 按类型+owner 路由
 timer: {resync: 10m} # 巡检兜底（level-triggered 保险丝）
 ingest: # ② 事件整理规则
 dedup: {window: 5m}
 group: {by: dedupKey, max: 100}
 filterLevels: [info, warn, error, fatal]
 phases: [Idle, Analyzing, Planning, AwaitingApproval, Executing, Verifying, Reporting, Failed, Paused]
 onEscalate: {action: pause, notify: bind-role} # AUTO 处理不了的 Escalate 到达时的暂停策略（可配置）：
                                                #   pause=立即挂起（相位冻结，现场+断点保留，SessionLog 可续）
                                                #   finish-tick=跑完本轮再停（防半成品，Execute 中途不打断）
                                                #   continue=只通知不暂停（低危域可配）
                                                # 恢复=人处理后在 console 批准 Resume（=Apply）；不自动恢复
 onFailed: {backoff: 30s*2^n, maxAttempts: 3, escalate: {to: root, notify: bind-role}}
 brakes: # ③ 刹车（强制默认：可收紧不可关闭）
 cooldown: 2m # 成功后最小间隔（防震荡）
 maxMutationsPerTick: 10 # 单轮最大变更数
 avoidRepeatFix: true # DriftReport 记录"改过什么"，避免重复同类修复
 regression: # ④ 文档回归
 statusWriteback: true # Status/Conditions/observedGeneration
 reports: [DriftReport, SessionLog]
```

## 4. 生命周期

注册（builtin 或系统自定义，Apply）→ 触发规则命中即一轮循环 → 相位运转（SessionLog 记录）→ 回归（Status+DriftReport）→ 冷却 → 待下一触发。相位语义变更需新版本名（只加不改）。

## 5. 与其他概念的关系

- ConnectorOps 必绑 Workflow（缺省 default-task）——op 调用的相位约束。
- Agent 的任务态机=引用 default-task；Workflow 引擎（core plugin 内）统一调度所有 Workflow 实例。
- Escalate 出口：默认上溯 root agent；有 role 挂载时 role 持有者经 Notification 同达。
- TaskScheme 在 Executing 相位内跑；Skill 缓存服务 Agent 层。
- **展示面**（console）：workflow 详情页四 tab——流程图（相位态机自动渲染、当前相位高亮）/ 事件流 / 流转（每轮相位流水，ops DB）/ 数据流（dataflow 拼图）；操作（启用/停用/编辑/克隆/导入）全部=Apply。渲染数据全部来自 Scheme+ops DB。**成本观测归 metrics**，不占 workflow 详情页。
- **第三方**：其他系统/他人编辑、导入、管理、触发设置，走同一 Apply+权限系统入口；导入=外部编排渲染成 spec（预览=dry-run，导入件首期 observe 模式）。
- **落地 agent**：新 workflow 的接线/代码化由 `apply-workflow` agent 承担（§1.2）。

## 6. 设计规则

1. 相位/迁移纯声明（相位机=标准 FSM：引擎按声明执行，规则之外无动作；失败走 onFailed）。
2. 刹车三件套（cooldown/maxMutations/avoidRepeatFix）为 Workflow 级强制默认，可收紧不可关闭。
3. **预算/成本不在核心循环语义内**：budget 是 metrics 关注的东西（由 ConnectorOps 收集→agent 报告的默认 workflow 承接），暂不做——核心循环只有触发/整理/相位/回归，不再往里加预算机器。
4. builtin Workflow（core-workflow/default-task/simple-shot/watch-only）修改属高敏 权限系统 项。
5. 触发规则必须与事件 Level 联动（minLevel 过滤）。
6. **核心定时驱动**：存在一个核心定时器——system 的 agent 定期处理 event 与报告，转给上游 global 汇聚（上游再 workflow 分析）；**builtin 域不走远端，event/报告本地处理**。timer.resync 是这条链的保险丝（level-triggered，丢事件靠巡检兜底）。
7. **流程可读性**：workflow spec 由 LLM 生成本段白话描述 + 流程图（mermaid），随对象详情展示——规则是数据，解释与图按需生成，不入库为准（重新可生成）。
8. **数据流必声明**（spec.dataflow inputs/outputs）——展示与对账依据；缺声明=Lint 报警。
9. **导入件治理**：origin=import 的 workflow 首期强制 observe 模式（只读跑一段再放开 act）；第三方编辑同权限系统裁剪（P7）。
10. **暂停策略可配置（onEscalate）**：AUTO 处理不了的 Escalate 到达时——Workflow **可以判断是否暂停**，也可以**按策略自动暂停**；pause=立即挂起（Paused 相位），finish-tick=本轮跑完再停，continue=只通知不停。默认 pause。挂起现场与断点由 SessionLog 承载，恢复=人批 Resume（=Apply），通知走 bind-role 双通道（root 上报+Bind 发送）。
11. **落地代码化**：workflow 的接线与连接层实现由 apply-workflow agent 经 developer-system 代码化完成；运行时不做即兴接线。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule.md)）。

## 7. 跨权限完整分析

Workflow 天生跨权限：一轮 core-workflow 要穿过五个权限域。逐点分析：

| # | 穿越点 | 涉及权限 | 谁持有 | 越权风险 | 机制 |
|---|---|---|---|---|---|
| 1 | 事件读取 | bus 订阅（按 selector/level） | Workflow 引擎（core plugin） | 低（读信号非资源） | 引擎统一订阅，按 triggers.minLevel 过滤 |
| 2 | 文档读取 | docs权限系统.read（L0/L1） | 执行 Agent | 中（读越界=信息泄露） | 白名单+按需加载，SessionLog 记 docsLoaded |
| 3 | 计划 | 无副作用 | Agent | 无 | Planning 相位只读 |
| 4 | 执行 | ConnectorOps 并集 | 执行 Agent | **高（核心风险点）** | 见下"三条越权出路" |
| 5 | 状态回写/文档回归 | fieldManager（engine/agent） | 引擎与 Agent 分持 | 中 | Status=engine 专写；Spec 类默认 Agent 无权（P6） |

**执行越权的三条出路（Workflow 不能静默越权）**：

1. **权限齐备**：Workflow 的 owner Agent 引用齐所需 ConnectorOps（权限并集覆盖全部步骤）——常态路径。
2. **跨系统提案**：步骤落在别的系统域 → 不直接执行，Apply 提案进对方待审区，由对方自己的 workflow 处理（系统间调用=互相 Apply 的语义）。
3. **审批提升**：缺权限且必须本 workflow 执行 → AwaitingApproval 相位插入，role 持有者人批（一次一批，token 制可选）。

**委派模型（一次性全量下发）**：上级委派任务=**一次性把权限全给全**——上级 agent 把自己的权限（ConnectorOps/Ref/Provider/role 并集）整包下发，权限 token 与 ref 直接给到执行 agent，不做按步骤细粒度裁剪。子 agent 权限仍 ⊆ 父（只减不增的不变量不变——扩权源头只能是上级/审批，agent 不能自增，扩权路径仍是 2/3）。**运行时发现缺权限 → 直接 ask 上级，上级重新一次性全量申请并整包重发**（挂起-恢复由 SessionLog 断点承接）。root 例：root 的 agent 默认下发任务时，判定为根 → **先向所有 Service 请求权限**（各 Service 侧判定放行），拿到的权限 token 与 ref 直接下发给需要执行的 agent。

**代码设计影响**（复杂度来源与对策）：

- 引擎须按相位做权限校验（Planning 只读放行；Executing 逐步校验 ops 归属）→ 引擎持有权限索引（Agent 引用并集的物化），校验是查表不是即席计算。
- 提案与审批是异步的 → 相位机要有挂起-恢复（AwaitingApproval ↔ 批准/驳回），断点续跑靠 SessionLog。
- 成本观测归 metrics（预算暂不做）：若日后做跨系统成本分摊，规则沿用"记发起方（提案方付费），被提案方执行轮成本记己方"。

**可行性结论：⚠️ 高复杂度，但可行且有清晰分阶段路径**：

| 阶段 | 范围 | 风险 |
|---|---|---|
| v1 | 出路 1（权限齐备）+ 出路 2（提案）；审批仅 权限系统 高危拦截面 | 低——单 owner 权限内执行，引擎校验退化为"步骤 ops ∈ owner 并集"查表 |
| v2 | 出路 3 全量（审批提升 token 制）+ 挂起-恢复完善 | 中 |
| v3 | ask-上级重发链路完善；跨系统成本分摊（归 metrics 域） | 中 |

关键判定：**复杂度在权限校验的完备性，不在相位机**（相位机是标准 FSM）。v1 先行不阻塞首圈循环。

## 8. 可行性分析（常规项）

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 震荡 | ⚠️ 中 | 修复互踩 | 刹车三件套（§6.2） |
| 成本失控 | ⚠️ 中 | 高频触发×大上下文 | 刹车三件套+metrics 事后聚合（预算强制暂不做，budget 归 metrics 域） |
| 多 workflow 修同一外部资源 | ⚠️ 中 | 交叉写 | 单一 owner Workflow 写；跨域走提案（§7 出路 2） |
| 第三方编辑权限面 | ⚠️ 中 | 谁能改谁系统的 workflow | scope 写权限+权限系统裁剪；builtin 修改=高敏项 |
| 导入渲染失真 | ⚠️ 中 | 外部编排语义≠声明式相位 | 导入预览=dry-run；origin=import 首期 observe 模式 |
| 展示数据双源 | ⚠️ 低 | 前端自建状态会漂移 | 渲染数据全部来自 Scheme+ops DB（硬性约定） |

## 9. 待决问题

见 open-questions.md#workflow

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
