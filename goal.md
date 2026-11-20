---
name: goal
docType: Goal
scope: core_system
ownerRefs: [{kind: ServiceDesc, name: core_system}]
---
# Goal — core_system

## intent

用 K8s 的逻辑管理 AI Agent 与系统：意图、约束、数据流全部落文档（声明），由永续 Loop 把现实拉齐到声明（R0.1–R0.6）。文档是运行时控制面，不是设计稿归档；机制不假设模型能力，模型越强收敛越快、自治空间越大。

本仓自身按同一套概念自我管理：本仓=ServiceDesc，instance 仓=ServiceInstance，workservice 仓=代码与内置 Connector（R1.1）。

## acceptance（可验收条款）

- A1. 三仓各归其位：声明改在 core_system（改文档=改系统）；实现形式与可行性在 core_system_instance；可执行代码在 core_system_workservice。跨仓职责错位即 drift。
- A2. 冷启动闭环：Igniter → SelfRecursiveCore → 四个 builtin service 全部 InSync，全程无需人工编辑任何运行时状态（bootstrap.md）。
- A3. 任一 builtin service 的 Goal.acceptance 均可被 Verifying 阶段以数据判定（MetricsInfo/Connector.verify），无"凭感觉验收"。
- A4. 一次真实 Loop 走通：外部变化 → Event → Agent（dsh 基座）→ TaskScheme → 代码执行 → 验证 → Status 追平 → 观测面可见（首个对象：developer-system，见 instance 仓）。
- A5. install service 全程可审计：从 GitHub org 发现 template → WorkServiceTemplate → 询问 → 安装，每步留痕（R1.4）。
- A6. 总控界面两层视角可用：资源视角第一层（所有资源类型可逐个点入、资源相关皆可点入）、信息流视角第二层（监控/状态/数据事件）（R1.5）。
