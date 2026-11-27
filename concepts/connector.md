# ConnectorOps — 工具调用面（挂载使用）

| 项 | 值 |
|---|---|
| K8s 对照 | 已装好的命令行入口（工具的使用点） |
| 形态 | `global|systems/<s>/…/connector-ops/<name>.yaml` |
| 作用域 | Global / System / Instance |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. 定义

ConnectorOps 是**直接的工具调用方式/提供的功能**：把某个 WorkService 的工具挂到某处（全局/系统/实例）供 Agent 调用。**Agent 默认挂 ConnectorOps**；使用要权限（role 并集，P7）。

类型/代码绑定/下载地/llmPrompt 等**描述性内容全部在 WorkService**（六面体的 connector 面与 tools 面，concepts/workservice.md）；Ops 只负责"这一份挂载"：指向哪个 WorkService、配什么环境、暴露哪些 op、绑什么 Workflow。

## 2. 边界

**是**：挂载使用面（workserviceRef + 环境 + op 子集 + Workflow 绑定）。每个 ServiceInstance 可以自实现自己的 Ops（就近遮蔽）。

**不是**：不是类型注册（在 WorkService.connector 面）；不是工具描述（在 WorkService.tools 面）；不做业务判断；无复杂生命周期（就是绑定）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: ConnectorOps
metadata:
 name: onedev-ci
 scope: builtin-developer-system/local-ci
spec:
 workservice: onedev # ：指向 WorkService（原 provider 字段）
 workflow: default-task # 相位约束（缺省）
 trustLevel: trusted # 内部默认 trusted；外部系统显式设 external（或继承 auth.provider 的 trustLevel）
 config: {endpointRef: ref/onedev-endpoint} # 逻辑声明
 auth: {provider: provider/onedev-robot} # 账号走 Provider
 ops: [checkout, build-status, gate-status, verify] # 提供的功能子集
---
# 通知类 Ops（default user-system 的 Event 默认通知挂载面，event.md 规则 7）：
apiVersion: core/v1
kind: ConnectorOps
metadata:
 name: notify-send-email
 scope: global # default user-system 全局挂载（通知通道不属单一系统）
spec:
 workservice: notify # 通知 WorkService（实现=common_connector notify OpsConnector，契约=connectors 包 OpsConnector 五方法）
 workflow: default-task
 config: {} # 收件人清单在 Provider 配置面（provider/email-notify 的 config.to）
 auth: {provider: provider/email-notify} # 账号走 Provider（secret 引用式取值）
 ops: [notify, send-email] # ⊆ notify WorkService.tools（Lint）
