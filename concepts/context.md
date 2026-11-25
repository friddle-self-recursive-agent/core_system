# Context — 上下文装配（索引 / 检索 / 压缩 / 缓存 / 背景会话）

| 项 | 值 |
|---|---|
| K8s 对照 | —（无直接对照；类比 informer 的本地缓存 + 调度器的 predicate 打分） |
| 形态 | 机制概念（不新增存储对象）；派生产物 DocIndex / ContextPack / ContextNotes 可丢弃可重建 |
| 作用域 | 全局（检索面按 scope 过滤） |
| 状态 | 设计定稿（2026-11-25 用户裁决：索引先行、分级分模块打标、检索而非全量、内置 RAG + 类 Skill 缓存） |

## 1. 定义

**上下文（Context）不是"把文档读进 prompt"，而是"按任务装配最小高信号 token 集"的机制。** 它由四件事构成：

1. **索引（DocIndex）**：全部设计文档 + 事件日志的结构化投影（级别 / 模块 / tag / 章节 / 摘要 / 内容指纹），是先决条件——**没有索引就没有检索**；
2. **检索（Retrieve）**：按当前任务上下文（对象 kind、模块、最近 diff、事件 tag）做相关度打分，返回**章节级**片段（chunk）而非整篇；
3. **压缩（Pack）**：把命中的片段压成一份**带引用**的 ContextPack（预算内最小集，引用可展开回原文）；
4. **缓存（Cache）**：chunk 摘要与 pack 落盘复用（类 Skill 的 `cachePolicy`），文档变更时**主动失效**。

跨轮记忆分工不变（用户裁决）：**跨轮交接仍以 `loop-next.md` 散文为准**（该形态被明确认可，不引入结构化 state 作为强制通道）；Context 只负责"每轮开工时把相关文档/事件装配成背景"，不替代交接。

## 2. 边界

**是**：文档与事件的检索面、装配面、压缩面、缓存面；任务开始前的背景会话；会话结束后的笔记回写与索引因子更新。

**不是**：
- 不是文档权威（权威仍是 git 仓 / 文档库；索引是**派生物**，删掉可重建，不入 git）；
- 不是记忆存储（跨轮交接=`loop-next.md`；会话内记忆=dsh session；长期事实=文档 + known-issues）；
- 不改变对象语义（检索/压缩只是读取与投影，不写对象、不触发 apply）；
- 不做全量灌入（"把 13MB 文档全读一遍"是本概念明确要消灭的反模式）。

## 3. 结构

```yaml
# DocIndex（派生物；按仓一次构建，增量更新）
apiVersion: context.core/v1
kind: DocIndex
spec:
  builtAt: "2026-11-25T00:00:00Z"        # 构建时刻
  source: {repo: core_design, commit: "<sha>"}   # 内容指纹=commit；文件级=blob sha
  docs:
    - path: concepts/event.md
      level: L1               # L0 宪法 / L1 概念 / L2 运行时设计 / L3 证据 / L4 笔记
      module: event           # 模块（console/cored/workflow/agent/event/doc/...）
      tags: [event, dedup, urgency, notification]
      importance: 4           # 1-5（conventions.tags 既有字段）
      digest: "事件分诊与去重；类型→标签；相关度因子"
      sha: "<blob sha>"
      chunks:
        - id: "event#r16"     # path#<anchor>（章节锚）
          heading: "6. 设计规则 16"
          summary: "type→tags、urgency=level×importance、亲和矩阵定时重算"
          sha: "<chunk 归一化内容 sha>"
          tokens: 180

# ContextPack（一次装配的产物；带引用；可缓存）
apiVersion: context.core/v1
kind: ContextPack
spec:
  query: {text: "...", kinds: [Workflow], modules: [console], tags: [ui], budgetTokens: 40000}
  chunks:
    - {ref: "concepts/workflow.md#1.3", why: "执行模型=session/agent", score: 0.82, tokens: 900}
    - {ref: "runtime/console-ui.md#11", why: "整改清单 A/B/C", score: 0.71, tokens: 2400}
  citations: ["<repo>@<commit>:<path>#<anchor>"]   # 压缩后仍可展开回原文
  tokens: 31200                                    # ≤ budgetTokens
  cacheKey: "pack:<querySig>:<indexCommit>"

# ContextPolicy（可配置因子；声明面对象，走 apply）
apiVersion: context.core/v1
kind: ContextPolicy
spec:
  factors:                    # 打分因子权重（Σ=1，可分别调）
    tag: 0.30                 # 直接 tag 重合
    affinity: 0.15            # tag 亲和传播（共现矩阵）
    keyword: 0.25             # 关键词/BM25
    recency: 0.10             # 时间衰减（半衰期可配）
    pin: 0.10                 # L0/L1 常驻加权（宪法/概念优先）
    prior: 0.10               # 上下文先验（当前模块/kinds/最近 diff）
  recency: {halfLifeDays: 30}
  budget: {ratio: 0.3, maxTokens: 60000}   # 背景包 ≤ 模型窗口 30%
  cache: {ttl: 7d, invalidateOnDocChange: true, prewarm: true}
```

