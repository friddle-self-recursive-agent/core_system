# AttentionReport — 关注报告（读侧派生：值得关注 / 不值得关注 + 证据链）

| 项 | 值 |
|---|---|
| K8s 对照 | 无直接对应（≈ 告警摘要 + `kubectl get` 的人话归并） |
| 形态 | **派生视图，不是文档对象**：不注册 DocType、不进 git、无 revision；缓存落 ops DB `attention_report`（可丢弃可重建） |
| 作用域 | 按查看者权限裁剪；可全局（viewer 可读 scope 并集）或对象锚定（service / workflow / instance） |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. 定义

关注报告是 console 默认主界面的内容：用一段人话回答三个问题——**现在怎么样、什么值得你看、什么已经检查过且正常**。读者是人（业务/运营视角），不是指标墙。

固定三块：**状态 / 异常 / 重要提案与审批**；另加两块：**已检查且正常（clear）** 与 **数据可信度（as-of / 窗口 / 降级）**。

生成方式=**确定性候选 + LLM 叙述**：

- 候选由规则从事实源收集（ops DB / Status / DriftReport / run / event / 审批），严重度由映射表给定，可审计；
- LLM 只决定"哪些值得说、怎么说"，输出严格结构；**数字只能取自候选/服务端 facts（白名单校验，不得自造）**；每条必须引用候选与证据，编造条目丢弃。

## 2. 边界

**是**：读侧派生视图；人的注意力路由（先看报告 → 点条目进对话/对象/审批）；按权限裁剪后的视图（不同人看到的报告可以不同）。

**不是**：

- 不是文档对象（不 Apply、不进 git、无 revision、无 owner——它不是系统的声明）；
- 不是告警系统替代（Event / Metrics / Status 仍是事实源；报告只聚合与叙述）；
- 不是决策者（不批准、不执行、不改状态；动作全部回到既有入口）；
- 不是唯一视图（系统树 / 工作流 / 事件流 / 审批仍是钻取面，报告是入口不是终点）。

## 3. 结构

```yaml
# ops DB attention_report（派生记录；示例）
report:
  id: ar-20261126-001
  asOf: 2026-11-26T12:00:00+08:00
  window: {from: 2026-11-25T12:00:00+08:00, to: 2026-11-26T12:00:00+08:00}
  scope: {kind: global | service | workflow | instance, ref: "..."}  # 主界面=global；workflow 页=该 workflow
  viewer: {subject: user/root, scopes: [core_system, developer-system], permHash: sha256(...)}
  generatedBy: llm | rules                 # rules=降级
  generator: {version: 1, promptVersion: 1, model: "<PROVIDER 档位>"}  # 可复现记录
  dataQuality: {degraded: false, missing: [], stale: false}
  facts: {systems: 6, runs24h: 49, failures24h: 0, approvalsPending: 4, driftsOpen: 2}  # 服务端注入，LLM 不可写
  summary: "一句话判断（不含数字）"
  attention:
    - candidateId: c-001
      category: status | anomaly | proposal    # 三块：状态 / 异常 / 提案审批
      severity: critical | high | medium
      title: "developer-system 门禁连续 3 轮失败"
      why: "近 3 轮都在同一验证步骤失败，最近一次 12 分钟前；影响 dev-delivery 交付。"
      impact: "dev-delivery 交付停摆"          # 可选
      evidence:                               # ≥1 条；服务端从候选解析，LLM 不回填 URL
        - {kind: run, id: run-123, ref: "<repo>/<path>#<anchor>", hash: "...", at: "..."}
        - {kind: event, id: evt-456}
      action: {kind: chat | open | approve | proposal, target: "..."}
  clear:
    - candidateId: c-010
      note: "已检查：6 个系统的 generation 全部追平（gen 12/12）。"
```

字段纪律：`evidence` 至少一条且由服务端解析；`action` 指向既有路由/ops；`category` 固定三块，界面按块渲染，不做数字宫格；`facts` 与 LLM 文本物理分离。

## 4. 生命周期

1. **候选收集（确定性）**：从 ops DB / Status 取事实——run 终态、DriftReport、阈值越线、审批积压、Proposal、连接不可达、ctx stale、会话停滞（KI-003）、执行体未绑定等；每项带对象引用、时间窗、映射表给定的严重度。
2. **权限裁剪（生成前）**：按查看者可读 scope 过滤候选（审批数也只计可读范围）；报告缓存键含权限指纹，不同角色不共用一份。
3. **分级守卫**：critical / high 候选强制进 attention（LLM 不得静默降级）；审批与待决提案恒上屏；medium 可被 LLM 判为 clear 或提升；low 默认 clear。
4. **LLM 叙述**：summary / title / why / clear note；**数字必须命中候选/facts 白名单**（服务端逐条校验，越界即拒绝该条文本并回退模板）；输出严格 JSON，校验 candidateId 存在、evidence 可解析，未知条目丢弃并计入 `dataQuality`。
5. **排序与预算**：critical → high → medium；同级按影响面与新鲜度；attention 上限默认 7（**只截 medium**，critical / high 全显）并标注「还有 N 条」。
6. **缓存与失效**：键 = {window, scope, permHash, candidateDigest, generatorVersion}；TTL 默认 5m，stale-while-revalidate（先展示上一份+stale 标记，后台重算）；DocApplied / run 终态 / 审批 / 连接变化 → 候选指纹变 → 后台重算。
7. **降级**：LLM 超时/不可用/预算耗尽 → `generatedBy: rules` 的确定性报告（同结构、模板叙述、按严重度排序）；数据源缺失 → `degraded:true + missing`；陈旧 → `stale:true`。三态都必须界面可见。
8. **注意力反馈**：查看者的「忽略 24h / 这也要看 / 已处理」落 ops DB（按 viewer 存），只影响本人后续排序权重，不改事实与全局严重度。

