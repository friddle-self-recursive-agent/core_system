# Open Questions（每概念 ≥3 问）

> 原稿要求"每个概念至少写三个问题，放到另一个文档"。问题按"不回答就无法开工"排序；❶❷❸ 为必答，其余为重要。已给倾向的标 [倾向]。

## core

1. ❶ Core v1 是单进程单实例。接受单点多久？多实例+选主的触发条件是什么（对象数？可用性要求）？
2. ❷ 文档库写串行队列的吞吐上限（目标值 obj/s）？超过时先加批量写还是直接换 DB 后端？
3. ❸ Core 挂掉的 RTO 目标是多少？看门狗重启期间在途 Agent 任务怎么处置（作废重派 vs 断点续跑）？
4. Core 的 API 形态：本地 CLI、HTTP、还是两者？Agent 与 Core 的通信协议选型？

## scheme

1. ❶ dispatch 表的路由表达能力 v1 只到 Selector 相等/集合，够吗？需要 exists/notIn 吗？
2. ❷ 类型演进的兼容期多长？迁移由 Loop 自动执行还是人审每一步？
3. ❸ 死信的保留与重放策略：重放由谁触发、有没有毒丸（poison event）熔断？
4. dsh（A15）如果原意不是 dispatch 索引，正确语义是什么？

## agent

1. ❶ Agent 的运行时形态：Core 内线程、独立进程、还是外部 runner（如复用某个 agent 框架）？崩溃隔离要求决定选型。
2. ❷ 一个 Agent 服务多个 Instance 时，上下文/权限如何隔离（按任务会话？按 Instance 派生 SubAgent？）？
3. ❸ SubAgent 权限"裁剪"的声明粒度：按 Connector、按 Ref、按文档路径、还是组合？
4. Agent 定期自我对账吗（HeartbeatLost 之外，加"能力漂移"自检）？
5. builtinRoot 的具体职责边界：它自己修 Core，还是只能拉起/回滚、修复必走人审？

## servicedesc

1. ❶ "能力声明，不绑实现"（规则 2）在现实里常被打破——紧急修复直接点名实现。要不要一个 escape hatch（如 annotations 里允许、定期还债的 lint 豁免）？
2. ❷ Goal.acceptance 的"可验证"标准由谁裁定：写系统的人、Bind 的 owner、还是 Policy 的固定模板？
3. ❸ 一个系统的边界划多大：developer-system 是一个 Desc，还是 scm/ci 两个？判据是什么（一个 owner？一个收敛域？）？
4. 文档间矛盾的自动检出做到什么深度：仅交叉引用存在性，还是语义级（LLM lint）？

## serviceinstance

1. ❶ v1 实例无独立 Spec。何时需要实例级覆盖（overlay）？触发条件写进设计还是等第一个真实案例？
2. ❷ MetricsInfo 的"最近摘要"（24h 概要）由谁生成、多久刷新？摘要本身算不算数据冒充文档（A17 边界）？
3. ❸ ImplDoc 过期的判定标准：Connector 版本变即过期？还是 driftScan 抽样核对？
4. 多实例（ci/cd 两实例）共享一份 DriftReport 还是各自持有？

## workservice

1. ❶ 能力标签（capabilities）词表谁来维护？任意自造标签会让"按能力引用"退化成"按名字引用"。
2. ❷ 外部系统的"所有权"问题：gitlab 同时被两个系统管理时，冲突动作的仲裁规则（唯一 owner？锁？提案合并）？
3. ❸ 外部系统不可编程观察（无 API 的遗留系统）时，watch 降级到什么程度可以接受（日志尾随？人工上报 Event？）？

## connector

1. ❶ 契约五方法的最小实现门槛：`get+plan+apply+verify` 必须有，watch 可轮询——undo 允许 `none` 但要人审。这个门槛对 dsh/http/sql 通用驱动现实吗？
2. ❷ Connector 代码的测试标准：契约符合性测试（conformance suite）谁写、谁跑（CI 里跑还是注册时跑）？
3. ❸ 通用驱动（dsh）的命令白名单模板怎么组织：按系统、按 Bind 角色、还是按风险等级？
4. Connector 自身的版本升级策略：多版本并存期、灰度（先一个 Instance 试用）如何表达？

## ref

