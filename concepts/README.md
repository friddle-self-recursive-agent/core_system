# 概念文档总索引

每个概念一份文档，统一模板：定义 / 边界 / 对象结构 / 生命周期 / 关系 / 设计规则 / 可行性 / 原始设计标注 / 审阅标注区。

## 核心概念（原稿已有，边界重划）

| 文档 | Kind | 一句话 | K8s 对照 |
|---|---|---|---|
| [core.md](core.md) | — | 常驻最小控制面进程 | apiserver+etcd+controller-manager |
| [scheme.md](scheme.md) | Scheme | 类型注册表 + 事件路由表 | scheme/CRD 注册 |
| [agent.md](agent.md) | Agent | 执行与收敛单元 | Pod/Job + controller |
| [servicedesc.md](servicedesc.md) | ServiceDesc | 系统声明=一组文档 | Deployment Spec |
| [serviceinstance.md](serviceinstance.md) | ServiceInstance | 声明的现实化 | Pod + status |
| [workservice.md](workservice.md) | WorkService | 外部真实系统 | Node/External Provider |
| [connector.md](connector.md) | ConnectorOps + ConnectorProvider | 外部系统幂等驱动（v0.3 拆类型层/使用层） | CSI driver + Attachment |
| [ref.md](ref.md) | Ref | 第三方临时指针 | ObjectReference/ExternalName |
| [builtin.md](builtin.md) | Builtin | 起源标记（core_system 自带开发，v0.5 无强制语义） | kube-system（仅类比自带） |
| [event.md](event.md) | Event | 变化通知，只触发不修改 | Event/watch |
| [apply.md](apply.md) | — | 唯一写路径 = 系统间调用 | kubectl apply/SSA |
| [bind.md](bind.md) | Bind | 人↔Agent↔System 绑定 | RBAC Binding |

## 补充概念（原稿没有，按 K8s 边界补齐）

| 文档 | Kind | 补它是因为 |
|---|---|---|
| [loop.md](loop.md) | Loop | 收敛引擎要成为可配置的一等对象，而不是写死在代码里 |
| [status.md](status.md) | — | 没有 Spec/Status 分离就没有声明式 |
| [scope.md](scope.md) | — | "属于哪个 System 还是 Global" 需要正式的名字解析规则 |
| [selector.md](selector.md) | — | 事件路由、汇总观测需要跨对象选择 |
| [owner.md](owner.md) | — | Instance/SubAgent/Ref 的级联归属与 GC |
| [finalizer.md](finalizer.md) | — | 删除外部副作用必须两阶段（A7） |
| [doctype.md](doctype.md) | — | "文档类型"本身要能注册扩展（=CRD） |
| [policy.md](policy.md) | — | 文档即权限 ⇒ 必须有准入（A9） |
| [credential.md](credential.md) | Credential | Connector 访问外部系统的凭证不能散落代码里 |
| [revision.md](revision.md) | — | 多写者并发与审计（A8） |

## v0.2 新增概念（R1 运行时要求催生）

| 文档 | Kind | 补它是因为 |
|---|---|---|
| [plugin.md](plugin.md) | Plugin | R1.2.1：基础 agent=dsh，root 直控子 agent，总控界面——都需要插件机制承载 |
| [task-scheme.md](task-scheme.md) | TaskScheme | R1.2.3：四层执行（意图→Agent→Scheme→代码），长运行不依赖 Agent 即兴 |
| [template.md](template.md) | WorkServiceTemplate | R1.4：install service 的模板发现/询问/安装流程需要一个 builtin Scheme |

## v0.3 新增/重划概念（R2 修正催生）

| 文档 | Kind | 说明 |
|---|---|---|
| [connector.md](connector.md)（重写） | ConnectorOps + ConnectorProvider | R2：拆使用层/类型层；Agent 默认挂 ops；builtin 服务 connector 提供默认 ops（A25） |
| [workflow.md](workflow.md) | Workflow | R2：执行态机，ConnectorOps 必绑；任务态机=default-task builtin（A26） |
| [provider.md](provider.md) | Provider | R2：外部能力账号包（auth/config/connector 可空/secret）（A27） |
| [notification.md](notification.md) | Notification | R2：一个 Scheme 一个 Instance 的通知渠道（A28） |

## v0.4 重写/新增概念（R3 修正催生）

| 文档 | Kind | 说明 |
|---|---|---|
| [bind.md](bind.md)（重写） | Bind | R3：Bind=role（非绑人）；责任默认上溯 root；bind=权限插入、与根同时处理；删 SLA 机器（A34/A35） |
| [user-system.md](user-system.md) | User + builtin 服务 | R3：用户系统（builtin 本地表；未来评估 authentik 接入）（A34） |
| [apply.md](apply.md)（重写） | — | R3：Apply=文档面唯一写路径（版本管理），不约束 Agent 干活；no-op+白名单规则转正（A32） |
| [revision.md](revision.md)（重写） | — | R3：删字段级归属/SSA；文档 diff=LLM 语义 diff（提案制）（A33） |

## v0.6 简化/新增概念（R5 修正催生）

| 文档 | Kind | 说明 |
|---|---|---|
| [connector.md](connector.md)（重写） | ConnectorOps + ConnectorProvider | R5：生命周期极简（就是绑定）；impl 三形态 tool/image/source+Ref；命名解析（无前缀=默认 org，带前缀=GitHub）；yaml 含 scheme/usage/llmPrompt/download（A38） |
| [skill.md](skill.md) | Skill | R5：工具使用处缓存为 skill（会话层经验，按需注入）（A38） |

## 边界矩阵（一屏总览）

| 概念 | 管"意图"还是"现实" | 管内部还是外部 | 是数据还是声明 | 唯一存在理由 |
|---|---|---|---|---|
| ServiceDesc | 意图 | 内 | 声明 | 说清系统应该是什么 |
| ServiceInstance | 现实的快照与证据 | 内 | 声明(Status)+数据 | 证明系统现在是什么 |
| WorkService | 外部能力的声明 | 外 | 声明 | 把第三方纳入管理面 |
| Agent | — | 内 | 声明 | 干活与收敛 |
| ConnectorProvider / ConnectorOps | — | 边界 | 声明+代码 | 类型标注+幂等驱动（v0.3 拆分） |
| Ref | — | 外 | 声明 | 临时指路 |
| Event | 现实的边沿 | — | 数据 | 触发"看一眼" |
| MetricsInfo | 现实的序列 | — | 数据 | 支撑判断与验证 |
| Core/Scheme/Builtin | 机制 | 内 | 声明+代码 | 让以上一切成立 |
