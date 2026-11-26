---
name: common-business-system-desc
docType: Desc
scope: common-business-system
ownerRefs: [{kind: ServiceDesc, name: common-business-system}]
---
# Desc — common-business-system

**是**：core-system 之上的通用企业服务模型（约束层）：针对企业实际运行状态的数据流/信息流设计与循环管控纪律。产出=DocType（StateModel/Finance）+ R-BIZ 规则集 + 通用状态基词表。

**不是**：不做业务逻辑（履约/记账引擎/报表属于实例层）；不新增 kind 或执行机制（约束全部落在已注册机制上）；不是组织人事系统（"人是谁"在 user-system）；不是 ERP。

概念全文见 [concepts/business-system.md](../../concepts/business-system.md)；机读落地口径见 instance 仓 runtime/business-system.md。
