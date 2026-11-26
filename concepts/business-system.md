# BusinessSystem — 企业业务系统层（common-business-system）

| 项 | 值 |
|---|---|
| K8s 对照 | K8s 机制之上的独立应用控制面实例：复用同一套控制面架构，但独立部署、独立 `cored`、独立文档库 |
| 形态 | **不在最外层 `core_system` 根项目中，单独设计、独立实例运行**；每个业务系统实例（如 `sybran`）运行**自己独立的 `cored` 进程与独立的 SQLite `docs DB`**（每个 `cored` 只挂载单个 `docs DB / docsRoot`） |
| 作用域 | 独立业务系统级（约束骨架被具体业务实例继承） |
| 状态 | 定稿（终态制，rule/rule.md；**2026-11-26 用户裁决：① business-system 不在最外层根项目中，单独设计，业务实例（如 sybran）运行独立的第二个 `cored`；② 明确区分业务内部流水/账本事件与外部控制面事件：业务流与逐笔对账由业务代码承接、自己走自己的事件与账本；外层控制面系统只承接系统级别事件、报警事件、以及对账失败事件**） |

## 1. 定义

common-business-system 是复用 core-system 机制的**独立企业业务服务模型**（不在最外层 `core_system` 根项目中混合部署，而是单独设计、独立运行自己的 `cored` 实例）。它提供**业务约束模型**——企业语义怎么与控制面机制分层配合——不把高频业务交易塞进控制面。

三层定位与物理隔离：

```
core-system（最外层根项目）   机制层：根控制面 / 六个 builtin（运行第一个独立 cored：core_agent）
  ↑ 复用同一套二进制机制，但物理与项目解耦（不混入根 docsRoot）
common-business-system       单独设计的业务约束骨架：状态 / 财务 / 业务 / 监控 / 事务 五域纪律
  ↑ 实例化（独立仓 + 独立 cored + 独立业务代码库）
sybran-business-system       第一具体企业实例（公司 OneDev 私有仓；运行第二个独立 cored：sybran agent）
```

**为什么必须两个独立的 `cored`**：每个 `cored` 的 Repository（`--docs-backend sqlite`）严格只挂载**单个权威 `docs DB`（单 `docsRoot`）**；最外层 `core_system` 的 `cored` 只管系统级 builtin，而 `sybran` 业务系统拥有自己独立的 `cored` 与独立的 `docs DB`。

## 2. 边界（特别是「业务内部流/账本」与「外部控制面事件」的严格分界）

**是**：企业运行状态的约束与控制面治理模型（业务规则声明、预算闸门审批、健康指标监控、对账失败后的升级处置）。

**不是**：
- **绝不把控制面 Event Bus 当成财务账本（Ledger）或高频业务事件流**：
  - **业务流与账本由业务代码自己承接**：高频订单流、支付流水、会计分录（Ledger Entry：不可丢弃、不可去重、借贷必相等）以及逐笔业务对账，**全部由业务系统自己的业务代码、自有数据库账本与业务内部事件流承接**（自己走自己的事件，对账也是业务代码自己跑）；
  - **外层控制面（`cored` Event Bus）只承接三类粗粒度事件**：
    1. **系统级别事件（System-Level Events）**：业务服务/实例生命周期、配置与规则变更（`DocApplied`）、组件健康态迁移；
    2. **报警/越限事件（Alert Events）**：指标越过声明面阈值（`MetricThreshold`）、预算额度触线请求审批（`ApprovalNeeded`）、任务停滞或熔断报警；
    3. **对账失败事件（Reconciliation Failure / Drift Events）**：业务代码内部跑对账循环时，一旦发现账实不符/平账失败，向控制面抛出**对账失败事件**（携 `DriftReport` 指针），触发 Agent 调查、告警或人审介入（对账成功仅刷新 `InSync` 状态与指标，不向控制面刷逐笔流水事件）。
- 不是最外层 `core_system` 的内嵌子目录（单独设计、独立 `cored`）；
- 不是新 kind 或新控制面执行机制（控制面仍只认既有的 Apply / Workflow / Permission / Event）。

## 3. 企业分析模式（元模式）

任何企业的实际运行状态可按同一把刀切开：**对象 → 流 → 控制 → 观测 → 循环**。

