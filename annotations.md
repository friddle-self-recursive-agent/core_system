# 审阅标注区

## 使用方法

审阅时在两处标注，任选其一：

1. **总表**：直接在下方 A-清单表格追加行，或在"状态"列把 `待裁决` 改成 `采纳/驳回/存疑`。
2. **就地**：在对应概念文档末尾的"审阅标注区"表格追加行。

标注语法：

```
【不合设计】位置 — 理由
【无法实现】位置 — 卡在哪
【边界冲突】A 与 B — 重叠点
```

## A-清单：对原始设计稿的预标注

以下是我方在展开设计时对原稿的异议与决议。**默认已按"建议"落进各概念文档**，但都保留了裁决开关——驳回任何一条，改的是对应文档，不是本表。

| ID | 原稿位置 | 问题 | 建议 | 涉及文档 | 可行性 | 状态 |
|---|---|---|---|---|---|---|
| A1 | 文档类型表 | `Prometheus 监控设计` 与 `Metrics 监控设计` 重复：一个是实现、一个是意图，层次混淆 | 删除 Prometheus 文档类型；监控意图统一进 `Metrics`；Prometheus 是 WorkService，抓取配置属于 Instance 实现侧 Docs | doctypes/README.md、concepts/workservice.md | ✅ | 待裁决 |
| A2 | 文档类型表 | `Workflow Desion` 拼写 | 更正为 `WorkflowDesign`，并明确它是**设计文档**（给人看），不是可执行编排 | doctypes/README.md | ✅ | 待裁决 |
| A3 | ServiceInstance 结构 | "ServiceInstance 下面是 Agent" 内嵌 Agent 定义会造成双源（全局 Agent 与实例内 Agent 各一份） | Agent 是全局一等对象；Instance 用引用（agentRefs），实现侧另有 Docs | concepts/agent.md、concepts/serviceinstance.md | ✅ | 待裁决 |
| A4 | Metrics / DataMetrics | 两者边界未定义 | 定：`Metrics`=系统行为/健康指标；`DataMetrics`=数据流指标（从哪到哪、延迟、丢数）。意图声明都在 Desc 侧，数据本体都在 MetricsInfo | doctypes/README.md | ✅ | 待裁决 |
| A5 | Loop 第一步 | "系统自动 event" 的产生源未定义 | 枚举五种触发源：Connector watch 外部 / Metrics 阈值 / 定时巡检 / Apply 写入 / 人工 | loop/loop.md | ✅ | 待裁决 |
| A6 | Loop 全程 | 无失败终止、无震荡保护 | 补 backoff、最大重试、冷却期、超限升级（Escalate→Bind 的人） | loop/loop.md | ✅ | 待裁决 |
| A7 | 概念清单 | 没有删除语义：文档删了，jenkins 上的 job 还在 | 补 Finalizer 两阶段删除 | concepts/finalizer.md | ✅ | 待裁决 |
| A8 | 概念清单 | 没有并发控制：两人/两 Agent 同改一份文档必然互踩 | 补 Revision（乐观锁 + SSA 字段归属 + 审计） | concepts/revision.md | ✅ | 待裁决 |
| A9 | 整体 | 文档即权限 ⇒ 改文档=提权，原稿未设防 | Policy 准入必选；Auth 类文档与 Builtin scope 默认人审 | concepts/policy.md | ✅ | 待裁决 |
| A10 | 整体 | 自举矛盾：文档管理一切，谁管理第一批文档 | 承认最小点火器（builtinRoot 二进制），见 bootstrap 设计；这是原稿未面对的硬前提 | instance:loop/bootstrap.md | ⚠️ | 待裁决 |
| A11 | WorkService vs ServiceInstance | 两者都是"实际的系统"，边界含糊 | 用 Q2 裁决：外部第三方=WorkService，本系统实例化=Instance；developer_system 是 ServiceDesc，gitlab/jenkins 是 WorkService | architecture.md §3 | ✅ | 待裁决 |
| A12 | APPLY 与 Event 并存 | 双路径风险：有人 Apply、有人发 Event 通知改状态 | Event 只触发不修改；一切修改只走 Apply。两概念正交 | concepts/apply.md、concepts/event.md | ✅ | 待裁决 |
| A13 | Core/Scheme/Builtin 三概念 | 职责重叠风险：都在"管内部" | 定边界：Core=进程（运行时）、Scheme=数据（注册表）、Builtin=标记（scope）。三者不同物 | concepts/core.md §2 | ✅ | 待裁决 |
| A14 | Loop 尾部 | "更新系统status等->agent处理->汇总->观测" 中第二个"agent处理"角色不明 | 定为 Report 阶段：Agent 生成 DriftReport/摘要（现实压缩回文档的载体），供观测面汇聚 | loop/loop.md | ✅ | 待裁决 |
| A15 | "loop 查看dsh" | dsh 未定义 | 理解为 Scheme 索引/事件路由表（Dispatch），并入 Scheme 概念，不单独造概念 | concepts/scheme.md | ⚠️ 理解可能偏差 | 待裁决 |
| A16 | Agent 下 Connector | "type->对应代码" 的代码放哪、谁审 | Connector 代码入库（global/connectors/<type>/src），Agent 只引用 type；代码变更走 Apply+Policy | concepts/connector.md | ✅ | 待裁决 |
| A17 | MetricsInfo | "收集系统，不是文档" 与"文件夹存一切"矛盾 | MetricsInfo 是数据目录/TSDB 引用，不进文档对象库；文档里只存它的查询入口声明 | concepts/serviceinstance.md | ✅ | 待裁决 |
| A18 | R1.1 "SystemDesc" | 与既有 Kind `ServiceDesc` 命名关系未定 | 根项目本身即最顶层 ServiceDesc（name=core_system），别名 SystemDesc 记入 annotations；是否全局改名待裁决 | system.yaml | ✅ | 待裁决 |
| A19 | R1.2.3 "Scheme" | Scheme 双义：类型注册（WorkServiceTemplate 是 builtin Scheme）与执行层（Agent→Scheme→代码） | 统一为"声明层"：类型注册（concepts/scheme.md）+ 执行图 TaskScheme（concepts/task-scheme.md，独立 Kind） | concepts/scheme.md、concepts/task-scheme.md | ✅ | 待裁决 |
| A20 | R1.4 WorkServiceTemplate | 原稿无此概念 | 新增 builtin Scheme：WorkServiceTemplate（模板）≠WorkService（成品）；执行者为 builtin-deploy-system | concepts/template.md | ✅ | 已按 R1.4 落地 |
| A21 | R1.2.1 dsh/Plugin | Agent 运行时未定义 | 基础 agent=dsh+Plugin（control/console/exec-local/reporter 首批）；root 经 control plugin 直控子 agent | concepts/plugin.md | ✅ | 已按 R1.2.1 落地 |
| A22 | R1.3 builtin 集合 | 原设计 builtin=控制面自身（core/scheme/builtinRoot），现扩为 4 个 builtin service | Builtin scope 重划：SelfRecursiveCore + developer/deploy/storage 三系统=自举最小集；"内置=代码和 connector 内置"（在 workservice 仓） | systems/builtin/、concepts/builtin.md | ⚠️ 膨胀风险 | 待裁决 |
| A23 | R1.5.4 ops 日志 | 原设计审计=git log 单轨 | 双轨：git=文档内容版本；DB（v1 sqlite）=操作流水（Apply/Event/Escalate），Core 双写+每日对账 | concepts/revision.md v0.2 修订 | ✅ | 已落地 |
| A24 | R1.6 developer 选型 | 原示例 gitlab/jenkins → 实际用既有 onedev | developer-system 落地选型 onedev（WorkService+onedev-driver），build 默认本地（dsh exec-local） | systems/builtin/developer-system、instance 仓 impl/developer-system.md | ✅ | 已按 R1.6 落地 |
| A25 | R2 Connector 拆分 | 单一 Connector 混"类型"与"使用" | 拆 ConnectorProvider（类型+代码绑定）/ConnectorOps（挂载使用，绑 Workflow）；Agent 默认挂 ops；builtin 服务 connector 提供默认 ops，每 ServiceInstance 可自实现；使用要权限 | concepts/connector.md | ✅ | 已落地 |
| A26 | R2 Workflow | 任务态机缺声明载体 | 新增 Workflow（执行态机）；任务态机=default-task builtin；与 WorkflowDesign（设计文档）、TaskScheme（步骤图）三方边界已定；ConnectorOps 必绑 | concepts/workflow.md | ✅ | 已落地 |
| A27 | R2 Provider | Agent 需绑定 API 账号/接口 | 新增 Provider（auth/config/connector 可空/secret→Credential 引用）；注意与 ConnectorProvider 不同物 | concepts/provider.md | ✅ | 已落地 |
| A28 | R2 Notification | BIND 后缺通知概念 | 新增 Notification（一个 Scheme 一个 Instance）；ApprovalNeeded/Escalate 默认接通知实例 | concepts/notification.md | ✅ | 已落地 |
| A29 | R2 取消 Agent 写路径强制规则 | "Agent 一切写操作经 Apply，违者拒绝" 被否 | 取消该规则；替代：每次 PLAN 与每完成一次 Session 必须记录文档（PlanDoc/SessionLog）于 ServiceInstance；文档面写入机制（Apply/Policy）本身保留 | concepts/agent.md §6.1、doctypes | ✅ | 已落地 |
| A30 | R2 AUTOLEVEL | Agent 无自治分级 | ask/auto/all 三级；默认 RootAgent=ask、ServiceAgent=auto；all 需显式授权（P8 落地） | concepts/agent.md §3.1 | ✅ | 已落地 |
| A31 | R2 子 agent 形态 | 派发子 dsh agent 的粒度未定 | 子 agent=机器 instance 级独立进程（非 dsh 内部 subagent），接受内存开销换隔离与直控；简单派发走 simple-shot | concepts/agent.md §1/§6.4 | ✅ | 已落地 |
| A32 | R3 Apply 定位 | "唯一写路径"易被误读为约束 Agent 干活 | 澄清：Apply=文档面唯一写路径（文档做版本管理）；不影响最底层 Agent 干活（A29 沿用）；no-op 不发 Event+fieldManager 白名单豁免自身转正为规则；提案 SLA 机器删除（NOTIF 承担告知） | concepts/apply.md | ✅ | 已落地 |
| A33 | R3 删字段级归属 | git 无字段级归属概念；文档 diff 是语义活 | 删 SSA/managedFields/三方合并；机器只做文档级比对，语义 diff 与合并提案=LLM（提案制，人裁兜底） | concepts/revision.md | ✅ | 已落地 |
| A34 | R3 Bind 重定义 | Bind 不是绑人 | Bind=role；新增用户系统（builtin 本地表，Kind: User；未来评估 authentic/authentik 接入） | concepts/bind.md、concepts/user-system.md、systems/builtin/user-system | ✅ | 已落地 |
| A35 | R3 责任模型 | "必须有 owner" 被否 | 无主对象合法：信息默认往上走到 root agent；bind=权限插入（role 持有者可处理该 agent），默认 bind 与根同时处理（双通道）；删 escalationChain/SLA | concepts/bind.md、agent/workflow/loop/notification 联动 | ✅ | 已落地 |
| A36 | R3 约束不写死 | "approver≠executor" 硬规则被否 | 代码不写死治理约束；以引用型 Rule/Policy 数据表达（示例规则库存模板） | concepts/bind.md §6.5 | ✅ | 已落地 |
| A37 | R4 Builtin 概念 | v0.2 把 Builtin 做成"最严作用域+强制文档集+成员白名单"，语义错误 | Builtin=起源标记：core_system 系统本来开发/代码自带（如默认代码带最基础的 builtin_developer_system）；不携带任何强制要求；必带文档级别归 DocType 注册（Scheme 层）与 Service 自身声明；治理档位由 Policy 规则配置（可按 origin 匹配），非概念内生 | concepts/builtin.md、doctypes/README.md §3、concepts/scope.md、concepts/doctype.md | ✅ | 已落地 |
| A38 | R5 Connector 再简化 + Skill | v0.3 的 Provider/Ops 生命周期过重（版本并存/探活/drift/finalizer） | Provider=绑定：impl 三形态（tool 外部直接工具/image 镜像/source 源代码+Ref 统一管理）；命名解析：无前缀=默认 org friddle-self-recursive-agent（代码与安装在该 org 生成），带前缀=github.com/<org>/<name> 完整配置；yaml 增 scheme/usage/llmPrompt（LLM 注入提示）/download（工具下载地方）；Ops=工具调用方式/提供的功能；新增 Skill：工具使用处缓存为 skill（按需注入，缓存非真相） | concepts/connector.md、concepts/skill.md、core/scheme.yaml | ✅ | 已落地 |
| A39 | R6 Core 承载形态 | Core 独立进程+将来独立界面的默认路线过重 | **默认用 dsh plugin 承接 Core**：core plugin（Apply/Event/Loop 引擎/Scheme/Policy）跑在 dsh 宿主内；**单独 Core 界面暂缓**——界面=console plugin，做通畅后再单独做 | concepts/core.md、concepts/plugin.md、instance impl/self-recursive-core.md、workservice | ✅ | 已落地 |
| A40 | R7 Credential 删除 | "不再有 Credential，有 Provider 概念即可" | Credential 概念/Kind 删除；secret 完全内化为 Provider.auth.secret（source 引用式取值 vault/env/keychain；明文扫描规则并入 Provider；轮换/吊销规则并入）；全库引用清理 | concepts/provider.md 及全库 | ✅ | 已落地 |
| A41 | R7 Loop 并入 Workflow | Loop 概念变了：合并到 workflow | Loop=带触发规则的 Workflow 实例（developer_system 是一种 loop）；Loop 本质=触发规则→事件整理→事件处理→文档回归 的整个 workflow；内置 core-loop；cooldown/maxMutations/DriftReport 防重/每轮成本 全部迁入 Workflow；跨权限完整分析已做（五穿越点+三出路+分阶段） | concepts/workflow.md §7、concepts/loop.md（墓碑） | ✅ | 已落地 |
| A42 | R7 Event 定级 | 事件要有类似 Log 的 Level；builtin 类似 dsh 实现的 event 队列 | Event.level=log 式五级（debug/info/warn/error/fatal）；debug 默认只进内存队列，fatal 必接 Notification；事件队列由 dsh（core plugin）实现；"短生命周期非文档对象"确认不变 | concepts/event.md | ✅ | 已落地 |
| A43 | R8 Plugin 概念删除 | "没有这个概念。我们系统本身没有 plugin" | Plugin 概念/Kind 删除；dsh=外部运行时（deepseek 插件机制），core 用 dsh plugin 实现（A39 沿用）；core/console/exec-local 等降为**实现说明**（instance 仓），非系统概念 | concepts/plugin.md（墓碑）、core/scheme.yaml | ✅ | 已落地 |
| A44 | R8 Policy 概念删除 | "Policy 准入控制不要。放到权限系统" | Policy 概念/Kind 删除；职责重分：权限+人审→权限系统；结构校验→Scheme/DocType；一致性→引擎；硬规则→权限系统内置项 | concepts/policy.md（墓碑）、concepts/permission.md | ✅ | 已落地 |
| A45 | R8 权限系统设计 | 新的权限骨架 | scope 权限域：global 权限 + system 开头各自 system 权限；默认 global/admin 全权限；**一切只绑 role**（用户绑 role / 用户绑 group、group 绑 role；不直接绑权限）；agent 权限判断不限死（agent/role/上级 agent）；跨系统 A 请求 B 时由 B 侧判定 | concepts/permission.md | ✅ | 已落地 |
| A46 | R9 Ref 重定义 | "Ref 更多是描述。申明。运行时候去相应系统找实例" | Ref=声明式逻辑引用：spec 只写 resolve{system,type,params}（如 type=code、项目名=onedev）；真实地址由被指向系统管理并返回（onedev 源码地址=developer_system 管）；spec 禁止出现物理地址；原"URL 指针+probe"废弃（probe 归 resolver system）；以此解耦各系统 | concepts/ref.md、connector/workservice 联动 | ✅ | 已落地 |
| A47 | R10 Selector 删除 | "Selector 在新系统中没啥用" | 概念删除：事件路由按 类型+involved/owner+scope 直达（dispatch 表）；能力匹配=WorkService.capabilities 字段；观测聚合按 Kind/scope；labels 降为自由注释性元数据 | concepts/selector.md（墓碑）、event/workflow/scheme 联动 | ✅ | 已落地 |
| A53 | R12 WorkService 六面体 | "WorkService 包括 ConnectorProvider，但不止：还有观测/数据/流程/运行状态观测/工具调用描述" | WorkService 扩充为六面体；ConnectorProvider 并入连接面（connector.md 收窄为 Ops 专档）；层级判例：System=deploy_system、实例=sybran 开发实例、WorkService=jenkins/onedev/bug-management；core/scheme.yaml v0.13 补全为完整注册表（19 kinds+17 docTypes+10 eventTypes+全 dispatch+runtime+conventions） | concepts/workservice.md、concepts/connector.md、core/scheme.yaml | ✅ | 已落地 |
| A54 | R13 概念文档终态制 | "文档概念不展示变更。直接展示最后的结果即可。然后这个按概念写入 rule 中" | 新增 rule.md（R-DOC）：概念文档只展示最终结果，不展示版本号/轮次/A-编号等变更叙事；历史唯一去处=本台账；删除 8 个墓碑文件；每个概念"设计规则"节固定携带终态制条目；concepts/README 重写为终态索引 | rule.md、concepts/ 全部 | ✅ | 已落地 |
| A48 | R11 复审提案 | WorkService 空壳化（类型/驱动/地址/账号分别归 ConnectorProvider/Ops/Ref/Provider） | **驳回，反向扩充**：WorkService=六面体（连接含 ConnectorProvider/观测/数据/流程/运行状态/工具调用描述）；层级判例 System=deploy_system→实例=sybran→WorkService=jenkins/onedev/bug-management（见 A53） | concept-review.md §四 | ✅ | 已裁决（R12） |
| A49 | R11 复审提案 | Bind 与 Role 重复（A34 后只剩对象↔role 二元关系表） | **采纳**：Bind 并入 Role（Role.spec.on；holders=user-system 投影）；bind.md 墓碑 | concepts/bind.md（墓碑）、permission.md | ✅ | 已落地（R12） |
| A50 | R11 复审提案 | Revision 全是 Apply 的实现细节（版本管理=Apply 定义的一部分） | **挂起**：Revision=版本管理无争议；提案只是文档组织之争（独立概念 vs Apply 一节），已在 concept-review.md §四补白话说明，待再次裁决 | concepts/revision.md | ⚠️ | 待裁决（已补充说明） |
| A51 | R11 复审提案 | Owner/Finalizer 移植残留 | **采纳且更彻底：直接去掉两个概念**——级联=目录即对象；外部副作用清理=WorkService.tools 成对 cleanup op（Lint 强制）；无系统级删除协议 | concepts/owner.md、finalizer.md（墓碑）、workservice.md 规则5 | ✅ | 已落地（R12） |
| A52 | R11 复审提案 | Status 无对象无 Kind，只是字段约定 | **采纳**：降级为 scheme.yaml conventions.status；status.md 墓碑 | concepts/status.md（墓碑）、core/scheme.yaml §六 | ✅ | 已落地（R12） |
| A60 | R2 builtin 语义 + 控制台/跨agent/工程规则 | builtin 被误解为一次性占位 | builtin=最基础的循环调用代码（如调用 dsh 的基础代码），未来可被安装的复杂真实系统取代；另记：R2.2 跨 agent 调用研究（结论在 instance 仓 runtime/cross-agent.md）、R2.3 控制台服务关注区（instance 仓 runtime/console-ui.md）、R2.4 数据库初始化幂等（rule.md R-ENG-2）、R2.5 默认 Go/TS（rule.md R-ENG-1） | concepts/builtin.md、rule.md、requirements/runtime.md、instance 仓 mvp/、runtime/ | ✅ | 已落地 |
| A61 | R3 workflow 规则化/默认skill/定时驱动 | workflow 配置散在各概念；agent 读文档靠"自己找" | workflow=一条规则：enabled 开关+services(involved/mode)+llm 全在 spec 配置（workflow.md §1/§3、scheme.yaml）；agent 被调用时默认携带"查本系统"skill（agent.md）；核心定时驱动：system agent 定期处理 event/报告→上游 global 汇聚→loop 分析，builtin 走本地（workflow.md 规则 6）；git 预装假设入 runtime.storage；LLM 生成流程描述+mermaid 图按需展示不入库（workflow.md 规则 7） | concepts/workflow.md、concepts/agent.md、core/scheme.yaml、requirements/runtime.md | ✅ | 已落地 |
| A55 | R14.4 仓库前缀 | 公司 git 上 agent 自治相关仓库无命名规则 | 定：公司 OneDev 上**默认前缀 `agent_pool`**（agent_pool/<name>）；GitHub 公开 org 只放无公司信息的泛化内容，公司实物（域名/地址/系统名/凭据）只在公司 git（R14.6 硬规则） | requirements/agent-pool.md、system.yaml | ✅ | 待裁决 |
| A56 | R14.2 反馈闭环 | "报错→agent→提议→批准→pull→发布→验收"是否需要新概念 | **零新概念**：=core-loop 系 Workflow 实例（feedback-remediation-loop）+ 既有 Event/Agent(AUTOLEVEL)/Proposal(P6)/AwaitingApproval/Notification/developer-system/deploy-system/VerifyDoc 的串联；新增物只有对象实例（Workflow/Agent/ConnectorOps）与三个 Connector watch 事件源 | instance 仓 impl/feedback-workflow.md | ✅ | 待裁决 |
| A57 | R14.1 双 profile | 两个 dsh profile 的分工与自举方向 | core-system profile=自举开发（developer-system 闭环跑 core_system 三仓），**唯一交付=更新 kube-inner profile 所用 plugin**（经 developer_system 产物链发布）；kube-inner profile=接入运行时（onedev + 内网集群纳管）。这是 bootstrap（P9）之后的第一对 agent 实例 | instance 仓 runtime/agent-pool-machine.md | ⚠️ 自举依赖 plugin 首版 | 待裁决 |
| A58 | R14.3 模块划分 | 内网系统"页面功能模块"在文档面的归属 | 门户服务注册表（90 项，六类）=**公司 git 存实物**；文档面只存模块分类注册（每模块=WorkService 或其 Instance/Ref，按边界决策树 Q2 判定）；清单本身是数据不是文档（Q1），投影进 WorkService 六面体 | instance 仓 impl/kube-inner-integration.md | ✅ | 待裁决 |
| A59 | R14.8 四项接入 | LDAP/飞书/OneDev/Kafka/SSH 接入是否需要新概念 | **零新概念**：user-system 接 LDAP+飞书=Provider+Instance（账号映射=数据投影）；developer-system 接 OneDev=既有设计落地；deploy-system 多渠道=ConnectorOps 并集按业务 DeployDesign 裁剪（规则不写死）；Kafka=Notification 的传输通道实现（一 Scheme 一 Instance 不变），飞书=Provider，通知落账号=user-system 映射 | instance 仓 impl/user-system.md、impl/deploy-system.md、runtime/event-bus.md | ✅ | 待裁决 |
| A62 | 子 agent 运行时（更正 A31 表述） | A31 落地文"派发子 dsh agent"把子 agent 绑死在 dsh 上，表述过窄 | **强调：子 agent 运行时不限于 dsh**——自写 agent、opencode 等任意 agent 运行时均可；子 agent 的派发/调用=ConnectorOps 描述或调用（与调用外部工具同一语义，spawn 本身就是一次 ConnectorOps 调用）。不变项：机器 instance 级独立进程、禁任何运行时内部 subagent 共享进程、权限=父裁剪只减不增 | concepts/agent.md §1/§3/§5/规则4、concepts/workflow.md §1、instance 仓 runtime/dsh-plugin.md、agent-session.md、cross-agent.md | ✅ | 已落地（A62 更正 A31 表述） |
| A63 | root 权限表述（更正） | 落地文把 root 写成"权限系统硬规则兜底"的特例，易读成权限旁路/无权限标志 | **root 有权限标志、走统一权限管理**：builtinRoot 挂内置 role `global/admin`（最高权限、默认内置），只是该绑定不可更改（不可删/不可换绑/不可降权）；其"最高权限"来自 role 授权面，不是身份特权；动作统一过权限判定与审计。dsh-plugin 权限表=该 role 的授权投影，非独立权限面 | concepts/permission.md 规则2b、concepts/agent.md §1/§5、instance 仓 runtime/dsh-plugin.md | ✅ | 已落地（A63 更正） |
| A64 | RootAgent AUTOLEVEL（更正 A30 表述） | 落地文把 RootAgent=ask 写成固定属性，像特例机制 | **RootAgent 与普通 Agent 同一 AUTOLEVEL 机制**：autoLevel 均可配置，Root 也可 auto/all（全自动，all 需显式授权+权限系统放行）；"RootAgent=ask"只是出厂默认值，不是锁死。变更路径同普通 Agent（Apply+权限系统） | concepts/agent.md §1/§3.1、core/scheme.yaml runtime.autoLevels、instance 仓 runtime/dsh-plugin.md、agent-session.md、impl/feedback-workflow.md | ✅ | 已落地（A64 更正 A30 表述） |
| A65 | R15.1 console 第一层 | 第一层资源视角的树形结构未定型 | **定：第一层=Service 视角树**（Global → ServiceDesc → ServiceInstance → WorkService/Agent 逐层展开，必须是树）；**渲染数据全部来自 Scheme+ops DB**（无独立前端状态）；workflow 详情页入树（流程图/事件/流转/数据流/成本五 tab，操作全=Apply） | instance 仓 runtime/console-ui.md | ✅ | 已落地 |
| A66 | R15.3 任务模板库操作集 | 模板库只有"引用+参数化"，无扩充/退出通道 | **模板库四操作**：用（引用+参数）/调（fork 副本调整，Scheme 方式描述含提示词段，builtin 起源固定不可删）/ **import（导入现有系统编排，dry-run 预览+首期 observe，最重要扩充通道）** / delete（自建与导入副本可删，引用计数>0 拒绝，builtin 不可删）；模板元数据带 origin 与提示词 | concepts/task-scheme.md §4/规则5-6、instance 仓 runtime/execution-model.md §3 | ✅ | 已落地 |
| A67 | R15.4 workflow 平台化 + 去 loop | workflow 只有内部机制语义；"Loop"残留为口语与文件名 | **Workflow=平台对象**：可执行、可编辑（spec=文档 Apply 修改，每步可调）、可展示（流程图/事件/流转/数据流/成本）、可第三方编辑管理导入（同 Apply+权限）、可启停；**数据流必声明**（spec.dataflow）；新增 builtin `dev-delivery`（默认研发交付 workflow，event 错误/新需求触发全自动，每步可调）与 `apply-workflow`（落地 agent：接线+调研发系统写自定义 connector 代码化每层调用+自监控闭环）；**全局去 loop**：概念、口语、目录（instance loop/ → runtime/）、命名（core-loop→core-workflow）全部改 workflow；历史存档（annotations/concept-review/requirements）不改写 | concepts/workflow.md、concepts/task-scheme.md、requirements/workflow-platform.md、instance 仓 runtime/workflow-runtime.md（新）、runtime/bootstrap.md（自 loop/ 迁入） | ✅ | 已落地 |

## 全局可行性判定（详见 feasibility.md）

原稿方向成立，但有三个硬前提必须接受：

1. **LLM 收敛性无法数学保证** —— 机制上用重试上限 + 升级到人 + 回滚兜底，不能假装会收敛。
2. **文件夹没有事务与 watch** —— Core 必须封装存储接口（git 后端串行写 + 轮询/钩子），未来可换真数据库。
3. **必须有一个文档之外的点火器** —— 否则鸡生蛋死锁（见 bootstrap）。
