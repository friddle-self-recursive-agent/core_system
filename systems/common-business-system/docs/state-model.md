---
name: biz-state-model
docType: StateModel
scope: common-business-system
ownerRefs: [{kind: ServiceDesc, name: common-business-system}]
---
# StateModel — 通用业务状态基词表（实例继承的缺省词表）

## objects

| 对象族 | 说明 | 现实态承载 |
|---|---|---|
| 提案/请求族 | 要办事（Proposal 为首个 dogfood） | 对象 Status |
| 单据族 | 订单/工单/报销等实例化时扩充 | 对象 Status |
| 事项族 | 待办/审批事项 | 对象 Status |

（实例层在此表上扩充具体对象，本层不定义具体业务对象——零业务逻辑。）

## transitions

基词表（闭合集；实例可**新增**状态词、可**收紧**主体纪律，不可改名、不可放宽 P2）：

```
draft（草稿）→ submitted（已提交）→ approved（已批准）→ executing（执行中）→ done（已完结）
submitted → rejected（已驳回）
任意态 → cancelled（已取消，留痕）
```

| 迁移 | 主体纪律 | 留痕 |
|---|---|---|
| draft→submitted | 提出人 | apply_log（proposer 回链） |
| submitted→approved / rejected | 审批主体（人审档或自动批准分流） | approval_log |
| approved→executing | 执行体 | run/session 审计 |
| executing→done | 执行体+验证通过（Verifying 判据） | VerifyDoc 探针结果 |
| *→cancelled | 有权限者 | apply_log |
