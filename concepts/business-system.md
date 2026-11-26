# BusinessSystem — 企业业务系统层（common-business-system）

| 项 | 值 |
|---|---|
| K8s 对照 | K8s 机制之上的应用语义层（Policy/上层 CRD 生态）：机制全部复用，约束=已注册机制的声明性使用 |
| 形态 | 一个 ServiceDesc（`systems/common-business-system/`）+ DocType 族（StateModel/Finance）+ 规则集（R-BIZ-*）；零新 kind、零新执行机制 |
| 作用域 | Global（约束库被一切业务实例继承） |
| 状态 | 定稿（终态制，rule.md；**2026-11-26 用户裁决：core-system 之上启动企业业务系统层，先骨架**；第一实例=sybran-business-system，落公司 OneDev 私有仓，运行面在 sybran agent，不进 core_agent） |

## 1. 定义

common-business-system 是 core-system 之上的**通用企业服务模型**：针对企业**实际运行状态**的数据流/信息流设计与循环管控。它只提供**约束**——企业语义怎么映射到 core-system 已注册的机制上——不提供任何业务逻辑；业务逻辑永远属于具体实例。

三层定位：

```
core-system                机制层：文档控制面 / 收敛循环 / 权限 / 事件（现有六 builtin）
  ↑ 继承约束（改实例不改本层）
common-business-system     约束层：状态 / 财务 / 业务 / 监控 / 事务 五域纪律（本层）
  ↑ 实例化（填入真实业务对象/预算/流程/指标）
sybran-business-system     实例层：第一具体企业实例（公司 OneDev 私有仓 sybran/sybran-business-system）
```

**"更多是一个约束，不实际逻辑"** 的机制含义：本层产出的每一条内容，要么是 DocType 注册（声明侧文档类型），要么是 Rule 条目（policy/lint），要么是基词表（枚举与迁移纪律）——**没有任何一条引入新的执行机制**；执行体仍是 Agent/Workflow/Connector，写路径仍是 Apply，闸门仍是权限系统+审批。

## 2. 边界

**是**：企业运行状态的约束模型（对象怎么建模、流怎么声明、钱怎么管、健康怎么看、动作怎么可回退、循环怎么对账）。

**不是**：
- 不是 ERP/财务软件（不实现记账引擎、不做报表 UI——财务数字的现实投影走 MetricsInfo/事件归档查询）；
- 不是业务逻辑（"订单怎么履约"属于实例层 sybran-business-system）;
- 不是新 kind 或新执行面（六域全部落既有机制——这是 P10 单一职责的反向应用：能在既有机制表达的约束绝不新增概念）；
- 不是组织人事系统（"人是谁"在 user-system；本层只约束"角色在流程里能干什么"）。

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

### 4.2 财务（Finance）

**企业分析**：账实分离（预算/计划 vs 实际发生）；流水不可变；闸门（谁批钱）；周期结算。

**core-system 落点**：
- 预算/科目/闸门规则 = **意图**（Finance 文档，Spec 侧）；
- 发生额/流水 = **现实**（Event 归档 + MetricsInfo 查询——不是文档，Q1 判例："这笔钱实际花了多少"进观测面）；
- 超预算 = MetricThreshold 事件 → ApprovalNeeded → Proposal 调预算（**P6 现成**：agent 发现超支不许改预算，只能提案）；
- 流水不可变 = 事件归档/opsLog 的 append-only 语义；
- 月结/年结 = 循环对账 Workflow（ReconcileTick 同机制的业务实例）。

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

1. **零新机制**：本层约束必须能用已注册 kind/DocType/Event/Workflow 表达；表达不了=先改 core-system 机制设计，不得在本层即兴造概念。
2. **R-BIZ-1 状态闭合集**：业务对象状态必须是闭合集+显式迁移表（StateModel）；未注册状态词不得入 Status；现实态只由系统回写（P2 移植，不可放宽）。
3. **R-BIZ-2 账实分离**：预算/计划=意图（Spec），发生额=现实（流水/指标）；现状数字禁止手填，只许从流水推导；流水 append-only。
4. **R-BIZ-3 钱动必审**：财务闸门动作（超预算、预算变更、对外付款类）默认走高危审批档；agent 无权改预算，只能提案（P6）。
5. **R-BIZ-4 流必须声明**：数据流/信息流每条在 DataDesign 声明 source→sink+幂等性+留痕口径；未声明的流不得投产（盲流=缺陷）。
6. **R-BIZ-5 无指标不上线**：业务域必须带 Metrics（指标+阈值）才可投产；阈值只在声明面（声明面外谓词不绑定）；观测面只读。
7. **R-BIZ-6 事务可回退**：对外动作必须声明幂等性+undo 等级（tools 契约）；undo:none 的动作默认人审；补偿=成对 cleanup op。
8. **R-BIZ-7 循环对账**：账实对照/状态投影/结算必须以 Workflow 循环运行（level-triggered、幂等、收敛语义）；禁止"跑完即忘"的一次性结算脚本语义。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule.md)）。

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
