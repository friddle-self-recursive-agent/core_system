# 文档类型注册表（内置首批）

> 机制见 [concepts/doctype.md](../concepts/doctype.md)。本表是首批内置 DocType 的登记与治理属性。
> 强制级别：**required**（不齐不许建系统）/ **default**（默认建议，缺了 Policy 警告）/ **optional**。
> 原稿清单的变更已按 A1–A4 处理，见文末对照。

## 1. 声明侧（ServiceDesc 下）

| 类型 | 强制(global) | 必填段 | 写者 | 说明 |
|---|---|---|---|---|
| `Goal` | required | intent / acceptance | 人 | 系统必须干什么。**acceptance 必须可验证**（Verifying 的判据） |
| `Desc` | required | overview / boundaries | 人 | 系统是什么、不是什么（概念边界的文档化） |
| `Rule` | default | rules[] | 人/owner | 约束（"必须每天备份"）。每条 Rule 建议带 ruleId，供 Status.RulesHeld 引用 |
| `WorkflowDesign` | optional | flows[] | 人 | **给人看的功能流设计**（原稿 Workflow Desion，A2 改拼写）。不是可执行编排 |
| `Metrics` | default | indicators[] / thresholds[] | 人 | 监控设计（A1：吸收原稿 Prometheus 类型）。系统行为/健康指标与阈值 |
| `DataDesign` | optional | entities[] / flows[] | 人 | 数据设计：实体、从哪到哪、什么权限 |
| `DataMetrics` | optional | flows[] / slo[] | 人 | 数据流监控设计（A4：延迟/丢数/血缘），区别于系统健康 |
| `Auth` | default（Builtin: required） | subjects[] / grants[] | 人（人审） | 授权设计：谁可干什么（设计层；钥匙见 Credential） |
| `DeployDesign` | optional | envs[] / rollout | 人 | 部署设计 |
| `CodeDesign` | optional | modules[] | 人 | 代码结构设计 |

## 2. 实现侧（ServiceInstance 下）

| 类型 | 强制(instance) | 必填段 | 写者 | 说明 |
|---|---|---|---|---|
| `ImplDoc` | required | how / mapping | Agent（随实现生成） | "我怎么实现这些功能的"（原稿 DOCS 前半）：声明→实现对照 |
| `VerifyDoc` | required | guarantees / probes | Agent/owner | "怎么进行约束保障的"（原稿 DOCS 后半）：验证手段、探针、兜底 |
| `DriftReport` | auto | drifts[] / actions[] | Loop 生成 | 每轮对账的差距与动作记录；也是下轮的压缩上下文 |
| `PlanDoc` | required | intent / steps / budget | Agent | v0.3（A29）：Agent 每次 PLAN 必须落档；含引用的 TaskScheme/Workflow |
| `SessionLog` | required | phases / docsLoaded / outcome | Agent/dsh 会话 | v0.3（A29）：每完成一次 Session 记录；态机可回放、上下文可审计 |
| `Runbook` | optional | — | 人 | 人肉处理手册（Escalate 后人看的东西） |

## 3. 必带级别归属（v0.5，A37：与 Builtin 无关）

三档（required / default / optional）由两层声明，**是 Scheme 与 Service 自己强调的事情**：

| 层 | 声明处 | 例子 |
|---|---|---|
| DocType 注册级（Scheme 层） | doctype 注册的 mandatory 字段 | Goal/Desc 全局 required；Rule 为 default |
| Service 自身声明级 | system.yaml 的 docs.required（只可加严） | developer-system 自要求 Auth 必带 |

Builtin 只是起源标记（core_system 自带开发，concepts/builtin.md v0.5），**不携带任何必带文档要求**；builtin 起源的对象同样适用上述两层。
（R0 原稿"Builtin 有默认/强制/可选文档类型"由 R4 修正覆盖，见 annotations A37。）

## 4. 全局对象文档（非 DocType，结构即 YAML）

Agent / Connector / WorkService / Ref / Bind / Credential / Loop / Policy / Scheme 的对象定义就是文档本身（结构化 YAML，见各概念文档 §3），不走散文 DocType。

## 5. 原稿 → 本表 对照

| 原稿类型 | 处置 | 依据 |
|---|---|---|
| Goal 必须 | 保留，加 acceptance 必填段 | — |
| Desc 必须 | 保留 | — |
| Rule | 保留，升 default | — |
| Workflow Desion | 改名 WorkflowDesign，定界"设计文档非编排" | A2 |
| Prometheus 监控设计 | **删除**，并入 Metrics；Prometheus→WorkService | A1 |
| Metrics 监控设计 | 保留为 Metrics | A1 |
| Auth 授权配置 | 保留；Builtin 下升强制 | — |
| DataDesign | 保留 | — |
| DataMetrics | 保留，边界定为"数据流" | A4 |
| DeployDesign / CodeDesign | 保留 | — |
| （原稿无） | 新增 ImplDoc / VerifyDoc / DriftReport / Runbook | Instance 侧需要类型注册才能管理 |
