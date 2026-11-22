# TaskScheme — 四层执行模型（意图→Agent→Scheme→代码）

| 项 | 值 |
|---|---|
| K8s 对照 | Job/CronJob spec（确定性步骤）——"长运行不依赖即兴"的 K8s 答案 |
| 形态 | 对象（systems/<s>/schemes/<name>.yaml），builtin Scheme 之一 |
| 作用域 | System 或 Instance |
| 状态 | 定稿（终态制，rule.md） |

## 1. 定义

默认执行层级四层：**用户意图 → Agent → Scheme → 代码**。

```
意图层（Goal/命令/Event） ：要说清"要什么"（文档）
Agent 层 ：理解意图、路由到 Scheme、处理异常与升级（LLM 只在这层）
Scheme 层（TaskScheme） ：确定性步骤图：触发→步骤→失败策略（声明式、可审）
代码层（Connector/Plugin) ：幂等执行（get/plan/apply/verify/undo）
```

核心动机：**长时间运行系统肯定不能依赖 Agent 即兴**。Agent 可以"自定义 Scheme"（写一份 TaskScheme 文档经 Apply 入库），但执行永远走已入库的 Scheme 步骤 + 基础调度（常见任务的可配置调度模板），不走 Agent 即兴发挥。收敛性风险从运行时移到评审时（Scheme 入库过权限系统）。

## 2. 边界

**是**：任务级确定性执行图；Instance 可自定义（走 Apply 注册）；常见任务有 builtin 模板库（build/verify/report/sync 等，可配置参数）。

**不是**：
- 不是 workflow 引擎（无 if-else 业务编排、无人写的脚本；失败策略只有 retry/escalate/rollback）；
- 不是 Workflow（Workflow 是对账节拍；TaskScheme 是单任务执行图；Workflow 派发的任务落到 TaskScheme 执行）；
- 不是 Agent 的替代（无 Scheme 可路由时，Agent 兜底+提案新 Scheme——兜底动作全程 DriftReport 留痕）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: TaskScheme
metadata:
 name: build-and-verify
 scope: builtin-developer-system/local-ci
spec:
 trigger: {events: [ExternalChanged], match: {source: onedev, type: push}}
 steps:
 - {id: checkout, connector: onedev-driver, op: checkout, args: {ref: "{{.branch}}"}}
 - {id: build, connector: dsh, op: exec, args: {host: local, cmd: "./gradlew build"}}
 - {id: gate, connector: dsh, op: exec, args: {cmd: "./gradlew lint test"}}
 - {id: artifact, connector: oss-driver, op: put, args: {from: build/libs, digest: true}}
 - {id: report, connector: onedev-driver, op: build-status}
 params: [branch] # 可配置（基础调度=模板+参数）
 onFailure: {retry: 2, backoff: 30s, then: escalate}
 budget: {minutes: 20}
```

## 4. 与其他概念的关系

- Workflow 的 Dispatch → Agent 选 Scheme（按 trigger 匹配）→ 代码层执行 → Verify → Status 回写。四层嵌在 core-workflow 管线的 Plan/Execute 相位。
- Scheme（类型注册）注册 TaskScheme 这个 Kind；TaskScheme 是"声明层的执行面"（ 双义统一）。
- **Workflow 分工**：Workflow 管相位（Executing 段），TaskScheme 管 Executing 段内的步骤图——步骤总在某 Workflow 的 Executing 相位内跑。
- builtin 模板库：`global/templates/task/`（build/verify/sync/report/install 等），Instance 引用+参数化，避免每系统重写。**模板库四操作**（全部走 Apply+权限系统）：
  - **用**：引用模板+参数（不改模板本体）。
  - **调**：builtin 内部模板固定起源（不可删），但可**调整**——fork 出副本改 spec（Scheme 方式描述：参数、步骤、**提示词**=各生成相位的 LLM 注入段），副本归自己 scope 管理。
  - **import**：从**现有系统导入**任务编排（既有 CI 流水线/运维脚本描述）渲染成 TaskScheme spec 入库——把存量资产纳入模板库，是最重要的扩充通道；导入预览=dry-run，导入件首期 observe。
  - **delete**：删除自建/导入副本（引用计数>0 拒绝；builtin 起源不可删）。

## 5. 设计规则

1. 步骤只能引用已注册 ConnectorOps 的 op（步骤 connector 字段指 ops 名）——无自由 shell（dsh 的 exec 也是一个 op，参数受白名单）。
2. 每个步骤幂等；整图可重入（断点=已完成步骤集）。
3. budget 必填；超预算=本轮失败走 onFailure。
4. 新 Scheme 入库过权限系统（高危 op 如 exec 人审）。
5. 模板元数据带 `origin`（builtin/adjusted/imported）与生成相位提示词（prompt 段）——提示词是模板的一部分，随模板版本管理。
6. 模板四操作（用/调/import/delete）都过权限系统；builtin 起源模板只读，调整必产生副本。
- 终态制：本文档只展示最终结果，变更历史只在 annotations.md（[rule.md](../rule.md) R-DOC-1/3）。

## 6. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 模板参数化表达力不足 | ⚠️ 中 | 真实构建千差万别 | 参数+覆盖段（overlay）；不够就 fork 调整副本或写新 Scheme（这正是设计意图：显式而非即兴） |
| import 渲染失真 | ⚠️ 中 | 存量编排语义≠确定性步骤图 | 导入预览=dry-run 展示渲染结果；origin=imported 首期 observe 模式 |
| 副本膨胀 | ⚠️ 低 | 人人 fork 模板失控 | 引用计数+定期对账（无引用副本提示清理） |
| Agent 兜底边界模糊 | ⚠️ 中 | 何时允许 Agent 不走 Scheme | 规则 3 兜底必须 DriftReport 留痕+人工可回看；连续同类兜底 N 次→必须提案 Scheme |
| 步骤间数据传递 | ⚠️ 低 | artifact 路径等 | v1 用本地工作目录+digest 引用，不做数据总线 |

**结论：可行。这是把"LLM 收敛不可保证"（H1）关进笼子的关键机制——确定性下沉，智能上浮。**

## 7. 待决问题

见 open-questions.md#task-scheme

## 8. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