## 4. 生命周期

1. **任务开始 → 背景会话（background session）**：只做四步——`index → retrieve → pack → cache`；产出 ContextPack 注入主会话（主会话=任务执行会话）。背景会话不写代码、不改文档。
2. **主会话**：以 pack 为背景开工；需要更多上下文时**再调检索工具**（JIT），而不是重读全量文档。pack 只是起点不是上限。
3. **会话结束 → 压缩回写**：会话日志压成 ContextNotes（做了什么/结论/未决点/引用），并按"哪些 chunk 被实际使用、命中率、偏差"回写检索因子（episodic 反馈）。
4. **文档变更 → 主动失效**：`DocApplied`（设计文档面）或仓 commit 触发——失效该文件全部 chunk 缓存与引用它的 pack（按内容指纹判定），可选预热重建。
5. **亲和矩阵定时重算**：tag↔tag 亲和度由 ConnectOps 周期任务重算（见 connector.md 规则 8），因子可配置，结果版本化后生效。

## 5. 与其他概念的关系

- **Scheme**：索引元数据字段沿用 `conventions.tags`（`tags/importance/digest`）；检索策略=ContextPolicy（声明面对象）。
- **Event**：事件是上下文的第二来源（type→tags、urgency 参与打分）；详见 event.md 规则 16。
- **Skill**：缓存策略与 Skill 同构（`cachePolicy` 的 TTL/失效条件），复用同一套缓存纪律。
- **Agent / Session**：`Agent.spec.docsPolicy` 的"按需读"由此实现；会话生命周期接入 `agent-session.md`。
- **ConnectorOps**：索引构建/亲和重算/失效/预热=代码承载能力，归 `connectops-context`（R-ENG-3）。
- **Notification**：事件紧急度（urgency）与上下文相关度共用因子，但不互相替代（通知分发看 level/importance，检索看相关度）。

## 6. 设计规则

1. **索引先行**：任何检索必须建立在 DocIndex 上；未建索引时降级为"按 path 直接读"并在报告中标注，不静默。
2. **分级分模块打标**：每份设计文档必须带 `level / module / tags / importance / digest`；缺字段=索引构建告警（不阻断），由 ConnectOps 补全（LLM 打标）后回写。
3. **检索而非全量**：agent 默认不得整篇读设计文档；顺序恒为 `index 命中 → chunk 摘要 → 按需展开原文`。单篇 >20KB 的文档（如 console-adoption）必须可章节级检索。
4. **因子可配置**：相关度=加权和（tag/affinity/keyword/recency/pin/prior），权重、半衰期、预算全部来自 ContextPolicy；改因子走 apply，不硬编码。
5. **上下文有预算**：每次装配有 token 预算（缺省=窗口 30%，可配）；超预算必压缩，压缩不得丢引用（每段摘要带 `path#anchor`）。
6. **引用可展开**：pack 里每条结论必须能回指原文；摘要与原文冲突以原文为准。
7. **缓存类 Skill**：L1=chunk 摘要缓存（键=`doc sha + chunk id + extractor 版本`），L2=pack 缓存（键=`query 签名 + index commit`）；TTL 可配；**文档更新主动失效**。
8. **背景会话与主会话分离**：背景会话只做检索/压缩/缓存（不产生副作用）；主会话从 pack 起步，按需再检索。
9. **会话结束回写**：会话压缩成 ContextNotes 并按"实际用到的 chunk"更新命中统计（检索质量的反馈闭环）。
10. **不漏事件**：事件参与索引与打分（type→tags、urgency），审计面（event_log）不受缓存影响；缓存只加速读取，不改变事实。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 索引漂移（文档改了索引没更新） | ⚠️ 中 | 检索到旧内容 | 内容指纹（sha）+ DocApplied/commit 主动失效 + 定时全量重建兜底 |
| 摘要失真 | ⚠️ 中 | 压缩丢关键约束 | 强制引用可展开；摘要失败降级为原文节选；冲突以原文为准 |
| 因子调参过拟合 | ⚠️ 低 | 权重只对历史任务最优 | 因子版本化 + 命中率反馈 + 定期回归集评测 |
| 缓存膨胀 | ⚠️ 低 | 磁盘增长 | TTL + LRU + 按 index commit 清理旧代 |
| 打标质量差 | ⚠️ 中 | 检索不到 | LLM 打标 + 人工可改 + tag 亲和传播兜底（漏标也能通过邻居命中） |

**结论：可行。全部为读侧增强，零写路径影响；最坏退化=回到"按路径读"，不阻塞既有流程。**

## 8. 待决问题

- chunk 粒度（章节 vs 段落）与最大 chunk 大小的默认值，需实测（建议先按章节，超 2k tokens 再切段）。
- 向量检索是否首发：首发用 tag + BM25（零外部依赖），向量作为可选后端（ContextPolicy.retriever 切换）。

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
