# core_system — 用文档管 AI Agent 的控制面

> 把"系统应该是什么"写进文档，用一个永续的收敛循环把"系统实际是什么"不停拉齐到它。
> 本仓不是设计稿归档：**它本身就是被这套机制管理的根声明**（ServiceDesc，用户术语 SystemDesc）——改这里=改系统（经 Apply + 权限系统）。

## 解决什么问题

今天管 AI Agent 靠三样手工活：反复黏贴上下文、堆护栏和人审兜底、写完就过期的设计稿。对应三个痛点：

1. **知识散落**——系统的意图、约束、数据流活在聊天记录、代码和人脑里；写不出来就审不了、也约束不了数据流向。
2. **文档漂移**——设计稿写完即归档，与真实系统渐行渐远；没有机制负责把现实拉回文档。
3. **盯人式管理**——管 agent 靠盯着它跑；模型一强，这些补丁全成多余，换模型又重做一遍。

core_system 的答案是把 K8s 的逻辑搬过来：**不把单个 agent 做得更强，赢在它上面那层**。

- **一切皆文档，文档皆对象**：被管理的东西（系统、Agent、连接、规则、权限）都以对象化文档存在——有类型、有 name、可引用、可校验。没有对象的文档是散文，没有文档的对象是黑箱。
- **文档=运行时控制面**：Spec（期望）由人经 Apply 写入，Status（现实）只能由系统回写；一致程度由 `observedGeneration` 表达。改文档=改系统，也=改权限。
- **管 agent 靠改文档**：agent 对着绑定的文档干活；它的权限面=引用的 ConnectorOps + Ref + Provider + Role 挂载的并集，再被权限系统裁剪。不靠盯着它。
- **机制不假设模型能力**：审批点、验证、幂等、dry-run 是机制的一部分，不因"模型应该没问题"而省略；严格程度可配置——模型越强，放宽配置，自治空间越大，机制不变。
- **收敛，而非完成**：Workflow 没有"跑完"，只有 `InSync`（此刻一致）；一致性是持续维持的属性。事件只是"该看一眼了"的信号，收到即全量对账——丢事件、乱序、重复都不会导致错误状态，最多多一次对账。

## 用户视角：你只做三件事

| 你的动作 | 是什么 |
|---|---|
| **改文档** | 改 Goal/Rule/Desc 经 Apply 落库=改系统；agent 代改的默认先进草稿缓存，你确认后才落库 |
| **批升级** | agent 收敛失败或拿不准时升级（Escalate）给人；它也可以提提案，由有权限者合入 |
| **看关注报告** | 总控首屏=关注报告（值得关注/不值得关注+证据链），旁边直接开对话；系统/工作流/事件/审批页是钻取面 |

剩下的活由四个面分工（职责单一，谁都不越界）：

| 层 | 组成 | 只负责 | 绝不负责 |
|---|---|---|---|
| 文档面 | ServiceDesc / ServiceInstance / 各对象声明 | 存意图与约束 | 执行任何动作 |
| 控制面 | Core 进程（Apply / Workflow 引擎 / Event 分发 / Scheme / 权限系统） | 校验存取文档、调度收敛 | 干活（干活是 Agent 的事） |
| 执行面 | Agent / Connector / WorkService | 收敛意图、驱动外部系统 | 定义意图 |
| 观测面 | Event 汇聚 / MetricsInfo / DriftReport（关注报告是读侧派生） | 让人看得见 | 反过来直接改状态 |

一次收敛闭环：

```
外部变化 → Event → Agent 分析（对着文档）→ 计划 → 执行（Connector 驱动外部系统）→ 验证
        → Status 追平 → 观测面可见 →（信号再触发下一轮全量对账）
```

熟悉 K8s 的话一屏对上（完整对照与差异见 [architecture.md](architecture.md)）：

| 本系统 | K8s | 一句话 |
|---|---|---|
| ServiceDesc | Deployment Spec | 系统应该是什么（一组异构文档） |
| ServiceInstance | Pod + status | 系统实际是什么（现实快照与证据） |
| Agent | Pod 执行体 + controller | 干活与收敛 |
| Workflow | Controller / Reconciler | 循环本体（一等对象，可启停、可配置触发源） |
| Apply | kubectl apply | 文档面唯一写路径 = 系统间调用的唯一形态 |
| 权限系统 | Admission | 文档即权限，准入必选 |
| WorkService | Node / 外部 Provider | 把外部系统（gitlab/jenkins/代码仓库/…）纳入管控面 |

## 三仓即三概念（自我示范）

这套机制管的第一个对象是它自己：仓库拆分就是三个概念的第一次落地。

