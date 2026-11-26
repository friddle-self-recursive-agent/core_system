---
name: goal
docType: Goal
scope: core_system
ownerRefs: [{kind: ServiceDesc, name: core_system}]
---
# Goal — core_system

## intent

用 K8s 的逻辑管理 AI Agent 与系统：意图、约束、数据流全部落文档（声明），由永续 Workflow 把现实拉齐到声明（R0.1–R0.6）。文档是运行时控制面，不是设计稿归档；机制不假设模型能力，模型越强收敛越快、自治空间越大。

**这是一个企业级内置 agent 系统**（2026-11-26 用户裁决）：agent 系统内生于企业运行面——不是外挂工具，而是组织的基础设施层；人只做简单、无副作用的使用（对话提需求、看结果），概念（workflow/scheme/权限）是为保运行、保可查、不失控而存在的机制层，默认不对使用者前置。

本仓自身按同一套概念自我管理：本仓=ServiceDesc，instance 仓=ServiceInstance，workservice 仓=代码与内置 Connector（R1.1）。

## acceptance（可验收条款）

- A1. 三仓各归其位：声明改在 core_system（改文档=改系统）；实现形式与可行性在 core_system_instance；可执行代码在 core_system_workservice。跨仓职责错位即 drift。
- A2. 冷启动闭环：Igniter → SelfRecursiveCore → 四个 builtin service 全部 InSync，全程无需人工编辑任何运行时状态（bootstrap.md）。
- A3. 任一 builtin service 的 Goal.acceptance 均可被 Verifying 阶段以数据判定（MetricsInfo/Connector.verify），无"凭感觉验收"。
- A4. 一次真实 Workflow 走通：外部变化 → Event → Agent（dsh 基座）→ TaskScheme → 代码执行 → 验证 → Status 追平 → 观测面可见（首个对象：developer-system，见 instance 仓）。
- A5. install service 全程可审计：从 GitHub org 发现 template → WorkServiceTemplate → 询问 → 安装，每步留痕（R1.4）。
- A6. 总控界面首屏=关注报告×对话：值得关注/不值得关注+证据链，旁边可直接开聊（R-UX-6）；对象详情=通用工作台（tag/规则/ctx/操作/scheme，R-UX-7）；系统树与信息流作为钻取视图可用（资源可逐个点入、监控/状态/数据事件可查）。
