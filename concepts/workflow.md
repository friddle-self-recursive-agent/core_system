# Workflow — 循环本体（触发规则→事件整理→处理→文档回归）

| 项 | 值 |
|---|---|
| K8s 对照 | Controller/Reconciler（触发+对账+刹车）与 Pod 相位机的合体 |
| 形态 | 对象：`global/workflows/`（builtin）与 `systems/<s>/workflows/<name>.yaml`（系统自定义） |
| 作用域 | Global（builtin）/ System |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. 定义

Workflow 是**完整的循环流程**：**触发规则 → 事件整理 → 事件处理（相位态机）→ 文档回归**。一句话：**Workflow 就是一条规则**——声明"何时看、看什么、怎么处理、怎么回归"，引擎按规则执行，规则之外引擎无动作。

**Workflow 可整体开启/关闭**（`spec.enabled`，Apply 切换）：关闭即该规则不再触发、不再消耗，已完成轮次与回归记录保留。**涉及哪些 service、怎么涉及、用哪个 LLM，全部在 Workflow 配置里声明**（`spec.services` / `spec.llm`）——换 LLM、圈 service 都是改配置，不是改代码。

**Workflow 是平台对象，不只是内部机制**：可编辑（spec=文档，Apply 修改，每一步可调整）、可展示（流程图/事件/流转/数据流，见 console）、可被第三方编辑与管理（导入/克隆/触发设置，同走 Apply+权限系统）、可启停（spec.enabled）。**developer_system 就是一种 workflow 实例**；不存在独立的循环 Kind。

### 核心内置 workflow 基座：`core-system-developer-loop` 与 `default-task`（2026-11-27 用户裁决）

> **核心裁决**：
> 1. **双内置基座（`core-system-developer-loop` + `default-task`），删除其余冗余内置 workflow**：
>    - **`core-system-developer-loop`**：管理自我迭代与研发发布闭环的主干工作流（出厂默认不启动 `spec.enabled: false`，不可删除 `undeletable: true`；2026-11-27 用户裁决：节点拓扑**可在前端加删**——`immutableNodes: false`，加节点/删验收节点走 draft→apply）。
>    - **`default-task`**：内置通用任务相位状态机（`Idle → Analyzing → Planning → AwaitingApproval → Executing → Verifying → Reporting`），供单次任务与 Agent Session 执行，其中 `session` / `agent` 节点支持通过 `globalRuleRefs` 引用相应的 `global` 规则（如 `rule/rule_eng`、`rule/rule_doc`、`rule/rule_ux`、`rule/rule_ctx`、`rule/rule_pub`）。
>    - 其余历史名称（`core-workflow`、`bug-lifecycle`、`bug-workflow`、`dev-delivery`、`apply-workflow`、`simple-shot`、`watch-only`）全部退入 `core/scheme.yaml` 的 `runtime.workflows.aliases` 做 Scheme Adapter 兼容映射，不再作为独立内置 workflow 存在。
> 2. **出厂默认不启动（`spec.enabled: false`）**：`core-system-developer-loop` 在 `core_system` 自身实例中因需要自我迭代才显式开启（`enabled: true`），而在 `业务实例` 等对外交付项目中**默认不启动**，需先通过 `systemBindings` 选择或配置绑定的 `developer-system` 与 `deploy-system`（`default` 默认开源习惯 / `install` 模板安装 / `import` 导入外部系统，一层层询问下去）后按需开启。
> 3. **不可删除，但主干节点可在前端加删、全节点参数与环境绑定在 Scheme/文档与前端可配置**（`undeletable: true`、`immutableNodes: false`——2026-11-27 用户裁决「我要加节点或者我要去掉验收节点了？」）：配置下沉到 `scheme.yaml` 的 `adapters` 与 `Workflow` 文档对象层，不再修改 Go 代码层级。
> 4. **多节点与多入口触发 + 临时 `BugDoc` 运行时闭环（不改设计也可触发，最后一步删 `BugDoc` 并回写 `InSync`）**：
>    - 不仅可以从首节点（监听日志/Event）触发完整闭环，当**用户通过对话/控制台修改设计文档**或**发现 Bug（不修改设计文档）产出/直接提交临时 `BugDoc`** 触发 `DocApplied` 时，直接从第 4 节点 **`doc-apply`（`Planning` 相位）** 切入，走同一条后续链路（`doc-apply → developer-system → 验收 → deploy-system → report-archive`）。
>    - 等整个流程改完并通过发版后，在 workflow 总结的最后一步 **`report-archive`（`Reporting` 相位）** 自动**删除临时 `BugDoc`**（调用 `DELETE /v1/objects/...` 发出 `DocDeleted`）并将目标 `ServiceInstance` 的状态修改回 **`InSync`**（清零 drift）。
>    - **`BugDoc` 属于运行时文档（`category: runtime, exportDefault: false`），默认不导出**：文档导出是一个**单独的数据库配置项目**（`docs_export_config` 表 + `GET/PUT /v1/docs-export/config`，种子初值由 `scheme.yaml` 的 `docTypes[].exportDefault` 决定，绝不在 Go 代码中写死类型判断）。
> 5. **默认 `OpenAIProvider` 点击即配 + 不同任务/不同 `ConnectorOps` 模型智商分级映射**：
>    - 所有 `session`、`connectOps`、`workflow` 均关联默认 Provider（`openai-default`）；在控制台点击任意 Provider 徽章即可弹出 **`OpenAIProvider` 配置抽屉**（配置账号/密钥引用、Base 地址 `baseUrl`、可用模型清单与任务模型映射）。
>    - 支持按任务类型与不同 `ConnectorOps`/节点配置不同模型档位：**重复性任务/日志清洗采集用低智商轻量模型（`tier: low`）**，常规研发任务用标准模型（`tier: standard`），**设计性任务/复杂根因诊断/Agent 评审用高智商推理模型（`tier: high`）**，可在界面自由修改映射。

```
【入口 1：运行期日志 / Event 触发 / 定时收集】
  ① log-event (Idle：监听日志 Event + 日志过滤 + ConnectorOps 收集指定日志；若 ConnectorOps 缺失可拉出代码开发任务)
   ↓
  ② agent-judge (Analyzing：Agent 判断是否值得修复 / 产出修复方案或临时 BugDoc；噪声则忽略直达 Reporting)
   ↓
  ③ approval-gate (AwaitingApproval：审批 / Agent 自动判断审批 —— human 人工 | agent 规则自动判断 | auto 全自动)
   ↓
【入口 2：用户对话或编辑器修改文档 → 触发 DocApplied 直接切入本节点】
  ④ doc-apply (Planning：文档落库 Apply / 汇聚点 —— 文档已修改即跳过前 3 步直奔研发实现)
   ↓
  ⑤ developer-system (Executing：调用绑定的 developer-system 落代码；缺失的 ConnectorOps 也在此拉出代码开发编辑)
   ↓
  ⑥ verify (Verifying：验收 —— 可配置怎么验收 code|agent|human|both 与自定义验收条件清单)
   ↓
  ⑦ deploy-system (Deploying → Reporting：调用绑定的 deploy-system 发版上线 → 清理临时 BugDoc + 文档/记忆回归收束 converged)
```

**`core-system-developer-loop` 标准 7 节点与引擎相位词汇映射表**（`global/workflows/core-system-developer-loop.yaml` 文档对象与 `scheme.yaml` 同源）：

