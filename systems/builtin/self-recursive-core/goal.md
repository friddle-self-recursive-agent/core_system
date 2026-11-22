---
name: self-recursive-core-goal
docType: Goal
scope: self-recursive-core
ownerRefs: [{kind: ServiceDesc, name: self-recursive-core}]
---
# Goal — self-recursive-core

## intent

维持整个控制面的存在与自洽：文档面可信（Apply 唯一写路径+准入）、事件不丢不淹、Workflow 引擎按声明运转、ops 流水可查（git=文档版本，DB=操作日志，R1.5.4）。自身也是被管对象：用本系统管理本系统。

## acceptance

- A1. Igniter 冷启动后 Core 在 60s 内进入 Available，且 SelfConsistent=True（scheme 与文档库实际内容一致）。
- A2. 任意写入旁路（直接 git commit 文档区）被 pre-receive/对账发现，24h 内 drift 报告出现。
- A3. ops 日志（DB）与 git 提交一一对应（对账脚本零差异）。
- A4. Event 死信率 < 0.1%，巡检兜底每 10m 至少一轮。
