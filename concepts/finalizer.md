# Finalizer —（已删除，A51 裁决采纳）

> **本概念已删除（v0.13，R12）**：不再有系统级两阶段删除协议。
> 外部副作用清理成为 **WorkService 的 tools/flows 职责**（workservice.md 规则 5：有外部创建动作的工具必须成对声明清理 op，Lint 强制）。
> 删除语义：删目录即级联（owner.md 墓碑）；清外部资源=执行该 WorkService 声明的清理流程（一次普通 Workflow 调用）。