| 序号 | 节点 ID (`name`) | 引擎相位 (`phase`) | 节点名称 (`title`) | 触发入口 (`entryEvents`) | Scheme Adapter 与可配置能力 |
|---|---|---|---|---|---|
| 1 | `log-event` | `Idle` | 监听日志与 Event | `BugReport`, `MetricThreshold`, `ExternalChanged`, `ReconcileTick`, `LoopRequested` + `timer` | **`logSource` Adapter**：配置监听事件类型、最低级别（`minLevel`）、服务/关键词过滤、定时巡检周期，以及**收集指定日志的 `ConnectorOps`**（若该 `ConnectorOps` 缺失或处于 `skeleton` 骨架态，定好 workflow 后直接拉出代码开发任务去实现/编辑） |
| 2 | `agent-judge` | `Analyzing` | Agent 判断 | —（由节点 1 推进） | **`agentJudge` Adapter**：配置判断准则（`criteria`，如判断运行 Bug 是否值得修复）、LLM 模型与分支输出（`worth_fixing` 进入审批；`ignore` 直达 `Reporting`） |
| 3 | `approval-gate` | `AwaitingApproval` | 审批 / 自动审批 | —（由节点 2 推进） | **`approvalGate` Adapter**：前端与文档可直接编辑切换 `mode: human | agent | auto`；`agent` 模式按 `autoCriteria` 与 `maxRiskLevel` 自动判断审批，高风险回退人工审批 |
| 4 | `doc-apply` | `Planning` | Doc Apply（文档修改汇聚点） | **`DocApplied`（第二入口：对话/手动改文档直接切入）** | **`docApplyEntry` Adapter**：既承接前序审批通过后的文档落库，又作为**多入口切入点**——用户对话修改文档触发 `DocApplied` 时跳过前 3 步直接从本节点进入 `developer-system` |
| 5 | `developer-system` | `Executing` | developer-system（代码开发） | —（由节点 4 推进） | **`systemBinding` Adapter (`developerSystem`)**：首先 `requires/select` 绑定 `developer-system`，按 `default`（默认开源习惯：`agent/<name>` 分支、`worktrees/<repo>/<slug>`、`tmp/`、单文件≤800行）/ `install`（模板安装）/ `import`（导入已有系统）逐层询问；支持拉出缺失 `ConnectorOps` 的代码开发与编辑 |
| 6 | `verify` | `Verifying` | 验收（Verify） | —（由节点 5 推进） | **`verification` Adapter**：可配置怎么验收（`mode: both | code | agent | human`）、绑定 `connectops-code-audit`、自由增删改验收条件清单（`conditions[]`）与失败策略（`onFail: retry-develop | block | ask`） |
| 7 | `deploy-system` | `Deploying` → `Reporting` | deploy-system（发版与回归） | —（由节点 6 推进） | **`systemBinding` Adapter (`deploySystem`)**：`requires/select` 绑定 `deploy-system`（`default | install | import` 逐层询问）、目标环境 `envs`、生产确认闸，完成后进入 `Reporting` 删临时 `BugDoc` 并归档 `DriftReport`/`SessionLog` |

> **正向相位序列与侧轨态严格分轨（修正 `Reporting --advance--> Failed` 缺陷）**：
> - `spec.phases` **只声明正向业务步序**；异常终态 **`Failed`** 与挂起态 **`Paused`** 属**侧轨态**，禁止列在 `spec.phases` 线性末尾。默认物化相邻 `advance` 边止于正向序列末步（`Reporting` 完成后单次 run 落正常收束态 **`converged`**，Workflow 本体按 P5 持续监听下一触发——绝不允许从 `Reporting` 经 `advance` 自动落入 `Failed`）。
> - `Failed` / `Paused` 仅由显式侧轨边到达（如 `ApprovalRejected → Failed`、`StepFailed → Failed`、`Escalate → Paused`）。
> - **单次 run 状态闭合集**：`triggered | running | suspended | converged | failed | canceled`；**静态迁移规则表（`transitions`）与运行期实际轨迹（`history: [{from, to, on, at, sessionId?, actor?}]`）必须分离**——UI 节点图按 `history` 标绿已走过的真实节点，不得按数组下标误把失败前未执行节点全标绿，也不得把静态 `transitions` 当事件时间线展示。

### 1.1 跨项目复用与逐层询问绑定（`core-system` vs `业务实例` 等对外项目）

`core-system-developer-loop` 同时服务两类场景，全部通过 **Scheme Adapter + 文档配置** 区分，零代码分支：

1. **`core-system` 自身实例**：
   - 在 `global/workflows/core-system-developer-loop.yaml` 中显式设置 `enabled: true`，直接管控 `core-system` 的自我迭代；
   - `systemBindings.developerSystem.resolution = default`（默认遵循本项目开源习惯：`agent/<name>` 分支、`worktrees/<repo>/<slug>` 隔离、单文件 ≤ 800 行、临时文件入 `tmp/`）；
   - `systemBindings.deploySystem.resolution = default`（默认发布至宿主与子模块链）。
2. **`业务实例` 等对外项目实例或业务自定义 Workflow（如监控 `bi-system` 运行 Bug 自动修复发版）**：
   - 出厂默认 `enabled: false`（不自动启动 core 自我迭代）；
   - 启用或配置时，首先由 workflow `requires` 或 `select` 相应的 `developer-system` 与 `deploy-system`，系统按 Template `resolver -> asks` 机制**一层层询问下去**：
     - **`default`（默认）**：使用系统内置的默认研发/部署通道与开源仓库规约；
     - **`install`（安装）**：若目标环境尚未安装 `developer-system`（如 OneDev）或 `deploy-system`，自动下探对应 `Template`（`appliesTo: servicedesc / workservice`）询问端口、存储、凭据并执行安装纳管；
     - **`import`（导入）**：将外部已有的代码仓/CI/CD/部署服务导入为 `WorkService` + `ConnectorOps` 并绑定到本 workflow 节点。

### 1.2 Workflow 落地与缺失 `ConnectorOps` 拉出代码开发（`apply-workflow`）

- 当用户在 `core-system-developer-loop`（或自定义业务 workflow）中配置了某个日志收集/过滤或业务交互 `ConnectorOps`（如 `connectops-bi-log-collector`），而该 `ConnectorOps` 尚不存在或仅处于 `workflow-bind` 骨架态（`skeleton: true`）时：
  - Workflow 定义保存（`Apply`）后，即可**直接拉出该 `ConnectorOps` 的代码开发任务**（生成 `ConnectorOps` 声明骨架并派发给 `developer-system` / `apply-workflow` agent 拉取代码仓库进行开发与编辑）；
  - 开发完成并通过 `verify` 节点（`connectops-code-audit` + 测试）验收后，由 `deploy-system` 构建生效。

### 1.3 执行模型：执行单元三型 connectops/agent/service（2026-11-27 用户裁决），gate=控制节点，默认绑定 ConnectorOps，apply 即实现

- **每个节点（相位/步骤）= 一个执行单元，词形三型**（2026-11-27 用户裁决「执行单元应该是 connectOps/agent/service」；旧 `session` 词形退役——原 session 节点按语义并入 agent/service）：
  - **connectops**：确定性胶水算子调用（日志收集过滤、代码审核 `connectops-code-audit` 等）——不可判断，按声明执行；
  - **agent**：**判断执行单元**（「agent 是可以判断的」）——会话/独立 agent 内做判断与产出（Agent 判断、Doc Apply 规划、总结归档）。**agent 节点点进即配**（前端节点表点击该行展开配置面）：该 agent 默认 LLM（`provider`/`model`/`modelTier`）、ref 的文档 `refDocs`、ref 的规则 `refRules`（工作流级缺省仍是 `globalRuleRefs`）、默认 ref 的 tag `refTags` 与 tag 规则 `tagRules`、随身工具 `tools`；
  - **service**：**调用目标系统**（developer_system / deploy_system…）——执行节点是 service，**service 内部用 service 自己的 agent 来执行**。**service 内部 agent 的执行载体=session**（2026-11-27 用户裁决「builtin 的 service 的 agent 可以用 session 来解决。突破下限制」）：run 推进落到 unit=service 节点时，引擎为 service 的 agent（`ServiceDesc.instances.agentRefs`）**开一个 session**（同 wake 桥/task-spawn 桥族的 session 拉起通路），`contextPassing` 上一轮详细上下文（run 历史逐字段汇聚——判断结论/方案与 diff/验收 findings/审批记录）作为**首轮输入注入该 session**；session 是完整执行形态（多轮/工具/三段式机制层，session.md），run **挂起在该节点**等 session 完成（session 心跳终结 → run 沿表续行，`history.sessionId` 回填真实会话锚）——**突破两条既有限制**：①service 节点执行从 declared-deferred 变真实通路；②「workflow 直挂 agent 必须 headless」只约束 workflow **直接挂载**的 agent 节点，service 内部 agent 挂在 `ServiceDesc.instances.agentRefs` 下、由 service 以 session 驱动，不受该条限制（agent.md 两类形态边界注记同账）。**builtin developer_system 的权限随文档授予**（P7 权限随文档走——`systemBindings.*.permissionRole` 绑 Role 文档，`Role.permissions` 以 `{scope, actions}` 条目声明，developer-system 系统文档同步标注）。
  - **gate**（控制节点，非执行单元）：审批闸门（`human` 人工批闸 / `agent` 自动判断审批 / `auto` 自动通过）——不计入执行单元三型。
