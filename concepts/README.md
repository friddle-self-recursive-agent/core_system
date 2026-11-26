# 概念文档总索引（终态制）

> 每个概念一份文档，统一模板：定义 / 边界 / 对象结构 / 生命周期 / 关系 / 设计规则 / 可行性 / 待决问题 / 审阅标注区。
> 终态制（[rule.md](../rule/rule.md)）：本表与各文档只展示最终结果；被删除/合并的概念不留墓碑，历史只在 git 历史。

## 核心概念

| 文档 | Kind | 一句话 | K8s 对照 |
|---|---|---|---|
| [core.md](core.md) | — | 控制面（dsh plugin 承载） | apiserver+etcd+controller-manager |
| [scheme.md](scheme.md) | Scheme | 类型注册表 + 事件路由表 | scheme/CRD 注册 |
| [agent.md](agent.md) | Agent | 执行与收敛单元（dsh 会话；AUTOLEVEL） | Pod/Job + controller |
| [servicedesc.md](servicedesc.md) | ServiceDesc | 系统声明=一组文档 | Deployment Spec |
| [serviceinstance.md](serviceinstance.md) | ServiceInstance | 声明的现实化 | Pod + status |
| [workservice.md](workservice.md) | WorkService | 外部系统完整管理描述（六面体） | Node + exporter |
| [connector.md](connector.md) | ConnectorOps | 工具调用面 | 已装工具入口 |
| [ref.md](ref.md) | Ref | 声明式逻辑引用（要什么，不写在哪） | Service 名/DNS |
| [builtin.md](builtin.md) | Builtin | 起源标记（core_system 自带开发） | kube-system（仅自带类比） |
| [event.md](event.md) | Event | 短生命周期信号（log 式 Level；dsh 队列） | Event/watch |
| [apply.md](apply.md) | — | 文档面唯一写路径 = 系统间调用 | kubectl apply |
| [workflow.md](workflow.md) | Workflow | 循环本体（触发→整理→处理→回归；Workflow=其实例） | Controller/Reconciler + 相位机 |
| [proposal.md](proposal.md) | Proposal | 需求提案（console 提需求→审批→派工的一等对象） | Issue/Enhancement 提案 |
| [task-scheme.md](task-scheme.md) | TaskScheme | 确定性步骤图（四层执行第三层） | Job spec |
| [template.md](template.md) | Template | 统一模具×四层 appliesTo（要求语义/Resolver/逐层询问） | Helm Chart |
| [business-system.md](business-system.md) | — | 企业业务系统层（common-business-system 约束库：状态/财务/业务/监控/事务五域纪律，零新机制） | K8s 之上应用语义层 |
| [provider.md](provider.md) | Provider | 外部能力账号包（auth.secret 内化） | Secret+ConfigMap+Endpoint 聚合 |
| [notification.md](notification.md) | Notification | 通知渠道（一 Scheme 一 Instance） | Alertmanager route |
| [user-system.md](user-system.md) | User | 用户目录（builtin 本地表） | — |
| [permission.md](permission.md) | Role/Group | 权限系统（scope 域；只绑 role；灵活判定） | RBAC |
| [skill.md](skill.md) | Skill | 工具使用缓存（会话层经验） | — |
| [doctype.md](doctype.md) | DocType | 文档类型注册（本系统的 CRD） | CRD 机制 |
| [scope.md](scope.md) | — | 四层作用域（目录即 scope） | Namespace |
| [revision.md](revision.md) | — | 版本管理（乐观锁/审计/语义 diff） | resourceVersion + audit |
| [context.md](context.md) | — | 上下文装配（索引/检索/压缩/缓存/背景会话） | —（informer 缓存 + 调度 predicate） |
| [attention.md](attention.md) | — | 关注报告（读侧派生：值得关注/不值得关注+证据链，默认主界面） | —（告警摘要的人话归并） |

## 边界矩阵（一屏总览）

| 概念 | 管意图还是现实 | 内部还是外部 | 唯一存在理由 |
|---|---|---|---|
| ServiceDesc | 意图 | 内 | 说清系统应该是什么 |
| ServiceInstance | 现实快照与证据 | 内 | 证明系统现在是什么 |
| WorkService | 外部系统的六面体描述 | 外 | 把外部系统（含代码仓库）纳入管控面 |
| Agent | — | 内 | 干活与收敛 |
| ConnectorOps | — | 边界 | 工具调用面 |
| Ref | 声明 | 外 | 说要什么；地址由 owning system 给 |
| Event | 现实边沿 | — | 触发"看一眼" |
| MetricsInfo | 现实序列 | — | 支撑判断与验证 |
| Core/Scheme | 机制 | 内 | 让以上一切成立 |
| common-business-system | 意图（约束） | 内 | 企业语义怎么落既有机制（状态/财务/业务/监控/事务五域纪律，零新机制） |
| AttentionReport | 现实（只读派生） | 内 | 回答"现在该看什么"（不是事实源、不是文档对象） |
