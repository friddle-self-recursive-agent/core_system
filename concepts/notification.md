# Notification — 通知（一个 Scheme 一个 Instance）

| 项 | 值 |
|---|---|
| K8s 对照 | Alertmanager 的 route/receiver 声明化 |
| 形态 | 类型（Scheme 注册）+ 实例对象：`global/notifications/<name>.yaml` |
| 作用域 | Global（可按系统覆盖） |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. 定义

Notification 是"把系统里该让人知道的事送到人面前"的声明：**一种通知渠道配置 = 一个 Scheme 注册的类型 + 一个可创建的实例**。触发源接 Event（ApprovalNeeded/Escalate/critical 事件），路由目标接 role 持有者（人经用户系统解析），通道走 Provider（im/email/webhook）。

"一个 Scheme 一个 Instance"的含义：Notification 的**类型**（如 im 通知、邮件通知、webhook 回调）注册进 Scheme；每个渠道落一个**实例**对象——新增渠道=建实例，不改代码。

## 2. 边界

**是**：出站通知的路由与通道声明。

**不是**：
- 不是 Event（Event 是系统内信号；Notification 是出站送达——Event 触发 Notification，反之不成立）；
- 不是 Role（Role 定权限与挂载；Notification 定"怎么送到人"；送达对象默认解析 Role.on 持有者，无挂载则 root agent）；
- 不是观测面（观测面是人主动看；Notification 是系统主动喊）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Notification
metadata:
 name: approval-im
 scope: global
spec:
 channel:
 kind: im # 类型标注（Scheme 注册的通知类型）
 provider: provider/im-feishu # 通道账号包
 on:
 events: [ApprovalNeeded, Escalate, HeartbeatLost]
 severity: [critical, warning]
 route:
 to: role-holders # ：解析 Role.on 挂载关系的持有者（用户系统投影）；无挂载则 root agent
 dedup: {window: 10m} # 同因聚合，防轰炸
 template: {ref: ref/notify-tpl} # 文案模板（可无，用 builtin）
status:
 delivered: {last24h: 12, failed: 0}
```

## 4. 生命周期

登记（走 Provider 校验：channel 可达性探测）→ 订阅事件 → 送达（含去重、失败重试→降级备用渠道）→ 静默窗口（oncall 值班表联动可选）→ 注销。

## 5. 与其他概念的关系

- 上游：Event 总线（按 on.events+severity 订阅）。
- 下游：Provider（im/email/webhook 的账号与通道）→ ConnectorOps（非直连时）。
- 对象：Role 挂载（route.to=role-holders 时解析 Role.on 的持有者）。
- Workflow 的 Escalate 出口、权限系统 的 ApprovalNeeded 默认接一个 Notification 实例（缺省 `approval-im`）。

## 6. 设计规则

1. critical 必须有可达通道（无 Notification 覆盖 critical 的系统，权限系统 建系统时警告——通知面不许悬空）。
2. 去重窗口强制（同 dedupKey 聚合）；失败重试后降级（im→email→webhook 日志）。
3. 通知内容不携带敏感明文（凭证/密钥模式扫描同规则）。
4. 送达记录进 ops DB（approval/escalate 关联审计）。
5. **通知阶段门**（v0.35，KI-001 邮件风暴根因 3/4 的机读落点）：通知只由**相位终态事实**触发——事件轴=人注意终态族（ApprovalNeeded 审批提升、Escalate 升级、HeartbeatLost 心跳丢失、SessionStalled 会话停滞（KI-003——停滞是人注意事实，与 HeartbeatLost 同族活性终态））恒放行；run 轴=其余事件（DocApplied 等进度事实）须 involved owner 现势 run 相位已达终态（声明序列尾=Report 相位完成，或终点锚）背书，无 run 证据面=fail-closed 拦。**apply 写入不触发用户通知**（apply ≠ 阶段完成）；被门事件照常留痕、归档、推进 run（门只作用于用户通知面，拦阻计数 gated 可查询）。送达面同窗三闸有序：minLevel 等级过滤（on.levels 声明）→ 阶段门 → dedup.window 聚合（窗口内同 dedupKey 至多一封，其余 deduped 计数可查询不投影——判别器：同键窗口内 N 次注入实发 1）。
6. **bind 用户通道与页面兜底（KI-003 上报面）**：通知的默认送达对象＝会话 bind 用户与 Role.on 持有者。**通道按已配置为准**：bind 用户（或 Notification 实例）配置了什么通道就走什么通道（email/im/webhook）；**未配置任何通道 = 不 notify**——不外发、不推送、不发邮件，该条通知**只在页面展示**（console 通知中心/会话页：等级、对象链、证据指针）——「没有 notify 就不 notify」。审批升级（ApprovalNeeded/Escalate）与会话停滞的人工上报同此口径；外发面照常受阶段门与 dedup.window 约束（规则 5），页面展示不受 dedup 抑制。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 通道依赖外部可用性 | ⚠️ 低 | IM webhook 可能失败 | 重试+多渠道降级+失败入死信告警 |
| 通知轰炸 | ⚠️ 中 | 事件风暴连带 | dedup 窗口+severity 过滤+速率上限 |

**结论：可行。Alertmanager 已验证的模式，声明化无新风险。**

## 8. 待决问题

见 open-questions.md#notification

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