- **验收节点 = developer-system 的 Agent 验收 session**（2026-11-27 用户裁决「验收也是 developer-system 的 Agent 的验收 session」）：verify 节点 unit=service 指向 developer-system（op=acceptance），service 内部 agent 开验收 session 逐条解释执行 `verification.conditions` 清单；**Report 节点也是 agent**（unit=agent）且随身工具（`tools`：读 findings / 写归档报告 / 打 tag）——记得提供相关工具。
- **节点拓扑可加删**（2026-11-27 用户裁决「我要加节点或者我要去掉验收节点了？」）：`immutableNodes` 不再恒 true（内置主干缺省 false）——前端节点表支持加节点/删节点（如删验收节点）/改节点参数，改动一律 draft→apply 落账（会话没有命令，§1.2 同源）。
- **默认绑定同名 ConnectorOps**：`core-system-developer-loop` 绑定 `ConnectorOps/global/core-system-developer-loop`，在 workflow apply 时自动物化节点接线骨架（`execution.state = bound`）。
- **可行性**：词形收敛=前端/scheme/YAML 三处枚举同步；**service 执行通路（2026-11-27 session 裁决落地）=引擎解析 unit=service**（对象 spec 透传加一投影：`SpecView.Nodes`——unit/service/op/agent 字段）+ session 拉起投影（ServiceSpawnSink 可选能力接口，与 WakeSink 同范式）+ 桥接拉起（plugin service-spawn 桥，与 task-spawn 桥同族：固定命令、载荷经 stdin、单飞锁）+ 完成续行（session 心跳终结 → run 沿表 advance）；contextPassing=run.history 已有逐相位轨迹可汇聚，引擎拼 payload 声明字段即可；权限=Role 对象既有 LoadObjects 判定，零新机制。

## 2. 边界

**是**：触发规则（含多入口节点触发與定时条件）+ 日志/事件过滤（含 `ConnectorOps` 收集）+ 相位态机 + 系统绑定（`developer-system`/`deploy-system`）+ 验收条件 + 刹车 + 文档回归——一个可配置、可编辑、可展示、可启停的平台文档对象。

**不是**：
- 不是散落在 Go 代码里的硬编码列表（内置仅 `core-system-developer-loop` 一条，配置全部沉入 `scheme.yaml` 与 YAML 文档对象）；
- 不是不可控的黑盒（`core-system-developer-loop` 本体不可删除，但主干节点**可在前端加删**（加节点/删验收节点），每个节点的执行单元、agent 配置（LLM/ref 文档/ref 规则/ref tag/tag 规则/工具）、审批模式、日志过滤、ConnectorOps、验收方式与验收条件在前端全部以人为本可视化可配）。

## 3. 对象结构（`global/workflows/core-system-developer-loop.yaml` 权威形态）