```

## 4. 生命周期

极简（ 不变）：绑定 → 使用 → 删除。无探活/drift/finalizer 概念级机制。

## 5. 与其他概念的关系

- 上游：WorkService（描述来源）；Provider（账号）；Workflow（相位）。
- 下游：Agent.connectorOps、TaskScheme.steps.connector 都引用 Ops。
- Skill（concepts/skill.md）：Ops 的使用处缓存为 skill。

- **Workflow 默认绑定**：每条 workflow 缺省绑定同名 ConnectorOps（`spec.connector` 可覆写）；ConnectorOps 是 workflow 节点的**流转实现面**——内部可调用 Service 操作、唤醒 Agent、嵌套其他 ConnectorOps；apply 时由 apply-workflow agent 开始写实现（代码化，非运行时即兴）；引擎只管相位/刹车/记账。

## 6. 设计规则

1. workservice 必填且必须已在册（六面体至少 connector 或 tools 非空）。
2. ops 子集 ⊆ WorkService.tools 声明的 op 集（Lint）。
3. 使用要权限（role 并集+权限系统，P7/）。
4. **回滚类型、策略与文档描述（2026-11-26 用户裁决）**：`rollback.type: irreversible`（或 `undo: none`，根本没办法回滚）的工具（在 `WorkService.tools` 里声明）每次调用人审；需要回滚的工具必须按 `rollback: {policy: never|auto|ask|optional, type: irreversible|code|agent|human, description, docRef?}` 区分**要不要回滚**、**代码回滚 / Agent 回滚 / 人回滚**，并附带清晰的回滚文档描述（见 `workservice.md` 规则 8、`task-scheme.md` 规则 8）。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

6. **ConnectorOps=节点流转实现面（不是触发器）**：触发/相位/刹车/记账归 Workflow 引擎；节点内容与节点间流转归绑定的 ConnectorOps（Service 调用/Agent 唤醒/嵌套其他 ConnectorOps）。命名约定：缺省=`<workflow 名>` 同名；空绑定或未实现 → 决策面 `execution=unbound` 可见（缺口不静默）。

7. **代码归属与生命周期（R-ENG-3）**：ConnectorOps 的代码一律归 **deploy-system** 管理的 git 仓库，按小概念命名 `connectops-<concept>`（如 connectops-chrome/connectops-dsh/connectops-opencode/connectops-gh）；生命周期=声明（docs）→ 仓库代码 → **build 生效** → 运行时；**每次变更必定提交**（override 亦同），不存在运行时改代码；未 build 生效=运行态不可引用（`execution=unbound` 可见）。

8. **`connectops-context`（上下文索引/亲和/失效/预热）**：上下文检索的代码承载能力归 deploy-system 的 `connectops-context` 仓（R-ENG-3 同款生命周期：声明 → 代码 → build 生效 → 运行时；每次变更必提交）。op 集：`index`（增量/全量构建 DocIndex）、`affinity`（tag 亲和矩阵重算，定时）、`invalidate`（文档变更主动失效 chunk/pack 缓存）、`prewarm`（L0/L1 常驻摘要预热）、`evaluate`（命中率回归，只出因子建议不自动应用）。调度两入口同一代码路径：cored 内建调度（旗标缺省关断）或部署侧 timer 调 CLI；因子与预算来自 ContextPolicy 对象（apply 生效），不硬编码。

9. **`connectops-code-audit`（代码级规则审核）**：`mode: code` 的规则统一由该 ConnectorOps 实现审核（R-TYPE-3）：Rule 条目 → scheme `runtime.ruleChecks`（ruleId→checker/参数/severity）→ `connectops-code-audit` 仓（deploy-system，R-ENG-3 生命周期）执行。op 集：`check`（按 ruleId/targets 审核仓库/工作树，返回 findings：ruleId/file/line/severity/message/evidence{ref,hash}）、`verify`（check+汇总，产 VerifyDoc 片段）。只读、幂等、不提交、不 Apply；未注册/未实现的 code 规则=unbound error，不得静默跳过。findings 进 VerifyDoc/DriftReport/Report，`error` 阻断 Deploy；`warn` 记录。`mode: agent` 的规则不走本实现——由 Verify 节点把规则原文（ref+hash）+ diff 丢给 agent 验证（见 rule-verification.md）。

10. **内部默认可信与外部系统 `trustLevel` 字段（2026-11-26 用户裁决）**：默认内部系统都是可信的（`spec.trustLevel: trusted` 缺省，未显式声明时继承 `auth.provider` 的 `trustLevel`）；对接外部不可控系统的 ConnectorOps 添加 `spec.trustLevel: external`。当 Workflow 调用 `trustLevel: external` 的 ConnectorOps 获取外部内容时，按 **Workflow 级别可配置的 `trustGate`（`mode: code | agent`）** 由代码或 Agent 判断一遍内容是否 OK 后再放行。

11. **Ops 双通道：cli 与 http（2026-11-27 用户裁决）**：一切 Ops（ConnectorOps/WorkService.tools）默认**同时支持 cli 与 http 两种调用模式**（`spec.mode: cli | http | both`，缺省 `both`——同一 op 语义、同一实现、两个传输通道）：
    - **cli 模式**：经本机命令行工具调用（`gh`、`dsh`、`kubectl`、`ldap-utils`…）；core_agent 默认走 cli；
    - **http 模式**：经 web/REST（`http_ai`、GitHub API、LDAP REST 网关、k8s API…）调用；部署侧后续交给 k8s 系统承载，默认走 http；
    - 实现侧=同一 op 分派器 + 两个 transport（cliTransport / httpTransport），声明面只改 `mode` 一个值即切通道，**零代码耦合**（进程间有很多玩法：同机 cli、跨机 http、网格 sidecar 均 由配置决定）。

12. **builtin 与外部仓分界（R-ENG-3 落地口径，2026-11-27 用户裁决）**：在 core 核心中**随引擎编译**的驱动=core 核心代码的一部分（`core_system_workservice/connectors/`：gitfs/dsh/codeaudit——这就是 builtin 的特殊性）；**其余一律 gh 建仓** `connectops-<concept>`（如 `connectops-gh`），**定义（WorkService/ConnectorOps YAML 对象）与实现代码同仓**放置（`objects/` 目录=声明、`<pkg>/`=代码），生命周期=声明 → 仓库代码 → build 生效 → 运行时；使用 github 能力的就 gh 创建 `connectops-gh`（issue 整理、release 发版、workflow dispatch 全走 gh）。

13. **builtin 契约的外部接入=用 ops 实现（2026-11-27 用户裁决，concepts/interface.md）**：builtin 系统创建 Interface 契约（`systems/builtin/<s>/interfaces/`，scheme 版本化）；core_system 调用 builtin 直接调接口（进程内）；以后接入 ldap/其他，**只需用 ops 实现该契约**（ConnectorOps/WorkService.tools 的 ops 集 ⊇ 契约 op 集）+ 一条 `provides` 标注（`impl: ops`）。**系统间相互直接 ServiceWork 调用是系统间自己的事情，跟本项目无关**——相应接口授权文档在各自系统仓内写清楚，本项目不做约定不纳管。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| Ops 与 WorkService.tools 描述漂移 | ⚠️ 低 | 工具变更后子集悬空 | 规则 2 Lint + WorkService 变更触发相关 Workflow 对账 |

**结论：可行。职责比 更薄（描述全在 WorkService），风险更小。**

## 8. 待决问题

见 open-questions.md#connector

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