| 步 | 问的问题 | core-system 对应 |
|---|---|---|
| 对象 | 企业在管什么（单据/合同/项目/资产/事项） | 每个业务对象=一个状态机（StateModel 声明），现实态=Status |
| 流 | 数据/信息在对象与角色之间怎么走 | 声明侧 DataDesign（entities/flows）；现实侧 Event/MetricsInfo 投影 |
| 控制 | 哪里有闸门（审批/预算/权限） | 权限系统 + Proposal 审批双路 + ApprovalNeeded 事件 |
| 观测 | 怎么知道运行正常 | Metrics 声明 + MetricsInfo 序列 + MetricThreshold 事件；观测面只读 |
| 循环 | 怎么持续拉齐现实与账面 | Workflow 循环（P3 level-triggered / P5 收敛而非完成）：对账、结算、投影刷新 |

这套切法与 architecture.md §3 边界决策树同构：对象/流=意图侧文档（Q1 意图），闸门=写面+审批，观测=现实侧（Q1 现实），循环=Workflow。**企业分析 = 用决策树逐项归类企业语义**。

## 4. 五域模型与 core-system 映射

### 4.1 状态模型（StateModel）

**企业分析**：企业里一切被管对象都有生命周期；状态词是闭合集；迁移带主体纪律（谁、在什么条件下，能把对象从 A 态推到 B 态）。

**core-system 落点**：P2 直接移植——
- 期望态 = Spec 侧 StateModel 文档（对象清单+状态词表+迁移表）；
- 现实态 = Status（**只能由系统回写**，人不得手改）；
- 迁移纪律 = conventions.status.writers 的写面主体语义；
- `observedGeneration` 表达"现实追上了第几版状态定义"；
- 闭合集+显式迁移表与 Workflow.transitions 同词汇（workflow.md 规则 14 同款机制）。

**既有示范**：Proposal 是本域第一个 dogfood 对象——`draft→submitted→approved|rejected→landed` 闭合集+主体纪律+审计回链，全部按本域约束运转。

### 4.2 财务（Finance）与账本/事件严格分离

**企业分析**：账实分离（预算/计划 vs 实际发生）；会计分录（Ledger Entry）不可丢弃、不可去重、借贷必相等；闸门（谁批钱）；周期对账。

**业务代码账本 vs 控制面落点（2026-11-26 裁决）**：
- 预算/科目/闸门规则 = **意图**（业务系统独立 `cored` 中的 Finance 文档，Spec 侧）；
- **发生额/逐笔财务流水（Ledger）= 业务系统自有代码与自有账本数据库承接**（**绝不走控制面 Event Bus `event_log`**，因为控制面 Event Bus 具有 dedup 窗口去重与可丢弃 level-triggered 语义，严禁当账本用）；业务流水走业务代码自己的内部事件与 ACID 账本表，现状数字由业务账本查询投影至 `MetricsInfo`；
- **外部控制面只收三类信号**：
  1. **系统级事件**：Finance/StateModel 规则更新（`DocApplied`）、服务生命周期变化；
  2. **报警/越限事件**：科目消耗越过声明面阈值 → `MetricThreshold` / `ApprovalNeeded` → Proposal 调预算（agent 发现超支不许改预算，只能提案）；
  3. **对账失败事件**：业务代码内部对账任务（月结/日结/渠道核对）发现账实不符时，向控制面发送**对账失败事件**（附 `DriftReport`），触发告警与处置 Workflow。

### 4.3 业务（流程）

**企业分析**：跨角色/跨系统的协作流（履约/采购/交付），有阶段、有闸门、有超时升级；同类业务可复制——换绑定不换流程。

**core-system 落点**：Workflow（相位机/transitions/onEscalate/brakes）+ TaskScheme（确定性步骤）+ ConnectorOps（跨系统调用）。"变体=只换节点绑定，不换 workflow 文档"（developer-variant 已示范的通用抽象）直接复用：同一履约流程文档，不同业务线只改节点绑定的 service/connectorOps。

### 4.4 监控

**企业分析**：业务健康必须指标化（进度/健康/瓶颈/达成率），越限告警，观测不干预。

**core-system 落点**：Metrics docType（indicators/thresholds 声明面）+ MetricsInfo（现实序列）+ MetricThreshold 事件 + 观测面纪律（**只看得见，不反过来改状态**——architecture.md 四层一面）。阈值必须在声明面注册（scheme.yaml 既有纪律：声明面外谓词不绑定、不即兴语义）。