```yaml
apiVersion: core/v1
kind: Workflow
metadata:
  name: core-system-developer-loop
  scope: global
  labels:
    core/origin: builtin
spec:
  enabled: false                    # 出厂默认不启动；core-system 实例自我迭代时显式置 true，对外业务项目默认 false
  immutableNodes: false             # 2026-11-27 用户裁决：主干节点可在前端加删（我要加节点/去掉验收节点），参数全可配；改动走 draft→apply
  undeletable: true                 # 内置核心工作流不可删除
  services:
    involved: [core_system, developer-system, deploy-system]
    mode: act
  llm: {provider: llm-main, model: default}
  triggers:
    events:
      types: [BugReport, MetricThreshold, ExternalChanged, ReconcileTick, LoopRequested, DocApplied]
      minLevel: info
    timer:
      enabled: true
      interval: 10m
      resync: 10m
  logSource:                        # 节点 1：监听日志 Event + ConnectorOps 收集过滤配置
    events: [BugReport, MetricThreshold, ExternalChanged, ReconcileTick, LoopRequested]
    minLevel: warn
    services: [core_system]
    keywordMatch: ""
    timer: {enabled: true, interval: 10m}
    collector:
      connector: connectops-log-collector
      op: collect-logs
      query: "level>=error"
      autoDevelopOnMissing: true    # 若该 ConnectorOps 缺失/未实现，可一键拉出代码开发任务
  entryPoints:                      # 多节点入口配置
    - node: log-event
      phase: Idle
      enabled: true
      events: [BugReport, MetricThreshold, ExternalChanged, ReconcileTick, LoopRequested]
      description: "入口 1：运行期日志/异常事件/定时巡检触发，从头走 Agent 判断与审批"
    - node: doc-apply
      phase: Planning
      enabled: true
      events: [DocApplied]
      docTypes: [Goal, Desc, Rule, WorkflowDesign, CodeDesign, DeployDesign, BugDoc, Workflow]
      description: "入口 2：用户对话或控制台修改文档触发 DocApplied，直接从 doc-apply 节点切入走 developer-system → 验收 → deploy-system"
  approval:                         # 节点 3：审批 / Agent 自动判断审批配置（前端可直接编辑）
    mode: agent                     # human（人工审批）| agent（Agent 规则自动判断审批）| auto（全自动放行）
    autoCriteria: "单模块非破坏性代码或文档修改、不涉及高敏权限与生产数据删除时自动批准；其余转人工审批"
    maxRiskLevel: low
  systemBindings:                   # 节点 5 & 节点 7：研发与发布系统绑定（默认 | 安装 | 导入 逐层询问）
    developerSystem:
      service: developer-system
      resolution: default           # default（默认开源习惯）| install（模板安装）| import（导入外部系统）
      connector: connectops-developer
      op: develop
      permissionRole: role/developer-system-ops   # 2026-11-27 用户裁决：builtin developer_system 权限随文档授予（P7——Role.permissions {scope,actions} 条目）
      conventions:
        branchPrefix: "agent/"
        worktreeDir: "worktrees/<repo>/<slug>"
        tmpDir: "tmp/"
        maxFileLines: 800
    deploySystem:
      service: deploy-system
      resolution: default           # default | install | import
      connector: connectops-deploy
      op: release
      permissionRole: role/deploy-system-ops      # 同上：权限随文档授予
      envs: [staging, prod]
      requireProdApproval: false
  verification:                     # 节点 6：验收方式与验收条件配置（前端可自由编辑增删）
    mode: both                      # both（代码+Agent）| code（仅代码审核）| agent（仅Agent规则）| human（人工验收）
    connector: connectops-code-audit
    op: audit
    onFail: retry-develop           # retry-develop（打回 developer-system 重修）| block（阻断上报）| ask（人工裁决）
    conditions:
      - {id: lint-rules, kind: code, title: "代码 Lint 与规则审核 (R-PUB-1 / R-DOC-6 / R-ENG-7 ≤800行)", command: "connectops-code-audit/audit", required: true}
      - {id: unit-tests, kind: test, title: "后端与前端单元/集成测试全绿 (go test ./... & npm test)", command: "go test ./... && npm test", required: true}
      - {id: live-probe, kind: agent, title: "活体探针与页面无假数据/无报错验证", command: "agent-verify", required: true}
      - {id: bugdoc-clean, kind: agent, title: "临时 BugDoc 验证通过后清理 (R-DOC-10)", command: "doc-clean-check", required: false}
  phases:
    - {name: log-event,        phase: Idle,             title: "1. 监听日志与 Event",        unit: connectops, connector: connectops-log-collector, op: collect-logs, provider: openai-default, modelTier: low,      entryEvents: [BugReport, MetricThreshold, ExternalChanged, ReconcileTick, LoopRequested]}
    - {name: agent-judge,      phase: Analyzing,        title: "2. Agent 判断（或产出 BugDoc）", unit: agent,      op: judge-issue,  provider: openai-default, modelTier: high,     refRules: [rule/rule_eng, rule/rule_doc]}
    - {name: approval-gate,    phase: AwaitingApproval, title: "3. 审批 / 自动判断审批",     unit: gate,       op: approval-check}
    - {name: doc-apply,        phase: Planning,         title: "4. Doc Apply（设计/BugDoc 切入点）", unit: agent, op: apply-doc,    provider: openai-default, modelTier: standard, refDocs: [goal], refRules: [rule/rule_doc, rule/rule_eng], refTags: [audit, fix], tagRules: [rule/tag_default], entryEvents: [DocApplied]}
    - {name: developer-system, phase: Executing,        title: "5. developer-system 研发（service 内部 agent 执行）", unit: service, connector: connectops-developer, op: develop, service: developer-system, contextPassing: {previousRound: true, fields: [judge, plan, diff, approval]}, permissionRole: role/developer-system-ops}
    - {name: verify,           phase: Verifying,        title: "6. 验收（developer-system Agent 验收 session）", unit: service, service: developer-system, op: acceptance, contextPassing: {previousRound: true, fields: [diff, verifyConditions]}}
    - {name: deploy-system,    phase: Deploying,        title: "7. deploy-system 发版（service 内部 agent 执行）", unit: service, connector: connectops-deploy, op: release, service: deploy-system, contextPassing: {previousRound: true, fields: [verifyReport, release]}, permissionRole: role/deploy-system-ops}
    - {name: report-archive,   phase: Reporting,        title: "8. 总结删 BugDoc + 回写 InSync", unit: agent, op: archive-report, provider: openai-default, modelTier: low, tools: [findings-read, doc-draft, tag-write]}
  transitions:
    - {from: Idle,             on: advance,          to: Analyzing}
    - {from: Idle,             on: "entry:DocApplied", to: Planning}
    - {from: Analyzing,        on: advance,          to: AwaitingApproval}
    - {from: Analyzing,        on: worth_fixing,     to: AwaitingApproval}
    - {from: Analyzing,        on: ignore,           to: Reporting}
    - {from: AwaitingApproval, on: advance,          to: Planning}
    - {from: AwaitingApproval, on: ApprovalGranted,  to: Planning}
    - {from: AwaitingApproval, on: ApprovalRejected, to: Failed}
    - {from: Planning,         on: advance,          to: Executing}
    - {from: Executing,        on: advance,          to: Verifying}
    - {from: Verifying,        on: advance,          to: Deploying}
    - {from: Verifying,        on: retry-develop,    to: Executing}
    - {from: Deploying,        on: advance,          to: Reporting}
  onEscalate: {action: pause, notify: bind-role}
  onFailed:
    backoff: 30s*2^n
    maxAttempts: 3
    rollbackPolicy: by-step
    escalate: {to: root, notify: bind-role}
  trustGate:
    enabled: true
    mode: code
    verifierRef: "connectops-code-audit/verify-external"
    onReject: ask
  brakes:
    cooldown: 2m
    maxMutationsPerTick: 10
    avoidRepeatFix: true
  regression:
    statusWriteback: true
    bugDocPolicy: invalidate        # delete（删除）| invalidate（标记失效归档）| keep（保留不删除）——可配置、可增删动作项
    cleanTempBugDoc: false          # 兼容简写开关（true 等价于 bugDocPolicy=delete；默认走可增删 postActions 声明）
    postActions:                    # 解释器通用收尾动作列表（前端/文档可自由添加、删除或启停任一条目）
      - {id: bugdoc-lifecycle, kind: doc-lifecycle, targetDocType: BugDoc, action: invalidate, enabled: true, title: "临时 BugDoc 收尾处理（可选：标记失效 invalidate / 删除 delete / 保留 keep，或直接删去此项）"}
      - {id: status-insync,    kind: status-writeback, targetPhase: InSync, enabled: true, title: "回写 ServiceInstance.status.phase = InSync"}
    reports: [DriftReport, SessionLog]
```

## 4. 生命周期

注册（builtin 或系统自定义，Apply）→ 触发规则命中即一轮循环 → 相位运转（SessionLog 记录）→ 回归（Status+DriftReport）→ 冷却 → 待下一触发。相位语义变更需新版本名（只加不改）。

## 5. 与其他概念的关系

- ConnectorOps 必绑 Workflow（缺省 default-task）——op 调用的相位约束。
- Agent 的任务态机=引用 default-task；Workflow 引擎（core plugin 内）统一调度所有 Workflow 实例。
- **执行载体只可能是后台执行（headless）agent（2026-11-27 用户裁决）**：Workflow run 不落对话 agent（对话 agent=与人交互面，两者模式与询问不一致）——触发**通知**与**审批**作为 headless agent 的默认工具随 run 注入（通知=Notification 面；审批=`ApprovalNeeded`→`AwaitingApproval` 闸锚挂起→role 持有者批）。agent.md §1/§4 同账。**边界（2026-11-27 session 裁决）**：拒绑 chat / headless 词形只约束 workflow **直接挂载**的 agent 节点；service 节点的内部 agent 挂 `ServiceDesc.instances.agentRefs`，由 service 以 **session** 驱动执行（§1.3）——session 是完整执行形态，不受该条约束。
- Escalate 出口：默认上溯 root agent；有 role 挂载时 role 持有者经 Notification 同达。
- TaskScheme 在 Executing 相位内跑；Skill 缓存服务 Agent 层。
- **展示**（console）：workflow 详情=同一对象工作台——默认**关注报告**（发生了什么/值得关注/下一步）+常驻对话；流程图/事件/流转/数据流/运行/配置为次级 tab；操作（启用/停用/编辑/克隆/导入）全部=Apply。渲染数据全部来自 Scheme+ops DB。**成本观测归 metrics**，不占 workflow 详情页。（R-UX-7；acceptance/console/console-ui.md §14.6）
- **第三方**：其他系统/他人编辑、导入、管理、触发设置，走同一 Apply+权限系统入口；导入=外部编排渲染成 spec（预览=dry-run，导入件首期 observe 模式）。
- **落地 agent**：新 workflow 的接线/代码化由 `apply-workflow` agent 承担（§1.2）。

## 6. 设计规则

