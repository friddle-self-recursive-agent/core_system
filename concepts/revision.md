# Revision — 版本、并发与审计

| 项 | 值 |
|---|---|
| K8s 对照 | resourceVersion（乐观锁）+ audit log |
| 形态 | metadata.resourceVersion + sqlite docs DB（内容权威）+ ops DB apply_log 流水 + git 导出快照（output/public） |
| 作用域 | 跟随宿主 |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. 定义

多写者（人、多个 Agent、跨系统提案）并存，需要三件事：

1. **乐观并发**（防丢更新）：resourceVersion 文档级乐观锁；
2. **变更历史与审计**：sqlite docs DB（当前内容+rv，默认权威）+ ops DB `apply_log`（操作流水）+ 周期 git 导出快照（公开/output；**非逐次账本**）；
3. **diff 与合并**：**文档 diff 是语义活，必须 LLM 来做**——机器只判定"相同/不同"（文本级），"哪里不同、是否冲突、怎么合"由 LLM 语义 diff 给出提案，人裁兜底。

## 2. 边界

**是**：写路径的并发正确性 + 历史与审计 + 语义 diff 的触发点。

**不是**：
- **不再有字段归属/managedFields/三方合并**（ 删除：不做字段级 ownership）；
- 不是 generation（generation 数 Spec 语义变更；resourceVersion 数每次写入）；
- 不是备份/发布版本。

## 3. 机制

```
resourceVersion：Core 每次成功写入自增；Apply 提交带回读到的版本，
 不符 = Conflict → 重读 →（需要合并时）LLM 语义 diff 提案 → 人裁/force
文档级 diff： 机器=整文档文本比对（相同 no-op / 不同提交）；
 LLM=语义解读（差异归类：意图变更？格式噪声？冲突？）+ 合并提案
审计： ops DB apply_log（fieldManager/rv/结果）+ sqlite 当前内容；周期 git 导出=公开快照（非逐次账本）
```

## 4. 生命周期

随对象建立，随每次 Apply 演进；真删后 `apply_log` 仍在账，git 导出快照保留旧内容（逐次正文历史见规则 6）。

## 5. 与其他概念的关系

- Apply 第三步由它承担；SessionLog/PlanDoc 也在其审计范围。
- Conflict 率仍是健康指标（Agent 互踩信号）。
- Status/Spec 写权分离由权限系统 承载（不再是 managedFields）。

## 6. 设计规则

1. 任何写入必须携带 fieldManager；无主写入拒绝。
2. Conflict 重试上限与 Workflow.backoff 共享预算（防活锁）。
3. **git 导出提交消息结构化**：`<fieldManager> <action> <reason-ref>`（reason-ref 指向 DriftReport/PlanDoc/Event）；写路径本身落 sqlite+apply_log，不依附提交。
4. 历史不可改写（no force-push；git 导出只追加/覆盖公开快照）。
5. **LLM 语义 diff 的输出永远是提案**：事实基础是 sqlite 当前内容/导出快照的文本 diff；合并落地必须人裁或 权限系统 明确放行——LLM 不直接改历史。
6. **默认 sqlite，git 只导出**：docs DB 是内容权威；git 布局=周期导出/公开，不参与写路径。逐次正文历史=`doc_history` 待补（当前 sqlite 后端 `GET /v1/rev-content` 返回 503 诚实降级，不得冒充逐次历史）。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| LLM diff 幻觉/漏判 | ⚠️ 中 | 语义归类可能错 | 文本 diff 为事实底座；LLM 只解读+提案；高危合并人裁 |
| 文档级锁粒度粗 | ⚠️ 低 | 大文档并发互踩 | 写者少+拆文档；Conflict 率观测 |
| sqlite 做乐观锁吞吐 | ⚠️ 低 | 单写者队列已串行化 | 同 结论；WAL+busy_timeout |
| sqlite 无逐次正文历史 | ⚠️ 中 | rev-content/编辑器历史降级 | apply_log 有操作流水；doc_history 下一段；git 导出仅快照不冒充逐次 |

**结论：可行。删除 SSA 后复杂度显著下降；LLM 语义 diff 的风险被"提案制"框住。**

## 8. 待决问题

见 open-questions.md#revision

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
