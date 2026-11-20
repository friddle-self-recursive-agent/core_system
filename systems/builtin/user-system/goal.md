---
name: user-system-goal
docType: Goal
scope: builtin-user-system
ownerRefs: [{kind: ServiceDesc, name: builtin-user-system}]
---
# Goal — builtin-user-system

## intent

维护"人是谁、怎么联系、持有哪些 role"的权威目录：builtin 本地用户表起步，零外部依赖；为 Bind（role 持有）与 Notification（通道解析）供数据。

## acceptance

- A1. Bind.status.holders 与 user.spec.roles 双向对账零差异（每日探针）。
- A2. 任一 critical Notification 能解析到至少一个可达联系人（contact 探测）。
- A3. 用户变更 100% 人审留痕（ops DB）。
- A4. IdP 接入演练：authentik 以 WorkService 形态 adopt 后，用户表可切投影且可回退（未来可行性项，见 instance feasibility §13）。
