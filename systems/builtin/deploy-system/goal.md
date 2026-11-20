---
name: deploy-system-goal
docType: Goal
scope: builtin-deploy-system
ownerRefs: [{kind: ServiceDesc, name: builtin-deploy-system}]
---
# Goal — builtin-deploy-system

## intent

在当前机器上落地一切"应该存在的东西"：builtin 服务的安装、WorkServiceTemplate 的安装（R1.4 流程：GitHub org 找 template → 看描述 → 找 WorkServiceTemplate → 询问 → 安装）、以及外部 WorkService 的生命周期动作。

## acceptance

- A1. install 流程全程询问留痕：每个 TemplateFound 必须产生 ApprovalNeeded 且获用户确认后才执行安装。
- A2. 安装幂等：同一 WorkServiceTemplate 装两遍，第二遍 no-op。
- A3. 安装失败自动回滚（镜像/配置/服务三段 undo），机器不留半成品。
- A4. 安装完成的资源自动登记为 WorkService 对象 + finalizer 注入（副作用自动登记，finalizer.md 规则 1）。