1. ❶ TTL 默认值与年检 Event 的节奏（90d/180d？）重要吗，还是全部 manual 起步？
2. ❷ Ref 的 probe 探测失败算 drift 吗（会触发 Loop 修复吗），还是只告警不修复？
3. ❸ "被 Loop 依赖的目标必须是 WorkService"（规则 2）怎么机器识别违规——Lint 扫描 Agent 上下文里的 Ref 用途吗？

## builtin

1. ❶ 成员上限"个位数"具体是几？core/scheme/builtinRoot/default-policy 之外还预留谁（观测面？审计？）？
2. ❷ 硬规则三条之外，将来若必须加第四条，流程是什么（发版+双人审？）？
3. ❸ Builtin 文档的人审"双人复核"在单人维护期怎么办（自我复核+延迟生效？）？

## event

1. ❶ 归档保留期（30d/1y）与合规要求对齐吗？审计要求 longer retention 吗？
2. ❷ 巡检兜底的默认 resync 间隔（10m）与事件去重窗口的关系：去重窗口必须 < resync，确认默认值组合自洽？
3. ❸ 死信熔断：同一 dedupKey 死信 N 次后自动屏蔽该来源吗？屏蔽是 Policy 动作还是 Event 系统动作？

## apply

1. ❶ v1 整文档归属够不够？字段级归属（managedFields 全功能）提前到 v1 的成本多大？
2. ❷ 跨系统提案（Proposal）的展示与合入 UX：待审区是文档目录、UI、还是两者？
3. ❸ no-op 不发 Event 防自我唤醒——那 Status 里"上次检查时间"怎么更新而不触发事件（专门的 heartbeat 字段豁免）？

## bind

1. ❶ v1 用户身份从哪来：IM id、邮箱、还是引入正式 SSO？换身份体系时 Bind 怎么迁移？
2. ❷ approver 与 executor 不得同人（规则 2）——单人团队如何豁免而不破坏审计？
3. ❸ escalationChain 跨系统吗（developer-system 的升级终点是平台 oncall，平台 oncall 的 Bind 在另一个系统）？环状升级链怎么防？

## loop

1. ❶ 预算制的具体预算单位与默认值：token 数、分钟、变更数——三者怎么组合成"一轮预算"？
2. ❷ CoolDown 与外部紧急变更的矛盾：生产事故时能跳过冷却吗（人工 Event 带高优先级）？
3. ❸ 多系统 Loop 并发修同一外部系统：唯一 owner 规则的注册在哪（WorkService 上加 ownerSystem 字段？）
4. Escalated 后人处理完的"重新触发"是自动（检测到 Status 变化）还是手动按钮？

## status

1. ❶ reason 枚举的初始集合定多大？谁批准新增（Scheme 变更流程）？
2. ❷ conditions 的 lastTransitionTime 抖动（True↔False 快闪）要不要防抖窗口？
3. ❸ Status 里允许放"下一步建议"吗（LLM 很想写），还是严格禁止（保持纯观测）？

## scope

1. ❶ 跨枝引用禁令（规则 3）与复用诉求的矛盾：A 系统想用 B 系统私有的 Connector，标准路径是"提升为 Global"——提升流程和评审门槛？
2. ❷ git 权限绕过（v1 承认）：要不要在 v1 就配 pre-receive 钩子做最小拦截（路径白名单）？
3. ❸ scope 不可变，但组织调整（系统合并/拆分）时迁移工具的形态？

## selector

