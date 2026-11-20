# Revision — 版本、并发与审计

| 项 | 值 |
|---|---|
| K8s 对照 | resourceVersion（乐观锁）+ audit log；~~managedFields/SSA~~（v0.4 删除，A33） |
| 形态 | metadata.resourceVersion + git 历史（天然审计）+ ops DB 流水 |
| 作用域 | 跟随宿主 |
| 状态 | 设计稿 v0.4（R3 修正） |

## 1. 定义

多写者（人、多个 Agent、跨系统提案）并存，需要三件事：

1. **乐观并发**（防丢更新）：resourceVersion 文档级乐观锁；
2. **变更历史与审计**：git 提交（内容版本）+ ops DB（操作流水）双轨（A23 不变）；
3. **diff 与合并**：**文档 diff 是语义活，必须 LLM 来做**（R3：git 无字段级归属概念，字段级合并不做）——机器只判定"相同/不同"（文本级），"哪里不同、是否冲突、怎么合"由 LLM 语义 diff 给出提案，人裁兜底。

## 2. 边界

**是**：写路径的并发正确性 + 历史与审计 + 语义 diff 的触发点。

**不是**：
- **不再有字段归属/managedFields/三方合并**（A33 删除：不做字段级 ownership）；
- 不是 generation（generation 数 Spec 语义变更；resourceVersion 数每次写入）；
- 不是备份/发布版本。

## 3. 机制

```
resourceVersion：Core 每次成功写入自增；Apply 提交带回读到的版本，
                不符 = Conflict → 重读 →（需要合并时）LLM 语义 diff 提案 → 人裁/force
文档级 diff：    机器=整文档文本比对（相同 no-op / 不同提交）；
                LLM=语义解读（差异归类：意图变更？格式噪声？冲突？）+ 合并提案
审计：          git commit（fieldManager 进 message）+ ops DB apply_log 双轨（A23）
```

## 4. 生命周期

随对象建立，随每次 Apply 演进；真删后历史仍在 git。

## 5. 与其他概念的关系

- Apply 第三步由它承担；SessionLog/PlanDoc 也在其审计范围。
- Conflict 率仍是健康指标（Agent 互踩信号）。
- Status/Spec 写权分离由 Policy 承载（不再是 managedFields，A33）。

## 6. 设计规则

1. 任何写入必须携带 fieldManager；无主写入拒绝。
2. Conflict 重试上限与 Loop.backoff 共享预算（防活锁）。
3. commit message 结构化：`<fieldManager> <action> <reason-ref>`（reason-ref 指向 DriftReport/PlanDoc/Event）。
4. 历史不可改写（no force-push）。
5. **LLM 语义 diff 的输出永远是提案**：事实基础是 git 文本 diff；合并落地必须人裁或 Policy 明确放行——LLM 不直接改历史。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| LLM diff 幻觉/漏判 | ⚠️ 中 | 语义归类可能错 | 文本 diff 为事实底座；LLM 只解读+提案；高危合并人裁 |
| 文档级锁粒度粗 | ⚠️ 低 | 大文档并发互踩 | 写者少+拆文档；Conflict 率观测 |
| git 做乐观锁吞吐 | ⚠️ 低 | 单写者队列已串行化 | 同 v0.2 结论 |

**结论：可行。删除 SSA 后复杂度显著下降；LLM 语义 diff 的风险被"提案制"框住。**

## 8. 原始设计标注

- A33（R3）：删字段级归属/三方合并；文档 diff=LLM 语义 diff（提案制）。
- A8/A23 沿用（并发控制存在、双轨审计）。

## 9. 待决问题

见 open-questions.md#revision

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
