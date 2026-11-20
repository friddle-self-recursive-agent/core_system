# Bind — 人与系统的绑定

| 项 | 值 |
|---|---|
| K8s 对照 | RBAC Binding + Scheduler 的 Binding（把决策落到具体执行者） |
| 形态 | 对象：global/binds/<name>.yaml |
| 作用域 | Global（可限定 system 域） |
| 状态 | 设计稿 v1 |

## 1. 定义

Bind 把**人**作为一等对象接进控制面：谁对哪个 Agent/系统负什么责任（owner）、谁审批什么级别的动作（approver）、谁被升级（escalation 链）、谁值班（oncall）。原稿"BIND 绑定相应用户"与 Loop 中"可配置 bind 人"共同落位于此。

## 2. 边界

**是**：人↔对象的**责任/审批**关系。它不是权限本体（权限=P7 的文档引用并集+Policy），它是"出事找谁、谁点头"。

**不是**：
- 不是 Credential（那是机器钥匙；Bind 是人的责任关系）；
- 不是组织架构同步（可以引用 LDAP/IM 的 Ref，但不负责保持同步——那是某个 WorkService+Connector 的事）；
- 不是审批流引擎：审批动作本身走 Policy 的 ApprovalNeeded Event → Bind 命中的人 → 人 Apply 决定。没有独立工作流组件。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Bind
metadata:
  name: developer-system-owners
  scope: global
spec:
  bindings:
    - {user: u-li,     role: owner,     on: system/developer-system}
    - {user: u-zhang,  role: approver,  on: agent/ci-repair-agent,
       when: {policySeverity: high-risk}}       # 只审高危动作
    - {user: u-wang,   role: oncall,    on: system/developer-system,
       schedule: ref/oncall-rota}                # 值班表可以是外部 Ref
  escalationChain: [bind/developer-system-owners, bind/platform-oncall]
  approvalSla: 4h            # 超时逐级升级
status:
  pendingApprovals: 1
  lastEscalation: {at: ..., to: u-wang}
```

## 4. 生命周期

创建（人审，Bind 自身属敏感对象）→ 生效（Policy/Loop 查它路由审批与升级）→ 人变动走 Apply → 失效（对象删除时其审批责任回落到 escalationChain 上一级）。

## 5. 与其他概念的关系

- Agent.spec.binds 引用 Bind（或内联简化写法，二者取一，见 open-questions）。
- Loop 的 Escalate 终点、Policy 的 ApprovalNeeded 路由目标都是 Bind。
- 它是"human-in-the-loop"的唯一挂点：模型弱时这里密、模型强时这里疏（P8 的可配置体现）。

## 6. 设计规则

1. 任何 Agent、任何系统必须有 owner（无主对象 Policy 拒绝创建）——责任不可悬空。
2. approver 与 executor 不得同一人审批自己发起的高危动作。
3. escalationChain 必须终点有人（最终落到平台 oncall），禁止空链。
4. Bind 变更走人审（它是"改谁能审批"的对象，天然高危）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 审批 SLA 无人响应 | ⚠️ 中 | 人是系统里最不可靠的组件 | escalationChain 逐级+SLA 超时；观测面亮"积压审批"指标 |
| 双写（Agent 内联 binds vs Bind 对象） | ⚠️ 低 | 两处配置漂移 | 规则定死一种（v1：Agent 内联引用 Bind 名，不内联展开） |
| 用户体系来源 | ⚠️ 低 | 本系统不管账号 | user 用外部身份标识（IM/LDAP id），验证委托给对应 Connector |

**结论：可行。风险在组织纪律不在技术；机制上 SLA+升级链兜底。**

## 8. 原始设计标注

- 原稿"BIND 绑定相应用户"（Agent 下）与 Loop"可配置 bind 人" → 统一为本对象，Agent 只引用。

## 9. 待决问题

见 open-questions.md#bind

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
