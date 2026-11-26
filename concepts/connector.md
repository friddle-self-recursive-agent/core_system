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
4. `undo: none` 的工具（WorkService.tools 里声明）每次调用人审。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

6. **ConnectorOps=节点流转实现面（不是触发器）**：触发/相位/刹车/记账归 Workflow 引擎；节点内容与节点间流转归绑定的 ConnectorOps（Service 调用/Agent 唤醒/嵌套其他 ConnectorOps）。命名约定：缺省=`<workflow 名>` 同名；空绑定或未实现 → 决策面 `execution=unbound` 可见（缺口不静默）。

7. **代码归属与生命周期（R-ENG-3）**：ConnectorOps 的代码一律归 **deploy-system** 管理的 git 仓库，按小概念命名 `connectops-<concept>`（如 connectops-chrome/connectops-dsh/connectops-opencode/connectops-gh）；生命周期=声明（docs）→ 仓库代码 → **build 生效** → 运行时；**每次变更必定提交**（override 亦同），不存在运行时改代码；未 build 生效=运行态不可引用（`execution=unbound` 可见）。

8. **`connectops-context`（上下文索引/亲和/失效/预热）**：上下文检索的代码承载能力归 deploy-system 的 `connectops-context` 仓（R-ENG-3 同款生命周期：声明 → 代码 → build 生效 → 运行时；每次变更必提交）。op 集：`index`（增量/全量构建 DocIndex）、`affinity`（tag 亲和矩阵重算，定时）、`invalidate`（文档变更主动失效 chunk/pack 缓存）、`prewarm`（L0/L1 常驻摘要预热）、`evaluate`（命中率回归，只出因子建议不自动应用）。调度两入口同一代码路径：cored 内建调度（旗标缺省关断）或部署侧 timer 调 CLI；因子与预算来自 ContextPolicy 对象（apply 生效），不硬编码。

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