1. 相位/迁移纯声明（相位机=标准 FSM：引擎按声明执行，规则之外无动作；失败走 onFailed）。
2. 刹车三件套（cooldown/maxMutations/avoidRepeatFix）为 Workflow 级强制默认，可收紧不可关闭。
3. **预算/成本不在核心循环语义内**：budget 是 metrics 关注的东西（由 ConnectorOps 收集→agent 报告的默认 workflow 承接），暂不做——核心循环只有触发/整理/相位/回归，不再往里加预算机器。
4. builtin Workflow（**双内置基座：`core-system-developer-loop`、`default-task`**——2026-11-27 通用解释器收敛；core-workflow/simple-shot/watch-only/dev-delivery/apply-workflow/bug-lifecycle 等旧名退入 scheme `runtime.workflows.aliases` 兼容映射，不再独立占册）修改属高敏 权限系统 项；builtin 正向相位词汇映射（§1 映射表）是声明面，运行时注册表与它同源——映射未落设计的 workflow 不进注册表（不即兴发明）；`Failed`/`Paused` 为侧轨态，默认物化 `advance` 边止于正向序列末步（落 `converged`），绝不自动 advance 至 `Failed`。
5. 触发规则必须与事件 Level 联动（minLevel 过滤）。
6. **核心定时驱动**：存在一个核心定时器——system 的 agent 定期处理 event 与报告，转给上游 global 汇聚（上游再 workflow 分析）；**builtin 域不走远端，event/报告本地处理**。timer.resync 是这条链的保险丝（level-triggered，丢事件靠巡检兜底）。
7. **流程可读性**：workflow spec 由 LLM 生成本段白话描述 + 流程图（mermaid），随对象详情展示——规则是数据，解释与图按需生成，不入库为准（重新可生成）。
8. **数据流必声明**（spec.dataflow inputs/outputs）——展示与对账依据；缺声明=Lint 报警。
9. **导入件治理**：origin=import 的 workflow 首期强制 observe 模式（只读跑一段再放开 act）；第三方编辑同权限系统裁剪（P7）。
10. **暂停策略可配置（onEscalate）**：AUTO 处理不了的 Escalate 到达时——Workflow **可以判断是否暂停**，也可以**按策略自动暂停**；pause=立即挂起（Paused 相位），finish-tick=本轮跑完再停，continue=只通知不停。默认 pause。挂起现场与断点由 SessionLog 承载，恢复=人批 Resume（=Apply），通知走 bind-role 双通道（root 上报+Bind 发送）。
11. **落地代码化**：workflow 的接线与连接层实现由 apply-workflow agent 经 developer-system 代码化完成；运行时不做即兴接线。
12. **相位推进器首段——迁移判定=声明序列单调前进（引擎真实驱动）**：run 受理即启动信号——引擎在受理路径上执行**单步迁移判定**：builtin run 从声明首相位**沿声明相位序列（§1 映射表）单调前进一步**（Idle→Analyzing），run 状态词翻转 `triggered→running`（触发已受理→首步进行中）。迁移规则=**序列前进**（「相位机=标准 FSM，序即声明」的机读落点：builtin 相位序列为线性声明，序列本身即迁移声明；显式 Transition 表首段已落 v0.25=规则 14——判定器改查表、序列前进=表的特例；异步推进已落 v0.26=规则 15——受理之后由装配层定时驱动逐段承接）；object 源 run 相位不投影=无从迁移，status 恒 `triggered`；已居序列尾（Failed 等终点相位）不再前进。**run 出现 ≠ 对账执行完毕口径不变**：`running`=首步进行中（Analyzing 进行中），后续相位推进仍由引擎逐段承接，不冒充执行完毕。
13. **相位推进器后续段首段——挂起-恢复（闸锚挂起判定+审批信号迁移，引擎真实驱动）**：闸锚=声明相位序列中的 `AwaitingApproval` 锚（§7 出路 3 人批闸；dev-delivery 的 Gate=同词锚位——**闸锚必须在声明序列内**，无闸锚的序列无挂起面）。三层判定（迁移判定在序列前进之上的扩展，判定器同一落点）：
    - **闸锚挂起**：run 迁移判定落点=闸锚 → run 挂起（status 词=`suspended`）——挂起=相位机等待外部审批信号，非终态、非执行完毕；
    - **审批提升**：审批提升信号（`ApprovalNeeded`，involved=Workflow 对象引用，event.md 规则 11）到达 → 该锚最新 run 相位落闸锚挂起（§7「AwaitingApproval 相位插入」的机读落点）；声明无闸锚的序列=零动作；
    - **批准恢复/驳回终态**：批准信号（`ApprovalGranted`）→ 闸锚沿声明序列续行（status 翻回 `running`——恢复=序列续行，原相位不回跳；细粒度断点续跑靠 SessionLog，载体未落地挂账）；驳回信号（`ApprovalRejected`）→ 终态（相位=声明终点锚 Failed，status=`failed`）。
    审批信号按 involved 的 workflow 锚寻径（event.md 规则 11），作用于**该锚最新 run**；**审批信号是相位机的迁移事件，不是新对账触发**——不另起新 run（规则 6「事件只触发」的触发对象=run 相位机迁移判定）；零动作防御面：object 源无从迁移、终态不迁移、非挂起态无可恢复、锚无 run 无可作用。**run 出现 ≠ 对账执行完毕口径不变**（挂起/恢复都是相位机推进留痕）。
14. **显式迁移表首段——判定器=查表（声明表驱动，引擎真实驱动）**：迁移判定从「序列前进」泛化为**声明表驱动**——builtin 表=声明序列**物化相邻行**（`from=seq[i] on=advance to=seq[i+1]`，序列前进=表的特例：表行全量物化，判定器纯查表 `from+on` 命中→`to`、未命中=零迁移）+**挂起-恢复审批边=表行先例**（批准边 `from=闸锚 on=ApprovalGranted to=闸锚后继`——与相邻行同目标、异事件名；驳回边 `from=闸锚 on=ApprovalRejected to=终点锚 Failed`——**表的首处非相邻迁移行**，机械判别器=非相邻迁移按表命中而非隐式走序列）。受理首步、批准恢复、驳回终态三路径共用同一查表落点；**行为面不变**（物化相邻行⟷序列前进等价，既有序列语义零翻转）。零动作面在表物化即收口：声明无闸锚/无终点锚的序列=无对应审批边（判定器无需特判）。查询面新增**声明表可见键**：run 投影新增 `transitions` 字段（表行 from/on/to 投影——**新载荷键出现=代际判别器**；object 源 spec 随文档面不在本进程，表不投影=空数组）。Workflow spec 声明终态形态 `transitions: ?[]{from, on, to}`（对象自声明迁移表解析首段已落 v0.27=规则 16——投影先行，对象源表投影见规则 16）。余量：对象源相位投影与迁移判定接线（下一段）。
15. **异步推进首段——装配层定时驱动（run 推进 tick，引擎真实驱动）→ 事件驱动推进源首段（下一段已收口）**：受理之后的相位推进由引擎**逐段承接**——装配层定时器每拍对每个现势 run 执行**单步迁移判定**（查表 `on=advance`——判定器同一查表落点复用，本段只加驱动源不动判定器）。落点语义=**迁移判定落点的通用规则**（规则 13 第一层判定的推广，StartRun/ResumeSignal 同款落点口径）：落闸锚（`AwaitingApproval`）→挂起（status=`suspended`）；落终点锚（`Failed`）→终态（status=`failed`——RunFailed 词汇即迁移终点语义，非引擎失败语义）；序列尾（无 advance 行命中）→零动作停（status 保持 `running`——诚实投影不冒充执行完毕，**不新增 done 词形**）。零动作防御面：`triggered`（object 源相位不投影）、`suspended`（挂起面不前进——审批信号之前相位机等待）、`failed`（终态不迁移）一律原样保留；每拍每 run 至多一步（逐段承接，不跳步）。装配口径=巡检保险丝同款（event.md 规则 10 范式）：`--advance-interval` 显式开启、缺省关断零推进（缺省不改既有行为面——受理首步同步推进 v0.23 口径恒在）。查询面新增**推进可见键**：run 载荷新增 `advances`（累计推进 run·步计数——**新载荷键出现=代际判别器**）。机械判别器：run 相位随拍沿声明序列（表推进行）前进 ∧ 落闸锚挂起即停 ∧ 批准恢复后继续推进至落终态即停 ∧ 关断实例 run 相位不随时间变化。
    **事件驱动推进源首段（v0.29——巡检拍与推进拍合一）**：推进的驱动源=二——装配层定时拍（上文）+**事件拍**：引擎内部源事件（source=`core`，event.md 规则 10 服务侧判定口径）落 run 的同拍，对该拍现势 run 全量执行一次单步推进（与定时拍同一查表落点、同一落点语义——判定器零改动，只加驱动源；本拍新落 run 参与本拍=全量口径不含特判，受理首步与事件拍是两条独立口径的拍步）。首段生产者=ReconcileTick（event.md 规则 10）；connector watch/metrics 阈值等其余引擎内部源随各自声明面顺延自动纳入同一拍面（落 run 同拍即拍，零新开关）。**connector watch 桥接源入拍面（v0.30——驱动源集合扩展）**：第二生产者=connector watch 桥（event.md 规则 12——装配层驱动 Watch 契约通道自产 ExternalChanged，source 服务侧判定恒 connector，dedupKey=驱动侧因由声明），落 run 同拍即拍——拍面驱动源集合=引擎装配的内部源（`core`=规则 10 巡检+`connector`=规则 12 watch 桥+`metrics`=规则 13 阈值桥；其余引擎内部源随各自声明面顺延），零新开关（事件拍仍是总闸连坐的事件面不是开关）。v0.29 判别器措辞收窄：人注事件落 run 不触发事件拍（注入通道 source 恒 human——不在拍面；权限自产 permission 同不在拍面）；connector watch 桥接源=引擎装配内部源，入拍面。**关断语义组合（声明面先定）**：推进总闸单一=`--advance-interval`（上文口径不变）——总闸关断=一切异步推进关断（定时拍与事件拍同闸连坐，事件驱动源不旁路总闸；巡检-only 部署行为面零翻转）；`--reconcile-interval` 关断（或 ReconcileTick 未注册）=无源事件→事件拍自然缺席（事件驱动源无独立开关——驱动源存在性随事件源，与「注册表是引擎内部源唯一开关」同口径）；双源同开=两拍面并行（各自独立拍面、各自每拍每 run 至多一步，相邻拍各一步不合并不跳步）；缺省（两旗标缺省 0）=零异步推进，行为面不变。机械判别器：总闸开启+巡检开启实例 run 相位随巡检到点沿声明表前进（含本拍新落 run 同拍第二拍步）∧ 总闸关断+巡检开启实例 run 相位恒受理首步形态（事件拍连坐关断）∧ 人注事件落 run 不触发事件拍（source 维度分立——事件拍只认引擎装配内部源集合，v0.30=core+connector）。**metrics 阈值桥接源入拍面（v0.31——驱动源集合扩展）**：第三生产者=metrics 阈值桥（event.md 规则 13——装配层阈值桥数据面样本通道服务侧判定自产 MetricThreshold，source 服务侧判定恒 metrics，dedupKey=`<metric>:<window>`），落 run 同拍即拍——拍面驱动源集合=引擎装配的内部源（core+connector+metrics），零新开关（事件拍仍是总闸连坐的事件面不是开关）。v0.29 判别器措辞收窄不变：人注事件落 run 不触发事件拍（注入通道 source 恒 human——不在拍面）；权限自产 permission 同不在拍面。机械判别器追加：metrics 阈值事件落 run 同拍两拍步（受理首步+事件拍——与 core/connector 同拍面同口径）。余量：其余引擎内部源事件拍声明面顺延、刹车/冷却/minLevel 与真实执行面接线。
