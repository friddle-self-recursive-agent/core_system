---
name: biz-finance
docType: Finance
scope: common-business-system
ownerRefs: [{kind: ServiceDesc, name: common-business-system}]
---
# Finance — 预算与闸门基线（实例继承底座）

## budget

| 段 | 约束 | 说明 |
|---|---|---|
| 科目声明 | 实例声明科目树（科目=意图，Spec 侧） | 本层不定科目（零业务逻辑）；只定"科目必须在册"纪律 |
| 预算额度 | 每科目带周期额度（period+limit） | 额度变更=提案（R-BIZ-3），agent 无写权 |
| 现状数字 | **禁止出现在本文档**（R-BIZ-2） | 现状=流水推导（事件归档+MetricsInfo 查询） |

## gates

| 闸门 | 触发 | 动作 |
|---|---|---|
| 科目超限 | 流水累计越过额度阈值（MetricThreshold） | ApprovalNeeded → 高危审批；agent 只能提案调额 |
| 大额动作 | 单笔超过实例声明的大额线 | 高危审批档 |
| 外部付出 | 对外付款/发函类（undo:none 动作） | 人审档（R-BIZ-6 联动） |

结算口径：月结/年结=对账 Workflow（R-BIZ-7），产出差异报告（Drift 语义）；差异必须可见，禁止静默抹平。
