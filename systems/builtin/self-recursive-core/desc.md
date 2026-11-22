---
name: self-recursive-core-desc
docType: Desc
scope: self-recursive-core
---
# Desc — self-recursive-core

控制面本体（原 Core 概念的落地服务）。**是**：常驻最小进程（Apply/Event 分发/Workflow 引擎/Scheme/权限系统）+ ops 日志 DB。**不是**：不执行任务（Agent/dsh）、不连业务外部系统（Connector）、不含业务判断。实现细节（进程结构、点火、DB 选型）在 instance 仓 impl/self-recursive-core.md；代码在 workservice 仓。