16. **对象声明表解析首段——object 源 run 表投影（引擎真实驱动）→ 相位投影与迁移判定接线（下一段已收口）**：Workflow 对象的自声明 spec（`spec.phases` 相位序列+`spec.transitions` 迁移表，scheme.yaml 声明终态形态）随文档面存在——apply 落库（校验闸门=形态 `{from, on, to}` 行+`[]Phase` 序列）后，object 源 run 的查询面从恒空投影变为**对象 spec 投影**（相位序列+声明表行，声明→留痕面：原样、顺序保留、非相邻行原样投影不解释语义）。解耦口径：引擎不感知文档库——解析面由装配层注入（**可选能力**，ResumeSink 同款范式：未挂文档库/未命中/损坏文档/未声明=零投影，既有行为面不变）；零缓存=apply 落库即生效（热装载语义天然跟随，无失效窗口；单次 lookup 两面齐投）。**相位投影即点亮判定**：判定器与推进器已完全表驱动（规则 14/15），声明了 `phases` 的 object 源 run 参与同一查表判定——受理首步（`on=advance` 命中→相位沿声明表推进、status 翻 `running`）、审批信号（提升落闸锚挂起/批准边续行/驳回边终态）、异步推进（随拍单步查表，落闸锚挂起/落终点锚终态/序列尾零动作停）三路径自然生效，判定器零改动；相位词汇基座=Agent 八相位+Deploying（§1 映射表——闸锚 AwaitingApproval/终点锚 Failed 在词汇内，防御面自然生效）。**零投影口径不稀释**：未声明 `phases` 的对象=零相位投影（status 恒 `triggered`、相位恒空——三条判定路径零动作防御面原样生效）；只声明 `phases` 未声明表=相位投影起步（受理投影=声明首相位）但无 advance 行=零迁移（诚实投影不冒充推进）。机械判别器：object 源 run 载荷 `phases`=声明序列（顺序保留）∧ 声明 advance 行命中时受理首步 `phase`=第二相位∧`status=running` ∧ 审批信号按声明表迁移（闸锚挂起/续行/终态）∧ 未声明 phases 对象 run `status` 恒 `triggered`∧`phases` 空数组（对照面）。
17. **刹车首段——冷却门与推进拍变更上限（表驱动，引擎真实驱动）**：刹车三件套的执行面首段——**强制默认**=cooldown 2m ∧ maxMutationsPerTick 10（§3 示例值升格为 builtin 强制默认；avoidRepeatFix 随 DriftReport 回归声明面顺延，本段不落）。**收紧判定（可收紧不可关闭的机读落点）**：spec.brakes 声明值只允许收紧——cooldown 只增 ∧ maxMutationsPerTick 只减；宽松方向声明（cooldown 小于默认、变更上限大于默认或非正值）一律**钳回强制默认**（运行时不即兴不拒绝——钳回=不可关闭的机械落点；声明形态合法性仍由写路径 scheme 校验闸门承担）。**刹车闸（装配层可选能力，ResumeSink 同款范式）**：刹车闸未挂接（缺省关断）=零刹车——触发全落 run、推进不限量，既有行为面零翻转（基线保护）；挂接后两路生效：
    - **冷却门（受理路径）**：同锚同 involved 窗口判——该锚该 involved 最新 run 受理时刻起 cooldown 窗口内的后续触发**不落 run**（触发留痕仍在，braked 计数可见）；窗口外照落；跨 involved 不互踩（防震荡语义粒度=同一对象——对象级修复互踩是震荡本体，锚级窗口会误伤并行对账）。cooldown 锚首段=run 受理时刻（完成语义缺位——「成功后最小间隔」的完成锚随真实执行面接线后切换，锚切换规则声明面先定）；冷却门只作用于受理落 run 路径且不区分 source（触发→run 转换的统一闸），审批信号面不经此门（审批信号是迁移事件不是对账触发，规则 13 口径不变）。
    - **推进拍变更上限（推进路径）**：每拍对每锚的 run 相位变更数受生效刹车值约束（变更单元首段=run 相位变更留痕）；上限只计实际发生的迁移（序列尾零动作不占额）；超限 run 本拍零动作、下拍续推（level-triggered 不丢拍）。
    **关断语义组合（声明面先定）**：刹车闸单一挂接点=部署旗标显式开启（缺省关断=零刹车行为面不变）；刹车闸与推进总闸、巡检闸正交（刹车只作用于已挂接的执行路径，不产事件不旁路任何闸；受理冷却门在订阅路径上与写面开关分立——只读装配亦可挂接）。**表驱动口径**：刹车值是声明数据（spec.brakes → 强制默认钳定 → 每锚生效值），判定面零即兴——每 run 载荷投影生效刹车值（`brakes` 键：cooldown、maxMutationsTick、source（default=强制默认、spec=声明收紧值）——**新载荷键出现=代际判别器**）。查询面新增**刹车可见键**：run 投影状态新增 `braked`（累计冷却门拦阻触发数）与 `capped`（累计推进拍上限拦阻 run·步数）——新载荷键出现=代际判别器。机械判别器：刹车闸挂接实例同锚同 involved cooldown 窗口内第二触发不落 run（braked>0）∧ 窗口外照落 ∧ 跨 involved 照落 ∧ 推进拍锚内变更数超上限时超额 run 相位本拍不变（下拍续推）∧ 未挂接实例同型触发全落 run 且 braked=0（双实例对照）。余量：avoidRepeatFix 与 DriftReport 回归面、cooldown 完成锚切换、minLevel 与真实执行面接线、事件拍余量源。
