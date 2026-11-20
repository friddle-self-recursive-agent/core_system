# Bind — Role 绑定（权限插入点）

| 项 | 值 |
|---|---|
| K8s 对照 | RBAC 的 Role/RoleBinding（角色，不是人） |
| 形态 | 对象：`global/binds/<name>.yaml`（对象 ↔ role） |
| 作用域 | Global（可限定系统域） |
| 状态 | 设计稿 v0.4（R3 重写：bind 是 role，不是 bind 人） |

## 1. 定义

**Bind 绑定的是 role，不是人**（A34）。人属于用户系统（concepts/user-system.md）。一个 Bind 声明"某对象（Agent/系统/…）上存在某 role"；哪些用户持有该 role 由用户系统分配。

责任模型（R3 重定义，A35）：

- **默认责任上溯**：没有 owner 强制。信息/升级默认**往上走，走到 root agent**——每个对象的默认处理者是它 owner 链向上的第一个（最终是 root）agent。
- **Bind = 权限插入**：bind 的作用是往对象上插一个 role，持有该 role 的用户**可以去处理这个 agent**。
- **默认 bind 与根同时处理**：绑定了 role 的对象，其事项同时流向 root agent（上溯通道）与 role 持有者（插入通道）——双通道并行，不是单点责任。

## 2. 边界

**是**：对象↔role 的绑定 + 权限插入语义。

**不是**：
- 不是"绑人"（人在用户系统；Bind 只认 role）；
- 不是审批流引擎（没有 SLA/超时机器，R3 删除：催办与告知由 Notification 承担）；
- 不是强制 owner 登记（无主对象合法，默认上溯 root）；
- 不承载硬编码约束（如"审批人不得等于执行人"——这类约束走 **Rule/Policy 数据**表达，不写死代码，A36）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Bind
metadata:
  name: ci-approver-bind
  scope: global
spec:
  role: approver                 # role 名（builtin 词表：owner/approver/oncall/watcher；可自定义）
  on: agent/ci-repair-agent      # 绑定对象（可多个）
  # 持有者在用户系统：user.spec.roles 引用本 Bind（或 user-system 同步）
status:
  holders: [u-zhang]             # 由 user-system 回写（投影，非权威）
```

## 4. 生命周期

创建（对象需要人介入时才建，不是必填）→ role 持有者可处理该对象（与 root 并行）→ 对象删除则级联 → role 空置仅告警不阻塞（默认上溯兜底）。

## 5. 与其他概念的关系

- **UserSystem**：用户与 role 持有关系；Bind.status.holders 是其投影。
- **Agent/Loop/Workflow 的 Escalate**：升级默认走 root agent；有 Bind 的对象同时通知 role 持有者（Notification 送达）。
- **Policy**：审批档位可按 role 配置（如 approver role 放行某类动作）；**约束类规则（如审批人≠执行人）以 Rule/Policy 数据表达**（示例规则库提供模板，引用即用，不进代码）。

## 6. 设计规则

1. Bind 只认 role；人只在用户系统出现。
2. 无主对象合法；信息流默认上溯 root agent。
3. 有 Bind 的对象：root 与 role 持有者**同时**收到事项（双通道）。
4. role 词表：builtin 四个（owner/approver/oncall/watcher），自定义 role 需 Scheme 注册命名前缀。
5. "审批人不得等于执行人"等治理约束：**不在代码里写死**——以引用型 Rule（Rule 文档/Policy 规则）实现，示例规则库存模板（A36）。
6. Bind 变更走人审（它是"谁能插手"的答案）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| root 成为兜底瓶颈 | ⚠️ 中 | 无 bind 的对象全走 root | root 默认 ask 级（A30），事项转 Notification 告知相关人；观测面"root 待办数"指标 |
| 双通道重复处理 | ⚠️ 低 | root 与 role 持有者都动手 | 处理动作幂等（P4）；SessionLog 可见谁先动 |
| role 持有者与用户系统漂移 | ⚠️ 低 | holders 投影过期 | user-system 为权威，投影带 lastSync；对账探针 |

**结论：可行。模型比 v0.2 更简（删 owner 强制与 SLA 机器），root 兜底 + 双通道语义清晰。**

## 8. 原始设计标注

- A34（R3）：Bind=role（非 bind 人）；用户系统新概念（builtin 默认，未来评估 authentic/authentik 接入）。
- A35（R3）：取消"必须有 owner"；默认责任上溯 root agent；bind=权限插入，默认与根同时处理。
- A36（R3）：取消 approver≠executor 硬规则——改为引用型 Rule 约束，不写死代码。

## 9. 待决问题

见 open-questions.md#bind

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
