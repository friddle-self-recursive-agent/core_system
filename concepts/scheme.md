# Scheme — 类型注册表与细粒度方面（Aspect）

| 项 | 值 |
|---|---|
| K8s 对照 | client-go scheme + CRD 注册机制 |
| 形态 | 按 `aspect: <xxx>` 细粒度拆分的单文件单 Scheme 文档（根入口 `core/scheme.yaml` + 分册 `core/schemes/scheme_<aspect>.yaml`）+ Core 内存索引 |
| 作用域 | Builtin / System |
| 状态 | 定稿（终态制，rule/rule.md；**2026-11-26 用户裁决：① Scheme 按 `aspect: <xxx>` 拆得更细更多方面；② 禁止多 Scheme 在一个文件（除非导入 Scheme，自己保存的权威文件严禁多 Scheme 合一）；③ 改已支持 Scheme 的值与行为描述免改代码，若 Scheme 值不支持或 Scheme 契约改动则必须触发相应代码改动**） |

## 1. 定义

Scheme 是所有"可存在之物"的类型与契约注册表：**对象类型**（Agent、ServiceDesc、Connector…）、**文档类型**（Goal、Rule、Metrics…，见 DocType）、**事件类型**、**事件路由表**以及各方面的运行与上下文约定。未注册的类型，Core 拒绝存储、Event 拒绝路由、Agent 拒绝引用——这是防止文档面腐化的第一道闸门。

**按 `aspect: <xxx>` 细粒度拆分（一文件一 Scheme）**：
为了避免所有概念挤在单一巨型文件里、并让「只改某个方面的值 vs 改某个方面的代码契约」边界清晰，Scheme 支持通过 `spec.aspect` 拆分为细粒度方面（如 `aspect: root` / `aspect: kinds` / `aspect: docTypes` / `aspect: eventTypes` / `aspect: dispatch` / `aspect: runtime` / `aspect: context` / `aspect: permission` 等）：

```yaml
# core/scheme.yaml（根入口，一文件一 Scheme）
apiVersion: core/v1
kind: Scheme
metadata:
 name: default
 scope: builtin
spec:
 version: core/v1
 aspect: root # 方面标识：root | kinds | docTypes | eventTypes | dispatch | runtime | context | ...
 imports: [] # 可选：引用按 aspect 拆分的独立单 Scheme 文件（core/schemes/scheme_<aspect>.yaml）
 kinds:
 - {kind: Agent, storage: global/agents/<name>/agent.yaml}
 - {kind: ServiceDesc, storage: systems/<name>/system.yaml}
 - {kind: ServiceInstance,storage: systems/<s>/instances/<name>/instance.yaml}
 - {kind: WorkService, storage: global/workservices/<name>/workservice.yaml}
 - {kind: ConnectorOps, storage: "…/connector-ops/<name>.yaml"}
 - {kind: Workflow, storage: "global/workflows/<name>.yaml | systems/<s>/workflows/<name>.yaml"}
 - {kind: Role, storage: global/roles/<name>.yaml}
 - {kind: Ref, storage: global/refs/<name>.yaml}
 docTypes: # 引用 doctypes/README.md 的注册表
 - Goal / Desc / Rule / WorkflowDesign / Metrics / DataDesign /
 DataMetrics / Auth / DeployDesign / CodeDesign /
 ImplDoc / VerifyDoc / DriftReport
 eventTypes:
 - {type: ExternalChanged, source: connector, route: owner-instance-workflow}
 - {type: MetricThreshold, source: metrics, route: owner-instance-workflow}
 - {type: DocApplied, source: core, route: owner-workflow}
 - {type: ApprovalNeeded, source: permission, route: notification/*}
 - {type: HeartbeatLost, source: core, route: parent-agent}
 dispatch: # “dsh”：事件如何找到处理者
 - {on: ExternalChanged, for: workservice/gitlab, dispatch: instances/*/workflows/*}
```

## 2. 边界

**是**：数据 + 索引。Core 启动时载入内存，变更走 Apply。

**不是**：
- 不是 Core 进程；
- 不校验内容（校验是 权限系统 按 Scheme 注册的 schema 做，Scheme 只登记 schema 引用）；
- 不产生 Event（只在 Event 已发生后查表路由）。

## 3. 生命周期

bootstrap 时由 builtinRoot 写入首版 → 之后只能**追加与扩容**（加新类型、加可选字段），破坏性变更需新版本号 `core/v2` 并保留 v1 兼容期（与 CRD 版本策略一致）。Scheme 自身修改属 Builtin 级准入（默认人审）。

## 4. 与其他概念的关系

- DocType 是 Scheme 里 `docTypes` 段的展开定义（DocType=CRD，Scheme=注册中心）。
- Event 产生后由 Core 按 Scheme.dispatch 路由。
- Core 启动自检：文档库中所有对象的 GVK 必须能在 Scheme 命中，否则启动失败（防野对象）。

## 5. 设计规则

