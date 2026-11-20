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

## 全局可行性判定（详见 feasibility.md）

原稿方向成立，但有三个硬前提必须接受：

1. **LLM 收敛性无法数学保证** —— 机制上用重试上限 + 升级到人 + 回滚兜底，不能假装会收敛。
2. **文件夹没有事务与 watch** —— Core 必须封装存储接口（git 后端串行写 + 轮询/钩子），未来可换真数据库。
3. **必须有一个文档之外的点火器** —— 否则鸡生蛋死锁（见 bootstrap）。
