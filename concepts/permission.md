# Permission — 权限系统（接替已删除的 权限系统）

| 项 | 值 |
|---|---|
| K8s 对照 | RBAC（Role/RoleBinding/Group）+ 准入的权限部分 |
| 形态 | Kind：`Role`（global/roles/）、`Group`（global/groups/）；User/Bind 已有 |
| 作用域 | Global |
| 状态 | 设计稿 v0.9（R8 新增：权限系统 概念删除，准入并入，A44/A45） |

## 1. 定义

权限系统是唯一的授权与准入机制（原 权限系统 概念删除，A44）。四条骨架：

1. **权限域按 scope**：global 有 global 权限（管 global 起头的对象与全局动作）；**system 开头的有 system 权限**（各系统域内对象由该系统权限管）。对象落在哪个 scope，就受哪层权限管（scope.md 联动）。
2. **默认 `global/admin` 拥有所有权限**（内置 role，不可删、不可降权——锁死管理的最后一道门）。
3. **一切只绑 role**：权限只授予 role；**用户绑 role**（user→role）、**用户绑 group**、**group 绑 role**（user→group→role）。**用户和 group 都不直接绑权限**——没有例外通道。
4. **Agent 权限判断不限死**：Agent 的动作权限=其绑定 role 的并集（ConnectorOps/Ref/Provider/文档域）；**由谁判定是灵活的**——可以是 agent 自治判定（auto 级）、role 权限表、或**上级 agent**（父级审批/裁剪）。**跨系统**：系统 A 的 agent 需要系统 B 的 agent 协助或询问时，**由 B 侧判定**（B 的 agent/role/上级 agent 任一合法判定方）——被请求方持有裁判权，A 侧不能自判通过。

## 2. 边界

**是**：授权（谁能在哪个 scope 做什么）+ 准入的权限与风险部分（人审拦截）。

**不是**（原 权限系统 四职责的重新分工，A44）：
- 不管结构校验（必填段/枚举）→ 归 Scheme/DocType；
- 不管一致性校验（owner 无环、引用存在）→ 归引擎；
- 不是审批流引擎（人审动作=ApprovalNeeded 事件+Notification 送达，无 SLA 机器）；
- 硬规则（builtinRoot 不可删等三条）是本系统**内置项**（代码级、不可配置放宽）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Role
metadata: {name: devtools-admin, scope: global}
spec:
  permissions:
    - {scope: "systems/developer-system/*", actions: [read, write, approve]}
    - {scope: "ops/onedev-ci", actions: [call]}
---
apiVersion: core/v1
kind: Group
metadata: {name: devtools-team, scope: global}
spec:
  roles: [role/devtools-admin]      # group 只绑 role，不绑权限
---
# User.spec 增补（user-system.md 联动）：
#   roles: [role/devtools-admin]           # 用户绑 role
#   groups: [group/devtools-team]          # 用户绑 group→role
# builtin: role/global-admin（全权限，不可删）
```

## 4. 判定流程（Agent 动作）

```
动作请求（本系统内）
  → 判定方（灵活，声明在 Agent/Workflow，不限死）：
     a. agent 自治（autoLevel=auto/all，白名单内）
     b. role 权限表（查表：动作 ∈ role 并集）
     c. 上级 agent（父级审批；root 为终点）
  → 全部不过 = 拒绝 + 记审计；命中人审档 = ApprovalNeeded

跨系统（A 的 agent 请求 B 的 agent）
  → A 发请求（提案/询问），**B 侧判定**（B 的 agent/role/上级 agent）
  → B 判定留痕（SessionLog/审计）；A 无自判权
```

## 5. 与其他概念的关系

- User（用户系统）：用户↔role/group 的持有面。
- Bind：Bind 是"对象↔role"（谁可插手某对象）；权限系统是"role↔权限"（role 能做什么）。两层拼起来完整。
- Scope：权限域划分依据（global/system）。
- Workflow §7 跨权限三出路中的"审批提升"，人审档位由本系统配置。
- Apply：写路径的准入环节调用本系统（权限+人审）；结构校验另走 Scheme。

## 6. 设计规则

1. 权限只出现在 Role.spec；User/Group 出现权限字段即校验失败（防绕行）。
2. `global/admin` 内置全权限，任何显式 role 不得复制其不可删语义。
3. 判定方灵活但**判定必须留痕**（谁判的、依据什么、何时）——灵活性换可审计。
4. 跨系统裁判权永远在被请求方（B 侧）。
5. 原则 P7（权限随文档走）不变：改 role/绑定=改权限=高敏变更（人审）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 判定灵活→不可预测 | ⚠️ 中 | 同一动作不同判定方结论不同 | 规则 3 强制留痕+判定方声明化（Agent/Workflow 里写清楚谁判） |
| role 爆炸 | ⚠️ 低 | 每 system 一套 role | role 模板（builtin 常用集）+ group 聚合 |
| admin 滥用 | ⚠️ 低 | 全权限兜底被日常滥用 | admin 动作全量审计+观测面亮灯 |

**结论：可行。标准 RBAC 骨架 + 灵活判定层；复杂度与原 权限系统 相当但边界更清。**

## 8. 原始设计标注

- A44（R8）：权限系统 概念删除，准入并入权限系统；结构校验归 Scheme/DocType、一致性归引擎。
- A45（R8）：权限系统设计（scope 权限域、默认 global/admin 全权限、只绑 role、用户经 group/role、agent 判定灵活不限死、跨系统 B 侧裁判）。

## 9. 待决问题

见 open-questions.md#permission

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