1. 一类一注册：同一种能力出现两个未合并的注册项即违宪（P10）。
2. 存储路径写进注册项（对象落在哪个目录由 Scheme 决定，instance 仓 layout.md 与之对齐）。
3. 类型演进只加不改：删字段、改语义必须升版本。
4. dispatch 表必须穷举事件类型的缺省路由；路由不到的事件进死信（DeadLetter）并告警，不允许静默丢弃。
5. **路由表达必须支持相等/集合之外的谓词**：exists / notIn / 前缀 / 正则等（v1 至少相等+集合+notIn+exists；语法随 Scheme 演进）——只有相等/集合不够用。
6. **spec 声明机读语义（准入 checker 的判读口径，R-TYPE 有规则即有 checker）**：`!` 前缀或 decl 后缀 `!` =必填（含子字段，先例 `system: ref!`）；`?` =可选；无标注=不强制必填但**出现即校验形状**（类型/枚举/嵌套结构）；`a|b` =枚举（含 `<占位>` 的段=通配段恒命中；`…` 段=开放式标记剥离后照判；含空白/`=`/冒号的段=散文整体不判）；`[]X`/`{…}` 递归；声明值可为带引号字符串或真实嵌套映射（WorkService 各描述面）。未知字段放行（规则 3 只增不改的准入侧镜像）；不可解析文档由存储层管辖。checker=workservice `scheme.ValidateDoc`，应用点①=apply 引擎准入第三步（kind 注册→权限→spec 结构；cored-bridge.md §2.1）——坏对象从授权面兜底升为写入口拦截。**应用点②=存量面净入 lint（v0.48，docsRoot 净入五闸）**：checker 只挡写入口=存量对象（checker 生效前落库/经旁路落库）零校验放行——读面 globObjects 对不可解析文档静默跳过（存量坏对象在 List 读面不可见）、存量形态违规对象读面放行一编辑即 400 且按原文无法复原（读面宽松/写面严格双严格度劈叉）。净入 lint=workservice `cmd/cored-lint`（`internal/repository.LintGitDocs`）：docsRoot 全 yaml 文件系统通配（不经 List 读面），逐文件五闸与写路径同清单——路径注册（storage 模板通配命中恰一 kind，零命中=野对象/多命中=歧义）、可解析（读面静默丢弃面补检出）、身份一致（metadata.name/scope vs 文件名与路径派生 scope；nameSeg 写面同闸）、spec 准入（`ValidateDoc` 同闸门）、凭据来源形态（Provider 写面同闸）+scheme 镜像漂移闸（docsRoot `core/scheme.yaml` 消费方镜像 vs 载入权威字节比对——双源系漂移零检出缺口收口）。wrapper=`lint/docsroot-admission.sh`（R-TYPE-2 双向可追溯）。lint 纯只读零写面。
7. **按 `aspect: <xxx>` 细粒度拆分与单文件单 Scheme 铁律（R-DOC-8，2026-11-26 用户裁决）**：
   - Scheme 与 TaskScheme 可按 `spec.aspect` 拆分为更细的方面（如 `aspect: kinds` / `docTypes` / `eventTypes` / `dispatch` / `runtime` / `context` / `build` / `verify` / `reconcile` 等），每个方面独立打 Tag 入索引；
   - **禁止多 Scheme 在一个文件（自己保存的权威文件）**：系统自身保存的任何 `.yaml` 文件严格只允许包含**一个** Scheme / TaskScheme 对象（禁止单文件内 `---` 多文档拼接或多个 Scheme 合一，checker=`lint/single-scheme.sh`）；
   - **导入例外**：仅在从外部导入（`import`）时允许输入包含多 Scheme 的聚合文件，但**导入落库/保存时必须自动拆分为单文件单 Scheme**。
8. **改 Scheme 值免改代码 vs 改 Scheme 契约必触发代码改动（R-ENG-4，2026-11-26 用户裁决）**：
   - **免改代码（声明即生效）**：若既有代码驱动与 Scheme 契约已支持，仅修改 **Scheme 的值或行为描述**（如调整路由表值、阈值、参数、在 TaskScheme 中组合已注册的 ConnectorOps 步骤），Apply 落库即刻生效，**不触发**任何代码编译或建仓；
   - **必触发代码改动**：若所需的**Scheme 值不被现有代码支持**（如新增未实现的驱动 op / 新枚举行为），或**修改/扩充了 Scheme 的结构契约本身（`scheme 改动`）**，控制面必须将该缺口标为 `execution=unbound / scheme-contract-changed`，并**自动触发对应的代码改动流程**（在 `workservice` 或对应 `connectops-<concept>` 仓生成代码变更、build 生效并提交）。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

## 6. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 事件路由表随规模膨胀 | ⚠️ 低 | 系统×事件类型组合多 | 缺省路由 + 按 类型/involved/owner/scope 直达（dispatch 表），不逐系统枚举 |
| 版本演进复杂度 | ⚠️ 中 | 文档类型改版牵连所有存量文档 | 只加不改策略 + 存量兼容期 + 迁移由 Workflow 执行 |
| dsh 语义误解 | ⚠️ 低 | 原稿 dsh 若另有所指需重定义 | 已并入 dispatch；待用户裁决 |

**结论：可行，成熟模式（CRD 注册的翻版）。**

## 7. 待决问题

见 open-questions.md#scheme

## 8. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
