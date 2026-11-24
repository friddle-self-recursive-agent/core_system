# Event — 变化通知

| 项 | 值 |
|---|---|
| K8s 对照 | Event 资源 + watch 通知 |
| 形态 | 短生命周期数据（内存队列 + 滚动归档），**不是文档对象**；队列由 dsh（core plugin）实现，类似 dsh 的 event 队列 |
| 作用域 | 全局命名空间（带来源标注） |
| 状态 | 定稿（终态制，rule.md） |

## 1. 定义

Event 是"世界变了"的一次通知。五种来源：Connector watch 外部变化、Metrics 阈值越线、定时巡检到点、Apply 写入完成、人工触发（发布权限口径见规则 8：三源分立+发布域与 apply 写域分立）。

Event **只触发，不修改**：收到事件的反应永远是"触发一次 Workflow 对账"，对账结论才驱动动作。事件可丢、可重、可乱序——系统正确性不依赖它（P3 level-triggered）。

## 2. 边界

**是**：边沿信号 + 审计素材（归档后供观测面看"何时发生过什么"）。

**不是**：
- 不是状态：状态在文档（Status/MetricsInfo）；Event 是状态变化的**影子**；
- 不是指令：没有消费者"必须"做什么；dispatch 只是建议路由；
- 不是文档对象：不进文档库、不 权限系统 校验内容（只校验类型注册）。

## 3. 结构

```yaml
apiVersion: core/v1
kind: Event
metadata:
 name: evt-20261120-000123 # 唯一 id
spec: {}
status:
 type: ExternalChanged # Scheme.eventTypes 之一
 source: {kind: WorkService, name: gitlab, detail: "runner 标签变更"}
 involvedRef: {kind: ServiceInstance, name: developer-system/ci} # 路由按类型+involved/owner+scope
 at: 2026-11-20T10:00:00Z
 dedupKey: "gitlab:runner-label:sha256(...)" # 同因事件聚合
 level: debug | info | warn | error | fatal # Log 式等级（取代原 severity）
```

## 4. 生命周期

产生 → 去重（dedupKey+时间窗聚合，防风暴）→ 按 Scheme.dispatch 路由 → 触发对应 Workflow → 归档（保留 30d，critical 1y）。路由不到 → 死信 + 告警。

## 5. 与其他概念的关系

- Core 是总线；Scheme.dispatch 是路由表（按事件类型+owner/scope 直达， 起）；Connector.watch 是最大生产者。
- Event ≠ Apply：Apply 改文档并顺带产生 `DocApplied` Event；Event 本身永远不改任何东西。
- MetricsInfo 阈值判断后发 `MetricThreshold` Event——数据面到信号面的桥。

## 6. 设计规则

