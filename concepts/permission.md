# Permission — 权限系统

| 项 | 值 |
|---|---|
| K8s 对照 | RBAC（Role/RoleBinding/Group）+ 准入的权限部分 |
| 形态 | Kind：`Role`（global/roles/）、`Group`（global/groups/）；User 由 user-system 提供（人↔role 持有面） |
| 作用域 | Global |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. 定义

权限系统是唯一的授权与准入机制（原 权限系统 概念删除）。四条骨架：

1. **权限域按 scope**：global 有 global 权限（管 global 起头的对象与全局动作）；**system 开头的有 system 权限**（各系统域内对象由该系统权限管）。对象落在哪个 scope，就受哪层权限管（scope.md 联动）。
2. **默认 `global/admin` 拥有所有权限**（内置 role，不可删、不可降权——锁死管理的最后一道门）。
2a. **登录的 builtin 最小实现**：默认用 **dsh 的 token** 即可（dsh 下直接复用，先不单独建用户登录系统，以后再写）；user-system 必须提供一组 ConnectorOps 让登录非常方便（认证协议实现：login/me/token 交换）。本条是最小起步路径，不是永久形态。
2b. **builtinRoot 挂内置 `global/admin`**（默认内置绑定，不可更改：不可删/不可换绑/不可降权）——root **有权限标志、走统一权限管理**，无任何旁路；其"最高权限"来自该 role 的授权面，不是身份特权。
3. **一切只绑 role**：权限只授予 role；**用户绑 role**（user→role）、**用户绑 group**、**group 绑 role**（user→group→role）。**用户和 group 都不直接绑权限**——没有例外通道。
3b. **对象挂 role**（原 Bind 并入）：`Role.spec.on: [对象]`——哪个 Agent/系统挂了这个 role；持有者可处理该对象（与 root 双通道， 语义不变）。
4. **Agent 权限判断不限死**：Agent 的动作权限=其绑定 role 的并集（ConnectorOps/Ref/Provider/文档域）；**由谁判定是灵活的**——可以是 agent 自治判定（auto 级）、role 权限表、或**上级 agent**（父级审批/裁剪）。**跨系统**：系统 A 的 agent 需要系统 B 的 agent 协助或询问时，**由 B 侧判定**（B 的 agent/role/上级 agent 任一合法判定方）——被请求方持有裁判权，A 侧不能自判通过。

## 2. 边界

**是**：授权（谁能在哪个 scope 做什么）+ 准入的权限与风险部分（人审拦截）。

**不是**（原 权限系统 四职责的重新分工）：
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
 on: [agent/ci-repair-agent] # ：对象挂载（原 Bind.role/on 并入）
 permissions:
 - {scope: "systems/developer-system/*", actions: [read, write, approve]}
 - {scope: "ops/onedev-ci", actions: [call]}
---
apiVersion: core/v1
kind: Group
metadata: {name: devtools-team, scope: global}
spec:
 roles: [role/devtools-admin] # group 只绑 role，不绑权限
---
# User.spec 增补（user-system.md 联动）：
# roles: [role/devtools-admin] # 用户绑 role
# groups: [group/devtools-team] # 用户绑 group→role
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

人审档机读判定（首段，event.md 规则 9 联动）：**写路径权限准入拒绝 ∧ 被拒对象属授权面装载类（kind ∈ Role|Group——本系统装载进权威快照的对象即授权面本体）**。锚=规则 5/P7「改 role/绑定=改权限=高敏变更（人审）」：对授权面自身的写被拒，说明有主体在试图变更权限结构——这正是需要人知悉/人审的档位，写路径引擎据此自产 ApprovalNeeded（source=permission，主路 notification/* 送达 role 持有者）。两处边界：**hard rules 拒绝≠人审档**（代码级不可放宽=永不可批，只拒绝+记审计，不产事件）；**dry-run 零副作用不产事件**。对象类清单可扩（User/Provider/builtin scope 等人审类随声明面扩展入表），首段只收 Role|Group 与装载面同源。

跨系统（A 的 agent 请求 B 的 agent）
 → A 发请求（提案/询问），**B 侧判定**（B 的 agent/role/上级 agent）
 → B 判定留痕（SessionLog/审计）；A 无自判权
```

## 5. 与其他概念的关系

- User（用户系统）：用户↔role/group 的持有面。
- 对象挂载：Role.on 承担"对象↔role"挂载；Role.status.holders 由 user-system 投影回写。
- Scope：权限域划分依据（global/system）。
- Workflow §7 跨权限三出路中的"审批提升"，人审档位由本系统配置。
- Apply：写路径的准入环节调用本系统（权限+人审）；结构校验另走 Scheme。
- Event 发布面：`publish` 动作 × `events` 资源域（concepts/event.md 规则 8）——与对象写（write × 对象 scope）分立的权限域，两域不互为准入。

## 6. 设计规则

1. 权限只出现在 Role.spec；User/Group 出现权限字段即校验失败（防绕行）。
2. `global/admin` 内置全权限，任何显式 role 不得复制其不可删语义。
3. 判定方灵活但**判定必须留痕**（谁判的、依据什么、何时）——灵活性换可审计。
4. 跨系统裁判权永远在被请求方（B 侧）。
5. 原则 P7（权限随文档走）不变：改 role/绑定=改权限=高敏变更（人审）。
6. **权限双态（2026-11-27 用户裁决）：默认直给 + 越权弹窗**：
   - **默认直给态**：权限默认不需要控制——**所有权限直接给**（agent 日常动作零审批摩擦，不逐条拦）；
   - **越权弹窗态**：显式越权/升级请求**默认触发弹窗授权**（内建默认，不依赖配置开启）——工具调用声明升级权限级别（如 `sandbox_permissions: danger-full-access`）并附 `justification` 理由时，走 ApprovalNeeded→控制台**授权弹窗**（人批=放行，拒=记录），复用既有审批闸锚（headless 询问同款通路），全程留痕；
   - 两态并存不矛盾：直给是日常默认，弹窗是**升险动作的强制闸**——请求方自己声明要越界，就必须当面拿到授权；`justification` 随审计账留存。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 判定灵活→不可预测 | ⚠️ 中 | 同一动作不同判定方结论不同 | 规则 3 强制留痕+判定方声明化（Agent/Workflow 里写清楚谁判） |
| role 爆炸 | ⚠️ 低 | 每 system 一套 role | role 模板（builtin 常用集）+ group 聚合 |
| admin 滥用 | ⚠️ 低 | 全权限兜底被日常滥用 | admin 动作全量审计+观测面亮灯 |

**结论：可行。标准 RBAC 骨架 + 灵活判定层；复杂度与原 权限系统 相当但边界更清。**

## 8. 待决问题

见 open-questions.md#permission

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