| 仓库 | 概念角色 | 放什么 |
|---|---|---|
| **core_system**（本仓） | ServiceDesc | 声明：requirements 存档、Goal/Desc/Rule、概念定义（Scheme 层）、builtin 服务声明 |
| [core_system_instance](https://github.com/friddle-self-recursive-agent/core_system_instance) | ServiceInstance | 实现形式：ImplDoc/VerifyDoc、运行时设计（四层执行、dsh 插件、总控界面、ops 日志）、Workflow 管线与 bootstrap |
| [core_system_workservice](https://github.com/friddle-self-recursive-agent/core_system_workservice) | 代码 | Igniter、Core 进程、dsh 插件宿主、内置 Connector |
| [core_system_dsh_plugin](https://github.com/friddle-self-recursive-agent/core_system_dsh_plugin) | 代码（plugin 面） | dsh plugin 宿主 + connector 实现；core 本体 Go build 于 workservice 仓，经 submodule `core_system/` 指向最新 |
| 用法仓（**private**，托管于私域 SCM，地址不入公开仓） | 代码（用法型 connector） | 按部署用法决定的驱动（onedev/nas/oss）；workservice 仓 connectors/ 只收 builtin 驱动 |
| 业务实例仓（**private**，托管于私域 SCM） | 部署实例设计 | developer/deploy 的业务实例：节点绑定值与实测契约（私域 SCM adopt、部署渠道实例）；builtin 本体在其余四仓，零部署锚点（2026-11-26 裁决：业务侧内容=private 仓、托管私域 SCM） |
| [common_connector](https://github.com/friddle-self-recursive-agent/common_connector) | 代码（通用 connector） | 跨部署复用的通用 connector（通知/邮件 OpsConnector、SMTP；default user-system Event 默认通知） |

六个 builtin service（[systems/builtin/](systems/builtin/)）构成自举最小集：**self-recursive-core**（控制面本体）、developer-system（开发流水线）、deploy-system（安装执行）、storage-system（文档与产物存储）、connector（默认 Ops 宿主）、user-system（用户目录）。冷启动 = Igniter 点火 → Core 按文档把全部 builtin service 拉到 InSync，全程无需人工编辑运行时状态。

## 目录

```
core_system/
├── system.yaml / goal.md / desc.md      # 根 ServiceDesc 对象（含 acceptance 验收条款）
├── requirements/                        # 原始要求存档（背景 / 运行时 / workflow 平台 / agent pool）
├── principles.md                        # 10 条设计原则（冲突裁决依据）
├── architecture.md                      # 四层一面 / 边界决策树 / K8s 对照
├── rule/                                # 规则目录：rule.md 总文档 + rule_xxx.md 各方面（R-DOC-6 侧车随行）
├── concepts/                            # 概念定义（终态制，rule/rule.md）
├── doctypes/README.md                   # 文档类型注册表
├── core/scheme.yaml                     # 首版 Scheme：类型注册 + 事件路由 + 运行时基座
├── systems/builtin/                     # 自举最小集六个 builtin service 声明
├── *.md.metadatainfo                    # 每篇文档同目录侧车：tags[{tag,tag_type}] + importance 0-100（R-DOC-6）
└── open-questions.md                    # 活问题清单（现存概念的真问题）
```

**元数据侧车**：每篇文档 `<name>.md` 同目录有 `<name>.md.metadatainfo`（`tags[{tag,tag_type}]` + `importance 0–100`），导出/GitHub 镜像保留；规则见 [rule/rule_doc.md](rule/rule_doc.md) R-DOC-6，校验 `lint/metadatainfo.sh`。

## 阅读/审阅顺序

1. [requirements/runtime.md](requirements/runtime.md)（原始运行时要求：三仓结构、运行时规则、builtin 系统、install 流程）
2. [goal.md](goal.md)（验收条款）→ [principles.md](principles.md) → [architecture.md](architecture.md) → [rule/](rule/rule.md)（按方面查规则）
3. [concepts/](concepts/)（新读者从 README 索引入）
4. 实现 → instance 仓（可行性=中间文档已随实现收敛删除，R-DOC-10；可行性分析保留在概念文档小节与 runtime 判据）

## 审阅方式

直接改概念文档终态（或在文档末尾"审阅标注区"追加行）；新问题进 [open-questions.md](open-questions.md)。设计方不逐条来问。

## Workflow

管线状态机、自举顺序、developer_system 如何满足循环：全部在 instance 仓（workflow/、impl/）。本仓只声明"必须有 Workflow、Workflow 的契约是什么"（concepts/workflow.md）。