### 4.5 事务

**企业分析**：企业动作要么成、要么留痕可补偿，不能半途无账；跨系统动作需要 undo。

**core-system 落点**：P4 幂等硬契约（写操作幂等，做不到的外部系统在 Connector 内包成幂等：比较后写/写前 dry-run/写后验证）+ WorkService.tools 的 `undo: full|partial|none` 与 cleanup 成对声明；不可回退动作 = 人审档（P8：审批点是机制一部分，严格程度可配置不等于可省略）。

### 4.6 循环管控（五域的运行形态）

对账/结算/巡检 = level-triggered 循环（P3/P5）：不依赖事件完整性，收到信号全量对账；只有 `InSync`（此刻账实一致），没有"结完"。

**core-system 落点**：ReconcileTick 事件已是系统级对账锚；业务对账（账实对照/状态投影刷新/结算）= **同一循环机制的业务 Workflow 实例**——新增的只有循环的业务判据（声明在 Metrics/Finance），不是新的循环引擎。

## 5. 对象结构

### 5.1 DocType 注册（本层新增两个，其余全复用）

| DocType | 必填段 | 写者 | 说明 |
|---|---|---|---|
| `StateModel` | objects / transitions | 人/owner | 业务对象清单+状态词表+迁移表（闭合集）；每对象声明主体纪律 |
| `Finance` | budget / gates | 人/owner | 预算科目+闸门规则；现状数字禁止出现（只许从流水推导） |

复用：DataDesign（流声明）、Metrics（指标）、WorkflowDesign（业务流程）、Rule（域纪律）。

### 5.2 系统声明骨架

```yaml
# systems/common-business-system/system.yaml
apiVersion: core/v1
kind: ServiceDesc
metadata:
  name: common-business-system
  scope: global
spec:
  goalRef: goal.md
  descRef: desc.md
  docs:
    - rule/biz-rules.md        # R-BIZ-1..7
    - docs/state-model.md      # 通用业务状态基词表（实例继承后特化）
    - docs/finance.md          # 预算/闸门基线
  instances:
    - name: sybran             # 第一实例（实例侧设计落 sybran-business-system 私有仓）
      agentRefs: []
```

### 5.3 通用业务状态基词表（实例继承的缺省词表，可扩充不可改名）

```
draft（草稿）→ submitted（已提交）→ approved（已批准）→ executing（执行中）→ done（已完结）
任意态 → cancelled（已取消，留痕）；submitted → rejected（已驳回）
```

迁移主体纪律：draft→submitted=提出人；submitted→approved|rejected=审批主体；approved→executing=执行体；executing→done=执行体+验证通过；cancelled=有权限者。**实例只允许：新增状态词（闭合集扩充）、收紧主体纪律；不允许放宽 P2（现实态系统回写）。**

## 6. 生命周期（继承与实例化）

```
本层定稿（Rule/DocType/基词表入库）
→ 实例继承：拷贝 R-BIZ 纪律+基词表 → 特化（新增业务对象/科目/指标/流程绑定）
→ 绑定 agent（autoLevel 按审批分流配置）
→ 循环开跑（对账/结算 Workflow 注册，ReconcileTick/定时触发）
→ 现实投影持续回写 Status/MetricsInfo（P2/P5：收敛，而非完成）
```

## 7. 与其他概念的关系

- **core-system 全部机制**：复用不改造（P10：本层是约束声明，不是新机制）；
- **Proposal**：第一个按本模型运转的业务对象（状态域 dogfood）；实例层一切"要办事"都从提案进；
- **Template（appliesTo: servicedesc）**：远期可为业务系统出厂模具（业务系统模板=五域骨架），v1 不做；
- **Metrics/DataDesign/DataMetrics**：监控域与流域的既有承载，本层只加"必须声明"的纪律；
- **sybran-business-system**：第一实例（公司 OneDev 私有仓）；其运行面在 sybran agent，与 core_agent 物理分离（实例侧部署锚点见该仓，凭据只引用式）。

## 8. 设计规则

