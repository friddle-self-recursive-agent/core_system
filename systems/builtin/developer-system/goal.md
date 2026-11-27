---
name: developer-system-goal
docType: Goal
scope: builtin-developer-system
ownerRefs: [{kind: ServiceDesc, name: builtin-developer-system}]
---
# Goal — builtin-developer-system

## intent

从提交到可部署产物的连续流水线：源码管理（**本地 git 仓库——工作区内目录即仓，origin 可配置 push 远程**）、构建（本地 build）、质量门禁、产物入库（storage-system）。全程由 Workflow 对账：流水线现实与本文档声明不一致时自动修复或升级。**builtin 零外部依赖：与 onedev/任何部署目标）无关——远程 SCM/CI 只是 workflow 节点的可插拔绑定变体**（impl/developer-system.md §0 通用抽象；部署实例=业务侧开发实例仓，private）。

## acceptance

- A1. push → 构建启动 p95 < 3min（本地 build，无队列远端）。
- A2. 主分支红线（测试+lint）100% 执行，无旁路合并。
- A3. 构建产物 100% 入库 storage-system 本地 files/（digest 命名），可回溯到 commit。
- A4. 任一阶段失败 → Event(critical) → Bind oncall 5min 内可达（审计可查）。
- A5. 满足"开始的循环"：本地 git commit → Event → Agent → TaskScheme(build) → dsh 本地执行 → verify → Status（零外部依赖首圈；详见 instance 仓设计 §首圈走查）。