1. ❶ 推荐值表（防 domain=CI/ci 漂移）强制力：警告还是拒绝？
2. ❷ 表达式引擎 v2 的需求征集：in/notIn/exists 之外，真实场景需要 exists/notExists 吗？
3. ❸ Label 变更的敏感度分档：core/* 人审，其余放行——业务方自造 core-like 前缀怎么防（保留前缀校验）？

## owner

1. ❶ 双主需求出现时（两系统共管一个 WorkService）："一主一引用+Finalizer" 的具体写法示例？
2. ❷ 孤儿告警的核实 Loop 是全局的还是每系统一份？
3. ❸ owner 链过深（>4 层）时责任上溯效率：要不要强制最大深度？

## finalizer

1. ❶ 自动登记（规则 1）依赖 Connector.apply 返回副作用清单——契约要不要加 `sideEffects[]` 返回段？
2. ❷ 墓碑对象的观测指标阈值：多少条算"删不干净欠债超标"触发平台级告警？
3. ❸ 24h Escalate 之前要不要先自动重试清理（复用 Loop.backoff）？

## doctype

1. ❶ 必填段 ≤3 的约束对 Rule 这类"列表型"文档够用吗（rules[] 算一段）？
2. ❷ DocType 版本化（Goal/v2）的存量迁移：Loop 自动改写文档？还是只标记兼容、由 owner 择机改写？
3. ❸ 语义质量评估（drift 计入）的评分标准：谁定义"Goal 写得好不好"的量尺？

## policy

1. ❶ 审批放行的粒度：按 fieldManager 放行后，同一 Agent 的所有后续动作都免审吗？要不要"单次批准"token？
2. ❷ Lint 警告的收敛：警告堆积会让真正的信号被淹没，警告也要 SLA 吗？
3. ❸ Policy 自身变更的"最小自引用"审查：改 Policy 的人审由谁批（平台 oncall？）？

## credential

1. ❶ v1 的 source 从哪个起步：env 最简，但轮换要人肉；vault 最对，但引入外部依赖。起步顺序？
2. ❷ 双钥匙过渡期（轮换）长短与 Connector 契约的配合细节：source 数组化？
3. ❸ 根凭证（Builtin 用）与普通凭证的管理差异：谁掌管 Igniter 装载时用的首把钥匙？

## revision

1. ❶ commit message 结构化的强制力：pre-commit 钩子校验还是 Policy 校验（走 Apply 的都过 Policy，但直接 git commit 呢——v1 单库绕过路径）？
2. ❷ Conflict 率的健康阈值定多少？超阈值的自动处置（限流最活跃写者？）？
3. ❸ git 历史与 Policy 审计记录的关联：audit 记录单独存还是完全信任 git log？

## plugin

1. ❶ control 直控通道的原语集最小闭环是什么（dispatch/interrupt/query 三够吗）？要不要 sub→root 的主动上报通道（还是复用 reporter）？
2. ❷ console plugin 的宿主形态：TUI 先行还是直接 Web？决定首版交互范围。
3. ❸ 插件权限 grants 与 Agent docsPolicy 的合并规则（交集还是并集）？

## task-scheme

1. ❶ builtin 任务模板库首批定哪些（建议 build/verify/sync/report 四个）？参数面多宽？
2. ❷ Agent 兜底（无 Scheme 可路由时）的授权边界：谁批第一次兜底？
3. ❸ 步骤产物传递用本地目录+digest，够撑多复杂的流水线？第一个反例出现时升级方案？

## template

1. ❶ 首批官方模板清单确认：onedev + prometheus，还有谁？
2. ❷ 模板仓的命名约定（`<name>-template`？）与搜索方式（topic 标签 vs 仓库名匹配）？
3. ❸ 无 OSS/NAS 的裸机环境，模板 resources 降级路径的最低要求？

## connector（v0.3 拆分后）

1. ❶ builtin 服务 `connector` 提供的默认 ops 集合定多大（gitfs/dsh/http 之外还放谁）？
2. ❷ ops 的就近遮蔽（instance 覆盖 global）在 console 资源树上如何呈现，防"同名不同物"困惑？
3. ❸ Provider 的 types 标注与 WorkService.capabilities 的关系：是否合并为同一词表？

## workflow

1. ❶ builtin 首批三个（default-task/simple-shot/watch-only）够用吗？是否补 install-flow？
2. ❷ 相位预算默认值（Analyzing 5m 等）如何随模型速度调优——写进 Workflow 还是全局 Policy？
3. ❸ SessionLog 回放的粒度：相位级还是动作级（存储量差一个量级）？

## provider

1. ❶ LLM Provider 是否需要多活（llm-main/llm-backup 自动切换）？切换策略放 Provider 还是 Agent？
2. ❷ provider 与 credential 的人审能否合并为一次（同批变更）？
3. ❸ 直连（connector 为空）的出口审计做到什么深度：域名白名单还是全量记录？

## notification

1. ❶ 首批通道顺序确认：IM（飞书）→ email → webhook 日志？
2. ❷ 静默窗口与 oncall 值班联动：v1 做吗？
3. ❸ critical 无通道的"建系统时警告"要不要升级为拒绝？

## agent（v0.3 追加）

1. ❶ Session 记录粒度"看实现"：dsh 会话结束即记，还是每 Workflow 相位迁移即记？
2. ❷ docsLoaded 审计之外，要不要对"该读未读"（漏 Rule）做事后检测？
3. ❸ RootAgent=ask 时问"Bind 的人"，多人值班如何路由（复用 escalationChain？）？

## apply（v0.4 追加）

1. ❶ no-op 判定的字节级宽容度（空白/注释变化算不算 no-op）？
2. ❷ 跨系统提案待审区的展示与处理 UX 定在 console 哪个入口？
3. ❸ force 选项保留给谁（仅 Policy 高权限角色？）？

## revision（v0.4 追加）

1. ❶ LLM 语义 diff 的调用时机：仅 Conflict 时，还是每次 Apply 都出"变更归类"？
2. ❷ 语义 diff 提案的信任边界：哪些类别（格式噪声）可自动合，哪些必人裁？
3. ❸ token 成本：语义 diff 进预算（budget_log）吗？

## bind（v0.4 重写后）

1. ❶ role 词表自治度：自定义 role 要不要 Scheme 注册（防拼写爆炸）？
2. ❷ root 兜底待办的规模化：待办数阈值与分流策略（观测面指标先行）？
3. ❸ 双通道"同时处理"的冲突：谁先动谁算数？需要锁吗（还是靠幂等+SessionLog）？

## user-system

1. ❶ authentic 还是 authentik？（R3 原文 "authentic"——按 authentik（开源 IdP）理解，待确认）
2. ❷ contact 探测频率与降级链（IM 不可达→email→webhook 日志）？
3. ❸ IdP 接入后本地表的回退演练节奏（季度？随 storage 演练）？

## builtin（v0.5 起源标记后）

1. ❶ 起源判据：随 core_system 代码仓开发？随默认发版带出？第三方后来合入算不算？
2. ❷ origin 用 scope+label 双表达后，Policy 默认要不要给 core/origin=builtin 配一条人审规则（配置层默认值）？
3. ❸ builtin 对象升级随代码发版（R1.3）与文档侧 Apply 的节奏冲突如何对账？

## connector（v0.6 简化后）

1. ❶ 默认 org 的 Provider 仓形态：继续放 workservice 仓 connectors/，还是 org 下独立仓（如 core_system_providers）？
2. ❷ 带前缀 provider 的版本锁定语法（provider@v1.2 vs ref digest）定哪种？
3. ❸ tool 形态（外部直接工具）的安全边界：哪些 tool 允许零安装直接引用？

## skill

1. ❶ 沉淀自动化阈值：几次成功调用自动成 Skill（1 次太灵敏，3 次太迟）？
2. ❷ Skill 提升为 Global 的判据（引用热度？跨实例数？）？
3. ❸ Skill 与 provider.llmPrompt 冲突的检测时机：加载时校验 or 定期对账？

## core（v0.7 dsh plugin 承载后）

1. ❶ core plugin 与 builtinRoot/control plugin 同宿主时的启动序（谁先起、崩溃谁拉谁）？
2. ❷ 多机时 core plugin 是否仍单实例（v1 单机接受；跨机的预留点）？
3. ❸ "做通畅了"的判据定什么（首圈循环稳定跑 N 周？）作为启动独立 Core 界面的触发条件？

## workflow（v0.8 吸收 Loop 后）

1. ❶ core-loop 与 default-task 的边界：core-loop 是系统级循环、default-task 是单任务态机——同一轮里嵌套时（core-loop 的 Executing 内跑 default-task 任务）成本与刹车按哪层计？
2. ❷ 跨权限三出路的判定顺序写在哪：引擎硬编码（1→2→3）还是 Workflow 声明？
3. ❸ 提案方付费的成本规则：被提案方拒绝时成本是否返还记账（纯审计语义）？

## provider（v0.8 吸收 secret 后）

1. ❶ Provider 变更人审会不会拖慢轮换（90d 轮换遇审批积压）？轮换走免审通道的边界？
2. ❷ 原 credential 的 grantedTo 授权粒度并入后：auth.provider 授权给哪些 ConnectorOps 的声明放 Ops 侧还是 Provider 侧？

## event（Level 化后）

1. ❶ Level 与 Notification 的映射表（warn→?，error→?）默认值？
2. ❷ debug 事件要不要可选落盘（排障时开）？

## 横切（不属于单一概念）

1. ❶ 首个落地系统选谁：建议 developer-system（示例即它），因为它最"内"（gitlab/jenkins 都是标准 API），能最快验证 Connector+Loop 主链路。确认？
2. ❷ Core 的实现语言与技术栈（Go 最贴近 k8s 生态？）。
3. ❸ 观测面 v1 的形态：Event 流查看器 + drift 仪表盘，用现成（Grafana）还是自持最小 UI？
4. 这套设计先开源晒还是先内部跑通？影响 Connector 仓与凭证模型的默认值。
