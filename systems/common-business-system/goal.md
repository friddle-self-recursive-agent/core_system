---
name: common-business-system-goal
docType: Goal
scope: common-business-system
ownerRefs: [{kind: ServiceDesc, name: common-business-system}]
---
# Goal — common-business-system

## intent

给一切企业业务实例提供统一的约束底座：企业实际运行状态的数据流/信息流设计与循环管控纪律（状态/财务/业务/监控/事务五域），全部落在 core-system 既有机制上，零新机制、零业务逻辑。第一实例=sybran-business-system（公司 OneDev 私有仓）。

## acceptance

- A1. 五域约束各有机制承载且可指认（StateModel/Finance DocType 注册在册；流域=DataDesign、监控域=Metrics、事务域=tools undo 契约、循环=Workflow 对账）——域↔机制映射表零空项。
- A2. R-BIZ-1..7 全部入库为 Rule 条目且可被实例继承引用（ruleId 稳定）。
- A3. 状态域 dogfood 成立：Proposal 对象满足 R-BIZ-1（闭合集+显式迁移+主体纪律）——既有事实，作对照锚。
- A4. 实例继承路径可走通：sybran 实例按"继承基词表→特化扩充"落骨架仓，继承不复制机制（实例仓零机制定义）。