1. **独立项目与独立 `cored`**：business-system 不混在最外层 `core_system` 根项目中，而是单独设计；每个业务部署实例（如 `sybran`）运行自己独立的 `cored` 与独立的 SQLite `docs DB`（单 `cored` 单 `docsRoot/docs DB`）。
2. **R-BIZ-1 状态闭合集**：业务对象状态必须是闭合集+显式迁移表（StateModel）；未注册状态词不得入 Status；现实态只由系统回写（P2 移植，不可放宽）。
3. **R-BIZ-2 账实分离与账本/事件总线隔离**：预算/计划=意图（Spec），发生额/逐笔分录（Ledger Entry）=**业务系统自有代码与自有账本库承接（自己走自己的业务内部事件与逐笔对账，严禁用控制面带去重的 Event Bus 充当财务账本）**；现状数字禁止手填，只许从业务账本推导并投影至 `MetricsInfo`；外层控制面 Event Bus **只承接系统级事件、报警/越限事件、以及对账失败事件**。
4. **R-BIZ-3 钱动必审**：财务闸门动作（超预算、预算变更、对外付款类）默认走高危审批档；agent 无权改预算，只能提案（P6）。
5. **R-BIZ-4 流必须声明**：数据流/信息流每条在 DataDesign 声明 source→sink+幂等性+留痕口径（含业务内部流与上报控制面的三类事件边界）；未声明的流不得投产（盲流=缺陷）。
6. **R-BIZ-5 无指标不上线**：业务域必须带 Metrics（指标+阈值）才可投产；阈值只在声明面（声明面外谓词不绑定）；观测面只读。
7. **R-BIZ-6 事务可回退**：对外动作必须声明幂等性+undo 等级（tools 契约）；undo:none 的动作默认人审；补偿=成对 cleanup op。
8. **R-BIZ-7 循环对账与异常上报**：逐笔业务对账由业务代码循环执行（自己走自己的内部对账流）；控制面以 Workflow 周期监督对账状态（level-triggered、幂等、收敛语义），**一旦对账失败必须向控制面抛出对账失败事件与 DriftReport**，禁止"跑完即忘"或静默吞没差异。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

## 9. 可行性分析

**总判**：本层可行性=映射覆盖率——五域是否全部能落在既有机制上而不新增概念。逐域：

| 域 | 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|---|
| 状态模型 | 业务状态词膨胀失控 | ⚠️ 中 | 企业对象多、各域各词，闭合集难维持 | 基词表+实例扩充制（可增不可改名）；Status 未注册词=lint 拒绝；词表挂在 StateModel 一处可审 |
| 状态模型 | "现实态系统回写"对企业流程的适用性 | ⚠️ 中 | 企业单据的现实推进常由人完成，非 agent | 写面主体含人审档（角色持有人推进=系统代记，人只出判定——与 Proposal approved=human 同构） |
| 财务 | 流水完整性 | ⚠️ 高 | 企业财务流水源多（银行/支付/内部），漏记=账实永远不合 | 对账循环显式暴露差异（Drift 语义）；每条流水带 source 声明（R-BIZ-4）；冷启动只管内部闸门账，外部对账靠导入声明 |
| 财务 | 数字精度/口径 | ⚠️ 低 | 分摊/汇率等会计细节 | 约束层不管口径算法（属于实例层实现 Docs）；本层只管"现状数字必须可溯源到流水" |
| 业务 | 流程文档与实际执行漂移 | ⚠️ 低 | 业务流程改了文档没改 | 既有收敛循环兜底（对账判据含流程绑定一致性） |
| 监控 | 指标口径争议 | ⚠️ 低 | "达成率"算法各说各话 | 口径写进 Metrics 声明（一处权威）；观测面只投影不裁决 |
| 事务 | undo:none 动作堆积 | ⚠️ 中 | 企业大量动作天然不可回退（对外发函/付款） | 默认人审档吸收；P8 配置面可按动作分级放宽；不追求全量自动化 |
| 循环 | 结算循环性能 | ⚠️ 低 | 全量对账随流水增长变慢 | P3 本就允许多级对账（增量对账+周期全量核）；对账本身幂等可重跑 |
| 整体 | 约束层被实例绕过 | ⚠️ 中 | 实例图省事不声明直接跑 | R-BIZ-4/5 是 lint 型可机械判定（投产前检查 StateModel/Finance/Metrics 在册）；闸门在 Apply 准入 |

**结论：可行。五域全部有既有机制承接，新增面只有两个 DocType 与一组规则；真实风险集中在财务流水完整性（实例层冷启动问题，非机制缺陷），以对账暴露差异+流水源声明压住。**

## 10. 待决问题

见 [open-questions.md](../open-questions.md#business-system)。

## 11. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
