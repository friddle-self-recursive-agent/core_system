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
| 现状数字 | **禁止出现在本文档**（R-BIZ-2） | 现状=业务系统自有账本（Ledger，由业务代码与自有内部事件承接，严禁用控制面带去重的 Event Bus 当账本）推导并投影至 `MetricsInfo` 查询 |

## gates

| 闸门 | 触发 | 动作 |
|---|---|---|
| 科目超限 | 账本累计投影越过额度阈值（MetricThreshold 报警事件） | ApprovalNeeded → 高危审批；agent 只能提案调额 |
| 大额动作 | 单笔超过实例声明的大额线 | 高危审批档 |
| 外部付出 | 对外付款/发函类（undo:none 动作） | 人审档（R-BIZ-6 联动） |
| 对账失败 | 业务代码内部对账发现账实不符 | 向上抛出**对账失败事件** + `DriftReport` → 控制面告警与处置 Workflow |

结算口径：逐笔流水与内部对账由业务代码自己承接；外层控制面只收**系统级事件、报警/越限事件、对账失败事件**（R-BIZ-2/R-BIZ-7）；差异必须可见，禁止静默抹平。