1. dedupKey 强调：同一因由的重复事件在窗口内合并（防外部抖动风暴；配合速率限制与 Workflow 侧冷却期——事件风暴的既有缓解不变）。
1b. **Level 强制**：每个事件必带 log 式等级；消费侧按 level 过滤（debug 默认不入库只进内存队列；fatal 必接 Notification）。
2. 事件不携带大负载：超过 1KB 的上下文放 Ref/DriftReport，Event 只带指针。
3. 消费者不允许"信任事件内容"，只允许"被叫醒后自己看现实"（P3 的落地）。
4. 死信必须可见：观测面死信计数是系统健康指标。
5. **AUTO 处理不了的出口=Escalate 事件**：auto 级 Agent 遇到权限外/能力外/重试耗尽——不自行硬扛，产生 `Escalate` Event（level=error），路由三路齐发：**owner-workflow**（按其 onEscalate 策略决定是否暂停，见 workflow.md）+ **root 上报** + **Notification 送达 Bind role 持有者**。事件只触发不修改——暂停与否是 Workflow 引擎按策略执行的动作，不是事件自带的。
5. **死信熔断要做**：死信率超阈值自动熔断该源（暂停 watch+告警），防止事件风暴拖垮引擎；恢复=人工或冷却后自动半开试探。
6. **dispatch 表 `for:` 谓词与 owner 解析机读口径**：谓词=`any` 或 `<selector>:<pattern>`（selector ∈ owner/scope）。`any`、`owner:*` 恒命中；`scope:<root>/*` 前缀式命中 involved scope（scope 是路径：global、builtin、systems/<s>，路径=scope）；**`owner:<字面量>` 按 owner 解析命中**——owner 解析模型：involved scope 根 `systems/<s>`→`<s>`，global/builtin 同名（owner=scope 根本身）——解析不等则不命中、事件顺延后行。命中=表序首个（`on` 匹配类型 ∧ 谓词命中）行，其 `route:`/`cc:` 即派发目标投影；**派发决策面可查询**：对当前表快照解析「这一事件若到达会路由到哪」（投影 route/cc/for/owner/row）——纯决策零事件注入零留痕零派发，owner 谓词的 live 机械验证落点；**route/cc 目标的执行绑定可查询**（引擎主体第二段）：决策面再投影 `execution={route:{executor,target,wired}, cc:{…}}`——映射表按目标族收编：`dead-letter`→none（死信无执行，观测兜底出口）、`notification/<channel>`→notification（`*`=全部已绑通道）、`workflows/<name>`→workflow、`<p>-agent`→agent（parent、root 等）、`<p>-workflow`→workflow（owner 对账锚）；未知目标族原样投影 `executor=unbound`（缺口可见，不静默吞并）；`wired`=执行面接线态（装配层登记前恒 false——执行计划可查 ≠ 执行面已在位，真实拉起落地轮翻转=机械判别器）。**workflow 触发面已接线（引擎主体第三段 v0.15，真实拉起第一子段）**：装配层登记执行面接线后，route 目标执行面=workflow 的留痕推进为**一次对账 run 投影**（「收到事件的反应=触发一次 Workflow 对账」的机读落点）——run=触发已受理+声明起点（对账锚按对账循环锚 core-workflow 解析：对账=系统级循环本体，workflow.md Controller/Reconciler 对照，owner 维度由留痕 Owner 字段承载；以 workflows 为前缀的直接引用按 builtin 注册表按名解析，未命中=平台对象引用即 Workflow 对象、锚保留相位不投影——spec 随文档面不吞并不缺口化）；run 可查询（对账 run 投影面）；**run 出现 ≠ 对账执行完毕**（相位态机 deferred，run 只证明触发面把事件接进了 workflow 域）。**notification 送达面已接线（引擎主体第四段 v0.16，真实拉起第二子段）**：装配层双登记（送达投影落点挂接 ∧ `WireExecutor(notification)`）后，执行面=notification 的绑定推进为**一条送达受理投影**——route 主路与 cc 旁路双路同 sink 收编（通知本身即旁路语义：以通知为主路的行如 ApprovalNeeded，以通知为旁路的行如 Escalate/HeartbeatLost 的 cc——主/旁维度由 origin 字段留痕，不再为旁路单开 sink 面）；送达可查询（送达投影面）。**真实通道出站已挂接（v0.17 第四段收尾，进程内自动投递注入）**：装配层经 exec 出站桥注入实现侧出站入口（信封协议 connectors.OutboundEnvelope，secret 引用式取值不经手信封——声明面见 provider.md email-notify 与规则 7），送达受理后异步出站、投影就地翻转 sent 或 failed（出站留痕 attempts 与 completedAt 随行；未注入出站的部署送达止于受理投影，语义不变）；**送达投影翻转 ≠ 重试存在**（一次尝试，重试、降级与静默窗口仍属引擎主体余量）。**agent 唤醒面已接线（引擎主体第五段 v0.18，真实拉起第三子段）**：装配层双登记（唤醒投影落点挂接 ∧ `WireExecutor(agent)`）后，执行面=agent 的绑定推进为**一条唤醒受理投影**——route 主路与 cc 旁路双路同 sink 收编（origin 留痕；现行表 agent 族目标均在 route 主路：Escalate 至 root-agent、HeartbeatLost 至 parent-agent），唤醒可查询（唤醒投影面）；**唤醒投影出现 ≠ agent 会话已被拉起**（真实拉起=session 域，declared-deferred，本面只证明触发面把事件接进了 agent 域）。相位态机、刹车、冷却、minLevel 与 agent 真实拉起仍属引擎主体余量。全表未命中 → `route=dead-letter`（rule 4 死信兜底可见）。订阅集合=表 `on:` 值去重；含 `on: "*"` → 坍缩为单条全类型订阅（通配已覆盖枚举）。
7. **默认通知通道 email**：Escalate 路由的 `notification/*` 路（cc 旁路）与 ApprovalNeeded 主路的默认通知支持 **email channel**——Notification Provider kind: email（声明面示例=provider.md `email-notify`：secret 引用式取值 `env:QQ_SMTP_AUTH_CODE`，收件人清单在 Provider/WorkService 配置面；通道实现=通知 ConnectorOps 的 `notify/send-email` 操作，契约面=connectors 包 OpsConnector 五方法——工具调用域，R-ENG-3 通用仓 common_connector 实现，`send-email` 经 SMTP 出站）。**进程内自动投递已挂接（v0.17）**：装配侧 exec 出站桥注入（信封协议 connectors.OutboundEnvelope，实现侧出站命令住连接器仓、依赖方向不反转），送达受理后异步出站并翻转 sent 或 failed；是否注入属部署侧决策逐 profile 装配（未注入=送达止于受理投影）。**送达投影翻转 ≠ 重试存在**——重试/降级/静默窗口仍属引擎主体余量（规则 6）。
8. **事件发布面（publish face）三源分立**：发布者=Connector watch（外部变化）/引擎内部（apply 落面 DocApplied、metrics 阈值、生命周期）/人（人工注入）三源（§1 五种来源的权限口径）；人经写面 HTTP 注入端点（随写面开关门控，未开启=405 与 apply 写面同口径）。**发布权限域与 apply 写权限域分立**：发布动作=`publish` × 域 `events`（资源域，permission.md §1 动作词汇），apply 写=write × 对象 scope——两域不互为准入（持 publish 不持对象 write、持对象 write 不持 publish 各自独立判定）；`DocApplied` 由引擎在落库事务内自产，主体不可经任意通道伪造来源标注。注入事件走与引擎内部事件**同一条主干**：类型注册校验（Scheme.eventTypes，§2 边界=只校验类型注册不校验内容）→ level 缺省=注册表 defaultLevel 投影 → dedupKey 时间窗聚合 → 订阅派发 → event_log 归档——零旁路、零特权通道；**注入通道的 source 由服务侧判定恒 `human`**（载荷声明的 source 不采纳，来源标注是审计事实不是请求参数）；debug 级注入不入库只进内存队列（规则 1b 同款）。注入回执 `{id, type, dedupKey, level, source, involved}` 与留痕 eventId 同源可回指。
9. **引擎内部源机读落点（首段=ApprovalNeeded 自产）**：引擎内部事件不是注入的镜像，是引擎在自己的判定路径上**自产**——首个落点：apply 写路径权限准入拒绝 ∧ 命中人审档（permission.md §4 机读判定：被拒对象属授权面装载类 Role/Group——「改 role/绑定=改权限=高敏变更（人审）」的机械投影）时，写路径引擎自产 `ApprovalNeeded` 事件进总线（零新 HTTP face，注册表派发行 `{ApprovalNeeded→notification/*}` 主路送达）。与注入面同一条主干零旁路，差异三处：**source 服务侧判定恒 `permission`**（与注入恒 human 同口径——来源标注是审计事实）；**类型注册闸门前置**——`ApprovalNeeded` 未注册即不发布（注册表是引擎内部源的唯一开关，声明先行机械落点）；**level 缺省=注册表 defaultLevel 投影**（ApprovalNeeded→warn），dedupKey=`permission:<obj>`（同对象待审变更窗口聚合防风暴）。**拒绝结论是权威、事件是通知**：事件发布失败不改变拒绝与审计留痕；dry-run 零副作用不产事件（apply.md §3 口径）。hard rules 拒绝（代码级不可放宽）≠人审档——永不可批的拒绝不产 ApprovalNeeded，只拒绝+记审计。connector watch/metrics 阈值/定时巡检等其余内部源随各自声明面扩展顺延。
10. **引擎内部源机读落点（第二段=定时巡检 ReconcileTick 自产）**：生产者=cored 定时器（装配层，非请求端点——零新 HTTP face，第三类真实来源；与写面开关分立：巡检是控制面保险丝，只读装配亦可开启）。部署侧显式开启（`--reconcile-interval <dur>`；**缺省 0=关断零事件**——缺省不改既有行为面，保险丝按部署开启，event.md §7「最迟 N 分钟全量对账一次」的 N 即此值）。与注入面同一条主干零旁路，差异四处：**source 服务侧判定恒 `core`**（引擎自身产生的心跳/巡检类来源标注是审计事实）；**类型注册闸门前置**——`ReconcileTick` 未注册即不启动巡检（注册表是引擎内部源的唯一开关，声明先行机械落点）；**level 缺省=注册表 defaultLevel 投影**（ReconcileTick→info）；**dedupKey=`reconcile:<at>`（拍点即因由）**——同拍重放窗口聚合、跨拍不聚合：巡检每个到点时刻是独立因由，最迟 N 分钟语义不被总线去重窗口吞没（拍点间隔与去重窗口解耦，event.md 规则 1 的「同因」口径在定时源上的投影）。**事件只触发不修改**：route `workflows/core-workflow`（对账锚=系统级循环本体）→ 到点留痕推进为一次全量对账 run 投影（run 出现 ≠ 对账执行完毕，规则 6 v0.15 口径不变）；involved 恒 `Workflow/builtin/core-workflow`（对账对象=对账循环本体，owner 维度由留痕承载）。connector watch/metrics 阈值等其余内部源随各自声明面扩展顺延。
11. **审批信号族（挂起-恢复首段 v0.24，run 域迁移事件）**：`ApprovalGranted`（批准）/`ApprovalRejected`（驳回）注册进事件类型注册表（source 声明=human——审批决定是人做出的，与注入通道 source 判定恒 human 同口径；level 缺省=info/warn 分诊）。**involved=Workflow 对象引用即锚**（kind/scope/name 三段首段 kind=Workflow）：引擎按 involved 携带的 workflow 名对该锚**最新 run** 执行相位机迁移判定——`ApprovalNeeded`（involved kind=Workflow 时）=审批提升（相位落闸锚 AwaitingApproval 挂起，workflow.md 规则 13）；`ApprovalGranted`=恢复（闸锚沿声明序列续行）；`ApprovalRejected`=终态（闸锚→终点锚）。**审批信号是相位机的迁移事件，不是新对账触发**：dispatch 派发面对其无目标（表行 dispatch=dead-letter=「该面无目标」的标注，run 域信号处理独立于 dispatch 派发——同一条总线订阅主干零旁路：同留痕、同去重、同 event_log 归档）；**不另起新 run**（规则 6「事件只触发」的触发对象=run 相位机迁移判定）。非 Workflow involved 的 `ApprovalNeeded`（既有权限拒绝产源 involved=Role/Group）不命中 run 域=既有行为面不变（机械反证面）。
12. **引擎内部源机读落点（第三段=connector watch 外部变化 ExternalChanged 桥，v0.30）**：生产者=装配层 watch 桥——驱动侧经 connectors 契约（`ProviderImpl.Watch` 通道产 `connectors.Event{dedupKey, detail}`，可降级 poll）声明外部变化，桥在服务侧完成闸门与判定后进总线；驱动仓零总线依赖（依赖方向恒为 connector 仓→workservice 契约层，R-ENG-3——总线面全部收敛在服务侧）。与注入面同一条主干零旁路，差异五处：**source 服务侧判定恒 `connector`**（外部变化来源标注是审计事实——驱动载荷不携带来源，与注入恒 human/巡检恒 core 同口径）；**类型注册闸门前置**——`ExternalChanged` 未注册即不启动桥（注册表是引擎内部源的唯一开关，声明先行机械落点）；**level 缺省=注册表 defaultLevel 投影**（ExternalChanged→info）；**dedupKey=驱动侧因由声明**（§3「同因事件聚合」的投影：驱动最知因由，服务侧透传不改造——窗口聚合防外部抖动风暴，规则 1；空=永不聚合）；**involved=装配绑定锚**（v0.30 首段=`WorkService/<type>` 来源服务投影，逐挂载 involved 声明面随 ConnectorOps 装配顺延）。**detail 不进总线**（规则 2：事件只带指针不带内容——消费者被叫醒后自己看现实）。**缺省关断**：装配旗标关断=零驱动零事件（缺省不改既有行为面，规则 10 保险丝同款范式；与写面开关分立——watch 桥只读装配亦可开启）。**事件拍组合**：watch 事件落 run 同拍即拍（workflow.md 规则 15 v0.30 段——拍面驱动源集合扩展，零新开关）。metrics 阈值等其余内部源随各自声明面扩展顺延。
13. **引擎内部源机读落点（第四段=metrics 阈值 MetricThreshold 桥，v0.31）**：生产者=装配层阈值桥——数据面指标样本经装配层绑定通道投递，桥在服务侧完成阈值判定与闸门后进总线（§5「MetricsInfo 阈值判断后发 MetricThreshold Event——数据面到信号面的桥」的机读落点；**数据面首段已落 v0.33**：MetricsInfo=进程内样本库（store/queries 投影，可丢弃可重建）+自观测采样器（ops DB event_log 流水窗口计数——查询投影即样本，metric=events.<type>）+读面 /v1/metrics；解耦口径=数据面零信号面依赖（信号面不持数据面，装配层持两者经样本通道适配）；阈值声明面=WorkService.observation.metrics 的 thresholds 行（声明面外谓词不绑定不即兴语义），逐对象 involved=WorkService/<scope>/<name> 源级绑定锚（involvedRef kind/scope/name 三段同构惯例——两段式不可被 owner/scope 谓词与对象链解析，v0.45 修正）；文档面零告警声明=no-source 缺口可见不静默）。与注入面同一条主干零旁路，差异五处：**source 服务侧判定恒 `metrics`**（来源标注是审计事实——数据面样本不携带来源，与注入恒 human/巡检恒 core/watch 恒 connector 同口径）；**类型注册闸门前置**——`MetricThreshold` 未注册即不启动桥（注册表是引擎内部源的唯一开关，声明先行机械落点）；**level 缺省=注册表 defaultLevel 投影**（MetricThreshold→warn）；**dedupKey=`<metric>:<window>`**（scheme.yaml MetricThreshold 行 dedup 声明的机械投影——同指标同窗口的重复越限样本窗口聚合防风暴，规则 1；窗口标签由样本侧声明，服务侧透传不改造）；**阈值判定是服务侧动作**——数据面只产样本不带判定（判定谓词属装配声明面，不属数据载荷——与 source 恒服务侧判定同口径；声明序首个同指标阈值参与判定，声明面外谓词不判定不发布不即兴语义；未越限样本静默=数据面照常产样本零事件）。**阈值声明面 apply 落库即生效（v0.47 热重绑）**：绑定表与样本流解耦（样本流=桥级单通道装配期接线，绑定表=可整体替换的纯声明）——apply 落库发出的 DocApplied（involved kind=WorkService）驱动全量重枚举与绑定表替换（连续变更合并；枚举失败=保旧表+告警+下次 apply 重试自愈，权限热装载同款 declared 语义），零绑定=合法等待态（装配期零声明不再是终态，apply 后热激活）。**involved=装配绑定锚**（v0.31 首段=`WorkService/metrics` 来源服务投影，逐对象 involved 声明面随 MetricsInfo 数据面落地顺延）。**缺省关断**：装配旗标关断=零样本源零事件（缺省不改既有行为面，规则 10 保险丝同款范式；与写面开关分立——阈值桥只读装配亦可开启）。**事件拍组合**：metrics 事件落 run 同拍即拍（workflow.md 规则 15——拍面驱动源集合扩展，零新开关）。**自参考阈值注记（v0.48）**：`events.<type>` 类自参考指标的样本=event_log 窗口计数——绑定摘除（声明复原）即断流，重绑激活后的首窗需 ≥1 条该类型事件入账才有样本可判（自参考指标不自我供血：断流→首窗零样本=合法等待态，样本源持续性=部署侧职责——注入通道 source=human 或真实流量，与产出 source=metrics 判别分立）。其余内部源随各自声明面扩展顺延。
14. **会话活性事件族（SessionStalled / SessionHealed / LongTaskRunning；停滞必须是一等事件）**：会话（Session）是执行的一等主体，其活性不允许只靠外部观察日志推断——必须事件化。①**心跳**：会话推进点（相位推进、工具调用完成、产物落盘任一）即心跳，落 ops 记录（可查询）；②**停滞判定**：watchdog（装配层，阈值可配，缺省 10m）超时无心跳 → 自产 `SessionStalled`（level=error，involved=session 锚，dedupKey=`session:<id>`）；③**自愈固定顺序（每步留事件）**：第一动作＝向会话注入**固定 prompt「继续」**（保留上下文，不重启），恢复 → `SessionHealed`（携停滞时长与最后心跳点）；仍未恢复 → 诊断卡因：**需要权限 → 向上提交**（`ApprovalNeeded`/`Escalate`，走审批链与通知，不自行绕过）；**需要人工介入 → 按会话 bind 用户已配置的通知通道上报**；**未配置任何通道 = 不 notify，仅页面展示**（notification.md 规则 6「没有 notify 就不 notify」）；④**长任务显式化**：声明为长任务或有进展心跳者不判停滞，产 `LongTaskRunning`（任务名/已运行时长/当前阶段/决策点），结束回收；⑤**不静默重试**：处置失败继续上报；同会话连续自愈无效达阈值（缺省 2）→ 停止自动处置并升级。语义锚：**有进展心跳 ≠ 停滞**；事件只触发不修改（处置动作由 watchdog/引擎按策略执行）。
15. **引擎内部源机读落点（第五段=Proposal 审批分流 ApprovalNeeded 自产，v0.51）**：生产者=装配层提案分流判定（`internal/proposal` watcher——DocApplied×Proposal 订阅，零新 HTTP face）：Proposal 对象以 `spec.status=submitted` 落库 ∧ 审批分流判高危（priority 不在部署侧 `--proposal-auto-approve` 清单——缺省全人审，proposal.md 规则 3）→ 自产 `ApprovalNeeded` 进总线（route `notification/*` 主路送达+审批屏待审区归档行随行）。与注入面同一条主干零旁路，差异四处：**source 服务侧判定恒 `core`**（引擎自身的分流判定产源标注是审计事实——与巡检恒 core/注入恒 human/人审档拒绝恒 permission 四值分立，registry 行 source=`permission|core` 双产源在册）；**类型注册闸门前置**——`ApprovalNeeded` 未注册即不发布（注册表是引擎内部源的唯一开关）；**level 缺省=注册表 defaultLevel 投影**（ApprovalNeeded→warn）；**dedupKey=`proposal:<obj>`**（registry dedup 模板 `<rule>:<obj>` 的机读实例——同提案待审窗口聚合防风暴）。**批准/驳回判定的事件族随行**：`fromDraft ∧ fieldManager=console:approve|console:reject` 的 Proposal 判定成功（create|update|noop）→ `ApprovalGranted`/`ApprovalRejected`（source=human——判定是人经 console 做出的，与注入通道 source 判定同口径；involved=Proposal/<scope>/<name>，非 Workflow 引用=不命中 run 域迁移，规则 11 反证面）。**拒绝/静默不产事件**：驳回走 ApprovalRejected（事件是通知不是第二判定）；低危自动批准不产 ApprovalNeeded（分流判定=无待审发生，判定留痕=approval_log granted 行 fieldManager=proposal:auto）。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 事件风暴 | ⚠️ 中 | 外部抖动/告警雪崩 | dedupKey 聚合 + 速率限制 + Workflow 冷却期 |
| 事件丢失导致迟收敛 | ⚠️ 低 | 纯边沿会漏 | 定时巡检兜底（level-triggered 的保险丝）：最迟 N 分钟全量对账一次 |
| 内存队列重启丢事件 | ⚠️ 低 | 同上 | 巡检兜底 + 归档落盘 |

**结论：可行。k8s 已验证的模式，加去重与巡检兜底。**

## 8. 待决问题

见 open-questions.md#event

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