18. **Verify 节点=规则验证硬 gate（code→ConnectorOps；agent→丢给 agent）**：代码开发流程的 `Verifying` 必须执行两类验证——① `mode: code` 规则经 scheme `runtime.ruleChecks` 由 `connectops-code-audit` 审核（只读、findings 结构化）；② `mode: agent` 规则把规则原文（ref+hash）+ diff/上下文交给指定 agent/服务 agent 验证（verdict + 证据）。`error` finding / `fail` verdict 阻断 Deploy；`warn` 进 Report；checker 未注册/未实现/超时、agent 不可用/`unverified` = 显式失败或降级，**不得默认通过**。Verify 节点缺失=流程缺陷（相位序列 Execute→Verify→Deploy 强制）。
19. **回滚区分「要不要回滚 + 四类回滚方式 + 回滚文档描述」（2026-11-26 用户裁决）**：Execute 相位失败时的回滚绝非一刀切，严格按步骤/工具声明的 `rollback: {policy: never|auto|ask|optional, type: irreversible|code|agent|human, description, docRef?}` 执行：有些根本没办法回滚（`irreversible`，事前人审、事后补救不逆操作）、有些不需要回滚（`never` 或 `ask` 决定不回滚而直修）、有些由代码确定性回滚（`code`）、有些由 Agent 读回滚文档描述诊断后回滚（`agent`）、有些挂起交给人按 Runbook 回滚（`human`）。
20. **并发任务冲突在 Apply 关口拦截并直接询问「暂停第一个还是放弃当前任务」（2026-11-26 用户裁决）**：两个同时冲突的任务在 `Apply` 这一关就会被乐观锁拦截（保障最终一致）。第一个任务 Apply 后，第二个任务到达 Apply 关口判断有没有实质冲突；若有冲突，直接挂起并询问上级 Agent 或人：**暂停第一个任务（`pause-first`）还是放弃当前任务（`abort-current`）**。
21. **外部系统 `trustLevel` 与 Workflow 级可配置内容检验门（`trustGate`，2026-11-26 用户裁决）**：默认内部系统都是可信的（`trustLevel: trusted`）；对接外部系统的 `Provider` 与 `ConnectorOps` 声明 `trustLevel: external`。当 Workflow 节点消费 `trustLevel: external` 的外部内容时，由 Workflow 级可配置的 `spec.trustGate`（`mode: code | agent | both`）先让代码或 Agent 判断一遍外部内容是否 OK（无注入/越权/污染），通过后方可进入 Context 与下游相位。

- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

## 7. 跨权限完整分析

Workflow 天生跨权限：一轮 core-workflow 要穿过五个权限域。逐点分析：

| # | 穿越点 | 涉及权限 | 谁持有 | 越权风险 | 机制 |
|---|---|---|---|---|---|
| 1 | 事件读取 | bus 订阅（按 selector/level） | Workflow 引擎（core plugin） | 低（读信号非资源） | 引擎统一订阅，按 triggers.minLevel 过滤 |
| 2 | 文档读取 | docs权限系统.read（L0/L1） | 执行 Agent | 中（读越界=信息泄露） | 白名单+按需加载，SessionLog 记 docsLoaded |
| 3 | 计划 | 无副作用 | Agent | 无 | Planning 相位只读 |
| 4 | 执行 | ConnectorOps 并集 | 执行 Agent | **高（核心风险点）** | 见下"三条越权出路" |
| 5 | 状态回写/文档回归 | fieldManager（engine/agent） | 引擎与 Agent 分持 | 中 | Status=engine 专写；Spec 类默认 Agent 无权（P6） |

**执行越权的三条出路（Workflow 不能静默越权）**：

1. **权限齐备**：Workflow 的 owner Agent 引用齐所需 ConnectorOps（权限并集覆盖全部步骤）——常态路径。
2. **跨系统提案**：步骤落在别的系统域 → 不直接执行，Apply 提案进对方待审区，由对方自己的 workflow 处理（系统间调用=互相 Apply 的语义）。
3. **审批提升**：缺权限且必须本 workflow 执行 → AwaitingApproval 相位插入，role 持有者人批（一次一批，token 制可选）。

**委派模型（一次性全量下发）**：上级委派任务=**一次性把权限全给全**——上级 agent 把自己的权限（ConnectorOps/Ref/Provider/role 并集）整包下发，权限 token 与 ref 直接给到执行 agent，不做按步骤细粒度裁剪。子 agent 权限仍 ⊆ 父（只减不增的不变量不变——扩权源头只能是上级/审批，agent 不能自增，扩权路径仍是 2/3）。**运行时发现缺权限 → 直接 ask 上级，上级重新一次性全量申请并整包重发**（挂起-恢复由 SessionLog 断点承接）。root 例：root 的 agent 默认下发任务时，判定为根 → **先向所有 Service 请求权限**（各 Service 侧判定放行），拿到的权限 token 与 ref 直接下发给需要执行的 agent。

**代码设计影响**（复杂度来源与对策）：

- 引擎须按相位做权限校验（Planning 只读放行；Executing 逐步校验 ops 归属）→ 引擎持有权限索引（Agent 引用并集的物化），校验是查表不是即席计算。
- 提案与审批是异步的 → 相位机要有挂起-恢复（AwaitingApproval ↔ 批准/驳回），断点续跑靠 SessionLog。
- 成本观测归 metrics（预算暂不做）：若日后做跨系统成本分摊，规则沿用"记发起方（提案方付费），被提案方执行轮成本记己方"。

**可行性结论：⚠️ 高复杂度，但可行且有清晰分阶段路径**：

| 阶段 | 范围 | 风险 |
|---|---|---|
| v1 | 出路 1（权限齐备）+ 出路 2（提案）；审批仅 权限系统 高危拦截面 | 低——单 owner 权限内执行，引擎校验退化为"步骤 ops ∈ owner 并集"查表 |
| v2 | 出路 3 全量（审批提升 token 制）+ 挂起-恢复完善 | 中 |
| v3 | ask-上级重发链路完善；跨系统成本分摊（归 metrics 域） | 中 |

关键判定：**复杂度在权限校验的完备性，不在相位机**（相位机是标准 FSM）。v1 先行不阻塞首圈循环。

## 8. 可行性分析（常规项）

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 震荡 | ⚠️ 中 | 修复互踩 | 刹车三件套（§6.2） |
| 成本失控 | ⚠️ 中 | 高频触发×大上下文 | 刹车三件套+metrics 事后聚合（预算强制暂不做，budget 归 metrics 域） |
| 多 workflow 修同一外部资源 | ⚠️ 中 | 交叉写 | 单一 owner Workflow 写；跨域走提案（§7 出路 2） |
| 第三方编辑权限面 | ⚠️ 中 | 谁能改谁系统的 workflow | scope 写权限+权限系统裁剪；builtin 修改=高敏项 |
| 导入渲染失真 | ⚠️ 中 | 外部编排语义≠声明式相位 | 导入预览=dry-run；origin=import 首期 observe 模式 |
| 展示数据双源 | ⚠️ 低 | 前端自建状态会漂移 | 渲染数据全部来自 Scheme+ops DB（硬性约定） |

## 9. 待决问题

见 open-questions.md#workflow

## 9a. 「Workflow + Scheme = 声明层、代码 = 通用解释器」与原临时 BugDoc 闭环失效收敛（2026-11-27 用户裁决）

> 用户原话：「完整的内置的应该是改成这个 `core-system-developer-loop` 默认在出厂不启动。因为我这个 core-system 要自我迭代才启动。对外项目就不会启动这个。`core-system-developer-loop` 是管理 core-system 自我迭代的，不可删除，不可调整节点，可以进行一些基于基础环境的配置，默认就是我基于这个项目的开源习惯……这个就是标准的 监听日志event->agent判断->[审批/自动审批]->doc apply->developer-system->验收->deploy-system……还有 workflow 可以多节点、多节点配置，比如用户对话修改了文档，触发 doc apply，也走下面逻辑这一条。临时 BugDoc 闭环应该是失效。本质 workflow+scheme 代码是解释器。这个删除 bugdoc 默认是可以添加删除以及选择不删除的。」