## 5. 与其他概念的关系

- **Event / Status / DriftReport / run 流水**：事实源；报告不复制事实，只引用（ref/id/hash）。
- **Context**：生成时按 tag 装配系统/规则/文档摘要（R-CTX-8 底座）；条目开聊时把涉及对象 tag 带进会话 ctx（两段会话的第二段起点）。
- **Proposal / 审批**：报告三块之一；点开=既有审批入口；报告无批准权。
- **Workflow**：报告可作用域到某 workflow（workflow 页默认视图）；生成器可被既有 Workflow 定时预热（同一生成器，不是新引擎）。
- **Console**：主界面=报告×对话（rule/rule_ux.md R-UX-6）；条目落地=对象工作台（R-UX-7）。
- **Permission**：生成前裁剪；缓存按权限指纹隔离；报告不得成为越权读取通道。

## 6. 设计规则

1. **人话与判断优先**：报告以判断句为主；数字只做服务端注入的事实注脚，不做指标宫格。
2. **三块固定 + clear 必显**：状态 / 异常 / 提案审批；空块显式「本窗口无」+ 检查范围；无 clear 区=报告不合格（避免「沉默=没问题」）。
3. **每条必带证据**：≥1 个可点 ref/id；证据由服务端解析，LLM 不得编造；链接失效=条目降级并计入 `dataQuality`。
4. **候选确定、叙述 LLM 化**：严重度由映射表给定；critical / high 强制上屏、不得被 LLM 静默降级；审批与待决提案恒上屏。
5. **数字只能来自事实**：`facts` 由服务端聚合注入；LLM 文本中出现的数字必须在候选/facts 白名单内（服务端校验，越界拒绝/改写），不得自造。
6. **报告≠决策**：报告无 Apply / 批准 / 执行权；一切动作走既有权限与审批链。
7. **权限裁剪在生成前**：不得先全量生成再前端过滤；缓存键含权限指纹。
8. **三态显式**：`generatedBy:rules` / `degraded + missing` / `stale` —— 任一发生必须界面可见，不静默。
9. **注意力预算**：attention 上限（默认 7，只截 medium）、生成频率、token 预算可配；critical / high 不截断。
10. **派生纪律**：不注册 DocType、不入 git、无 revision；删除缓存可重建；生成参数（模型/提示/映射表版本）随报告记录。
11. **可复现**：同窗口 + 同候选指纹 + 同生成器版本，条目集合与排序稳定（LLM 文本可不同，但不得增删 critical / high）。
12. **活体收敛口径（对齐 P3 Level-triggered，防待办无限堆积）**：关注报告、待审区与收件箱（`/v1/inbox`）**只投影当前仍未收敛的活体项**——Workflow run 已离开 `AwaitingApproval`（进入 `running`/`converged`/`failed`/`canceled`）、Proposal 已离 `submitted`、草稿已 Apply/弃稿、或 `Escalate` 已被确认归档/对应会话已终结时，**立即退出待处理队列**，仅保留在历史事件/审批审计流中；严禁把只增不减的 append-only 历史事件条数直接显示为「待你处理」。

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| LLM 幻觉/无证据条目 | ❗高 | 报告编造事故或引用不存在的对象 | 候选由规则收集；entries 必须带 candidateId；evidence 服务端解析；未知条目丢弃；critical/high 无法被 LLM 降级 |
| 权限泄露 | ❗高 | 报告聚合越权内容，比列表页更隐蔽 | 生成前按 viewer scope 裁剪；缓存键含 permHash；越权断言进验收 |
| 成本与延迟 | ⚠️中 | 每次打开都跑 LLM | 报告缓存 + stale-while-revalidate + 候选指纹（无变化不重算）+ token 预算 + 频率限制；rules 降级保底 |
| 噪音/注意力疲劳 | ⚠️中 | 什么都说=什么都没说 | clear 区显式、attention 上限、忽略/稍后反馈、严重度映射可调 |
| 报告成第二真相 | ⚠️中 | 系统对象开始引用报告内容 | 派生视图无 DocType/无 git；条目只引用事实，事实仍回源；报告 id 不入对象引用 |
| 判定口径主观 | ⚠️中 | 什么算「重要」因人而异 | 严重度映射表确定性 + critical/high 守卫；LLM 只在候选内叙述；反馈按 viewer 存 |
| 无数据/全空态 | ⚠️低 | 新系统首屏空白 | 诚实空态 + 检查范围 + 接入 CTA；不生成假条目 |
| 生成器与前端双源 | ⚠️低 | 前端自行拼报告 | 报告在服务端生成；前端只渲染结构；数据来源行钉死 |

**结论：可行。零新机制——读侧派生 + 既有 Provider（LLM）+ ctx 装配 + ops DB 缓存；最坏退化=规则模板报告，界面不空白。**

## 8. 待决问题

见 [open-questions.md#attention](../open-questions.md)（条数阈值 / 缓存粒度与 TTL / clear 窗口三项）。

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
