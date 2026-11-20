---
name: builtin-connector-goal
docType: Goal
scope: builtin-connector
ownerRefs: [{kind: ServiceDesc, name: builtin-connector}]
---
# Goal — builtin-connector

## intent

提供全局默认 ConnectorOps，让任何新系统零配置即有最小操作能力（文档读写/本机执行/HTTP 出站）；同时作为"每个 ServiceInstance 自己实现 connector"的遮蔽基线。

## acceptance

- A1. 三个默认 ops（gitfs/dsh/http）探活常绿；provider 版本升级灰度（先一个 Instance 引用新版）。
- A2. 任何 ops 被实例遮蔽时，全局默认版仍可用于对账（两版 diff 可查）。
- A3. dsh ops 每次调用审计入 ops DB；白名单外命令 100% 人审。