1. **代码只做通用解释器（Interpreter）**：
   - `workservice` 引擎不硬编码任何业务专用闭环；原先单独设立的「临时 BugDoc 闭环（`bug-lifecycle`）」失效作废。
   - 节点怎么触发、过滤什么日志、调哪个 `ConnectorOps`、按什么条件验收、收尾对临时 `BugDoc` 做「标记失效（`invalidate`）/ 删除（`delete`）/ 保留不删除（`keep`）」乃至直接增删这条收尾动作，全部在 **Workflow 文档 + Scheme Adapter** 中声明，由解释器按声明执行。
2. **两条入口汇聚于同一套标准主干**：

| 入口 | 起点节点 | 流转路径 |
|---|---|---|
| **入口 1：运行期日志/Bug/巡检事件**（`BugReport` / `MetricThreshold` / `ExternalChanged` / `ReconcileTick` / 定时日志收集） | 节点 1 `log-event`（`Idle`） | `1. 监听日志与 Event`（含过滤与 `ConnectorOps` 收集）→ `2. Agent 判断`（是否值得修复、可产出方案/临时 `BugDoc`）→ `3. 审批/自动审批`（`human \| agent \| auto`）→ `4. Doc Apply` → `5. developer-system` → `6. 验收`（可自由增删验收条件）→ `7. deploy-system`（→ `8. Reporting` 按可增删的 `postActions` 执行 `BugDoc` 标记失效/删除/保留不删 + 状态回归） |
| **入口 2：用户对话或控制台修改文档**（触发 `DocApplied`） | 节点 4 `doc-apply`（`Planning`） | 直接从 `4. Doc Apply` 切入（跳过前 3 步）→ `5. developer-system` → `6. 验收` → `7. deploy-system`（→ `8. Reporting` 按 `postActions` 回归） |

- 原 `bug-lifecycle`、`dev-delivery`、`core-workflow` 等历史名称仅在 `core/scheme.yaml` 的 `runtime.workflows.aliases` 中做 Scheme Adapter 兼容映射，默认注册表与列表不再保留冗余内置 workflow。
- 当业务上针对特定服务（如 `bi-system`）新增监控修 Bug 发版 workflow 时，同样由解释器执行该服务的 Workflow 文档配置（绑定 `bi-system`、配置日志过滤与收集 `ConnectorOps`、配置 Agent 判断与自动审批、绑定 `developer-system` 与 `deploy-system`、按需增删 `BugDoc` 失效/删除动作）。

## 9b. Workflow 模板与依赖系统逐层询问（2026-11-27 更新）

- Workflow 模板=**Template 概念在 workflow 层的应用**（`appliesTo: workflow`）：基于 `core-system-developer-loop` 标准主干提供可实例化的业务模具（如跨服务 Bug 监控修复发版模具）。
- 实例化或在新项目（如 `业务实例`）启用 `core-system-developer-loop` 时，首先 `requires/select` 对应的 `developer-system` 与 `deploy-system`，按 Template `resolver -> asks` 一层层问下去（**默认 `default` / 安装 `install` / 导入 `import`**）。

## 9c. 平台级声明 workflow：`gh-issue-trigger` 与 `agent-release`（2026-11-27 用户裁决；同日裁定 triage 更名 trigger——语义=触发修复闭环非仅整理）

> 用户原话要点：「core_agent 的 workflow 可以添加一个 gh_issue_event，即定时整理 github_issue，然后 agent 判断，然后自动更新文档→更新发版→github release（build 到时候做成使用 gh）。其中按规则，使用 github 的就 gh 创建 gh connector 的代码，放定义和代码。然后再加一个 workflow，用来更新代码编译后更新业务 agent。业务 agent 在未来自己的运行的时候报错，默认就开始走 github 提 issue。」

这两条 workflow=**声明层配置对象**（非 builtin 代码；解释器按文档执行，主干词汇与 core-system-developer-loop 同族）：

### 9c.1 `gh-issue-trigger`（GitHub Issue 触发 → 判断 → 文档更新 → 发版 → issue 回评闭环；2026-11-27 用户指令加第 9 节点 issue-feedback=connectops issue-comment）

```
入口 1：定时（timer 每 1h 整理）｜入口 2：GhIssueEvent（connectops-gh watch 桥自产，新开/重开 Issue）
 ① gh-issue-fetch (Idle：connectops-gh issue-list 拉取未整理 Issue——cli 模式走 gh CLI)
  ↓
 ② agent-judge (Analyzing：Agent 按 globalRuleRefs 判断 Issue 类型——bug/文档缺口/需求/噪声；产修复方案)
  ↓
 ③ approval-gate (AwaitingApproval：默认 agent 自动判断审批，human 可切)
  ↓
 ④ doc-apply (Planning：结论落临时 BugDoc/文档修订草稿)
  ↓
 ⑤ developer-system (Executing：文档更新/代码修复走 developer-system；build 用 gh workflow-dispatch)
  ↓
 ⑥ verify (Verifying：CI 绿 + 规则审核)
  ↓
 ⑦ gh-release (Deploying：connectops-gh release-create 发 github release)
  ↓
 ⑧ report-archive (Reporting：回评 Issue + 收尾 postActions——临时 BugDoc 默认 invalidate 可改 delete/keep)
```

- 绑定 `ConnectorOps/global/connectops-gh`（`mode: cli`——core_agent 默认 cli；部署侧同名对象声明 `mode: http` 走 GitHub REST），代码与定义同仓 `connectops-gh`（connector.md 规则 12）。
- 业务 agent 运行报错默认走 github 提 issue：其运行面把错误经 `connectops-gh` 提交 Issue（`issue-comment/issue-create` 语义），自动回流本 workflow 入口 2。

### 9c.2 `agent-release`（代码编译后更新 业务侧 agent）

```
入口 1：DocApplied（业务 agent 相关代码合并/构建完成）
  ↓
 ① build-check (Idle：connectops-gh 检查构建产物 digest——build 走 gh)
  ↓
 ② release-judge (Analyzing：Agent 判断影响面与升级窗口)
  ↓
 ③ approval-gate (AwaitingApproval：默认 agent 自动；prod 类升级可切 human)
  ↓
 ④ plan (Planning：升级批次与回滚预案声明)
  ↓
 ⑤ build (Executing：编译+产物 digest 入账)
  ↓
 ⑥ verify (Verifying：冒烟探针+规则审核)
  ↓
 ⑦ rollout (Deploying：connectops-deploy mode=http 推 部署侧 k8s 滚动更新)
  ↓
 ⑧ report-archive (Reporting：归档+github release 同步)
```

- 与 `gh-issue-trigger` 共用 `connectops-gh`；发布通道走 `connectops-deploy`（部署侧 k8s 侧默认 http 模式）——同一 workflow 文档在不同部署改 `systemBindings`/`mode` 配置即可换通道，零代码分支。

**声明要点（解释器配置面）**：两条 workflow 的 YAML 权威形态存 `core_system_instance/examples/workflows/`（`gh-issue-trigger.yaml`、`agent-release.yaml`），实例化=apply 到 docsRoot；全部为文档配置，不含任何 builtin 代码。
**现状勘误（2026-11-27 提交文档更新）**：①运行时 BugDoc 对象当前借 `kind: Agent`+`docType: BugDoc` 落库（如 `Agent/global/bug-workflow-agent-502-20261127`）——scheme 未注册 `BugDoc` kind，属过渡载体，待 scheme 注册 BugDoc kind 后迁正；②`gh-issue-trigger` 权威 YAML 的 doc-apply/report-archive 节点已随执行单元三型把旧 `unit: session` 词形退役为 `agent`（2026-11-27 用户指令顺手修正）。

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
