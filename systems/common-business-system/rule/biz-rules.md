---
name: biz-rules
docType: Rule
scope: common-business-system
ownerRefs: [{kind: ServiceDesc, name: common-business-system}]
---
# Rule — 企业业务五域纪律（R-BIZ，实例继承底座）

> 继承语义：业务实例（sybran-business-system 等）以引用方式继承本组规则；实例可收紧、不可放宽；
> 放宽=对本仓 rule 的修改（走正常提案/审批链）。type=lint 的条目必须在实例侧投产检查中机械可判（R-TYPE 同款纪律）。

## R-BIZ-1 状态闭合集（type: lint）

业务对象状态必须是**闭合集+显式迁移表**（StateModel 文档）；未注册状态词不得入 Status；现实态只由系统回写，人不得手改（P2 移植，任何实例不可放宽）。

## R-BIZ-2 账实分离与账本/事件总线隔离（type: policy）

预算/计划=意图（Spec 侧 Finance 文档）；**发生额/逐笔财务分录（Ledger Entry）=业务系统自有代码与自有账本数据库承接（自己走自己的业务内部事件与逐笔对账，严禁用控制面带 dedup 去重的 Event Bus 充当会计分录账本）**；**现状数字禁止手填**——一切"现在余额/累计"只许从业务账本推导并投影至 `MetricsInfo`；外层控制面 Event Bus **只承接系统级事件、报警/越限事件、以及对账失败事件**。

## R-BIZ-3 钱动必审（type: policy）

财务闸门动作（超预算、预算变更、对外付款类）默认高危审批档（Proposal 审批双路 + ApprovalNeeded 事件）；agent 对预算只有提案权，无写权（P6）。

## R-BIZ-4 流必须声明（type: lint）

数据流/信息流每条必须在 DataDesign 声明 source→sink、幂等性、留痕口径（明确区分业务代码内部流与上报控制面的系统/报警/对账失败事件）；未声明的流不得投产（盲流=缺陷）。

## R-BIZ-5 无指标不上线（type: policy）

业务域投产前必须带 Metrics 声明（指标+阈值）；阈值只在声明面注册（声明面外谓词不绑定不即兴）；观测面只读，不反向改状态。

## R-BIZ-6 事务可回退（type: policy）

对外动作必须声明幂等性+undo 等级（WorkService.tools 契约：full|partial|none）；`undo: none` 的动作默认人审档；补偿=成对 cleanup op；做不到幂等的外部系统在 Connector 内包成幂等（P4）。

## R-BIZ-7 循环对账与对账失败上报（type: policy）

业务逐笔对账由业务代码循环执行；控制面账实对照/状态投影刷新/结算监督以 Workflow 循环运行（level-triggered、幂等、收敛语义——只有 InSync 没有"结完"）；**一旦业务对账失败必须向控制面抛出对账失败事件与 DriftReport**，禁止一次性"跑完即忘"或静默抹平差异。
