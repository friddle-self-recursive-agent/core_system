# Context — 上下文装配（Tag 核心 / 索引 / 检索 / 压缩 / 缓存 / 两段会话）

| 项 | 值 |
|---|---|
| K8s 对照 | —（无直接对照；类比 informer 的本地缓存 + 调度器的 predicate 打分） |
| 形态 | 机制概念（不新增存储对象）；派生产物 DocIndex / ContextPack / ContextNotes / CtxCache 可丢弃可重建 |
| 作用域 | 全局（检索面按 scope 过滤） |
| 状态 | 设计定稿（2026-11-25 用户裁决：索引先行、分级分模块打标、检索而非全量、内置 RAG + 类 Skill 缓存；**2026-11-26 用户裁决：tag 是这个 RAG 的核心**——tagtype 域、四族打标、两段开会话、0.9 向量复用、ctx 在 session 界面可视可控） |

## 1. 定义

**上下文（Context）不是"把文档读进 prompt"，而是"按任务装配最小高信号 token 集"的机制。** 它由四件事构成，**组织这四件事的核心键是 tag**：

1. **索引（DocIndex）**：全部文档 + 事件 + 声明面的结构化投影（级别 / 模块 / tag / 章节 / 摘要 / 内容指纹），是先决条件——**没有索引就没有检索**；
2. **检索（Retrieve）**：按当前任务上下文（对象 kind、模块、最近 diff、事件 tag）做相关度打分，返回**章节级**片段（chunk）而非整篇；
3. **压缩（Pack）**：把命中的片段压成一份**带引用（ref+hash）**的 ContextPack（预算内最小集，引用可展开回原文）；
4. **缓存（Cache）**：chunk 摘要、pack、会话上下文落盘复用（类 Skill 的 `cachePolicy`），文档变更时**提示并主动失效**。

### 1.1 Tag 模型（RAG 核心）

- **TagType 域注册**：每个 tag 恰好归属一个 tagtype（如 `domain: event/ui/provider`、`mech: dedup/cache/budget`）；tagtype 与 tag 的**词表无全局数量上限**，随打标自然增长。
- **四族对象都打 tag**（同一套词表）：
  | 族 | 载体 | 打标字段 |
  |---|---|---|
  | Document | docsRoot 与各仓 md | `tags`（按 tagtype 归组）+ **`tagRelevance`**（map<tag, 0-1>，本文档对该 tag 的相关度）+ `importance`（1-5）+ level/module/digest |
  | Scheme | `core/scheme.yaml`（kind/eventType 注册） | `tags`（该 kind/eventType 关联的问题域） |
  | Provider | provider 对象 | `tags`（能力域：llm/git/notify/…） |
  | ServiceDesc | `systems/<s>/system.yaml` | `tags`（系统级问题域） |

  Event 不直接打标，经 `type→tags` 映射入同一池（event.md 规则 16）。
- **数量限制不在词表，在会话装配面**：一次 ContextPack 携带的 tag 集 = **每 tagtype ≤5 个 tag、总计 ≤20 个 tag**（ContextPolicy 可配缺省）。词表开放、装配受限——这是"检索聚焦"的结构保证。

### 1.2 跨轮交接不变

跨轮记忆分工不变（用户裁决）：**跨轮交接仍以 `loop-next.md` 散文为准**（不引入结构化 state 作为强制通道）；Context 只负责读侧投影——pack 内可携带 loop-next 的**压缩摘要**（ref+hash 指向原文，原文始终权威可展开）。

## 2. 边界

**是**：文档/事件/声明面的检索面、装配面、压缩面、缓存面；会话开启的两段式背景装配；会话结束的缓存回写；ctx 的可视与缓存实效控制面。

**不是**：
- 不是文档权威（权威仍是 git 仓 / 文档库；索引是**派生物**，删掉可重建，不入 git）；
- 不是记忆存储（跨轮交接=`loop-next.md`；会话内记忆=dsh session；长期事实=文档 + known-issues）；
- 不改变对象语义（检索/压缩只是读取与投影，不写对象、不触发 apply）；
- 不做全量灌入（"把 13MB 文档全读一遍"是本概念明确要消灭的反模式）；
- 不是权限面（tag 不替代 role/scope 过滤；检索与 ctx 展示都在调用者权限域内进行）。

## 3. 结构

```yaml
# DocIndex（派生物；按仓一次构建，增量更新）
apiVersion: context.core/v1
kind: DocIndex
spec:
  builtAt: "2026-11-26T00:00:00Z"
  source: {repo: core_design, commit: "<sha>"}   # 内容指纹=commit；文件级=blob sha
  docs:
    - path: concepts/event.md
      level: L1               # L0 宪法 / L1 概念 / L2 运行时设计 / L3 证据 / L4 笔记
      module: event           # 主模块（单值）
      tags:                   # 按 tagtype 归组（tag∈唯一 tagType）
        domain: [event, notification]
        mech: [dedup, urgency]
      tagRelevance: {dedup: 0.9, urgency: 0.8, notification: 0.6}   # 文档×tag 相关度
      importance: 4           # 1-5
      digest: "事件分诊与去重；类型→标签；相关度因子"
      sha: "<blob sha>"
      chunks:
        - id: "event#r16"     # path#<anchor>（章节锚）
          heading: "6. 设计规则 16"
          summary: "type→tags、urgency=level×importance、亲和矩阵定时重算"
          sha: "<chunk 归一化内容 sha>"
          tokens: 180
  objects:                  # 声明面三族入同一索引（tag 池共享）
    - {kind: Scheme, path: core/scheme.yaml, tags: {domain: [scheme]}}
    - {kind: Provider, name: "<provider 名>", tags: {domain: [llm, gateway]}}
    - {kind: ServiceDesc, name: "<system 名>", tags: {domain: [core, deploy]}}

# ContextPack（一次装配的产物；两段会话第一段的交付物；带引用；可缓存）
apiVersion: context.core/v1
kind: ContextPack
spec:
  query: {text: "...", kinds: [Workflow], modules: [console], budgetTokens: 40000}
  tagSig:                 # 会话装配面的受限 tag 集（词表开放、装配受限）
    domain: [console, workflow]
    mech: [cache, retrieval]
    vector: "<tag 词表空间的归一化向量（cosine 相似度用）>"
  chunks:
    - {ref: "core_design/concepts/workflow.md#1.3", hash: "<blob sha>@<commit>", why: "执行模型=session/agent", score: 0.82, tokens: 900}
    - {ref: "core_system_instance/runtime/console-ui.md#11", hash: "<blob sha>@<commit>", why: "整改清单 A/B/C", score: 0.71, tokens: 2400}
    - {ref: "loop-next.md#全文", hash: "<blob sha>@<commit>", why: "跨轮交接压缩摘要", score: 1.0, tokens: 800}
  citations: ["<repo>@<commit>:<path>#<anchor>"]   # ref+hash 可展开回原文
  tokens: 31200                                    # ≤ budgetTokens
  cacheKey: "pack:<tagSig>:<indexCommit>"
  provenance: {discoverySession: "<侦察会话 id>", reused: false, similarity: null}

# CtxCache（pack/chunk 缓存条目；session 界面可视、可设实效）
apiVersion: context.core/v1
kind: CtxCacheEntry
spec:
  key: "pack:<tagSig>:<indexCommit>"
  kind: pack | chunk-summary
  tagSig: {domain: [console], mech: [cache]}
  builtAt: "2026-11-26T03:00:00Z"
  expiresAt: "2026-12-03T03:00:00Z"        # TTL（缺省 7d，可手动改）
  hits: 3
  stale: false                              # 文档更新后=true（提示更新）
  ownerSession: "<产生它的会话 id>"

# ContextPolicy（可配置因子；声明面对象，走 apply）
apiVersion: context.core/v1
kind: ContextPolicy
spec:
  factors:                    # 打分因子权重（Σ=1，可分别调）
    tag: 0.30                 # 直接 tag 重合（按 tagRelevance 加权）
    affinity: 0.15            # tag 亲和传播（共现矩阵）
    keyword: 0.25             # 关键词/BM25
    recency: 0.10             # 时间衰减（半衰期可配）
    pin: 0.10                 # L0/L1 常驻加权（宪法/概念优先）
    prior: 0.10               # 上下文先验（当前模块/kinds/最近 diff）
  recency: {halfLifeDays: 30}
  budget: {ratio: 0.3, maxTokens: 60000}   # 背景包 ≤ 模型窗口 30%
  packLimits: {maxTagsPerType: 5, maxTagsTotal: 20}   # 装配面 tag 限制（词表不设限）
  reuse: {similarity: 0.9, algorithm: cosine-tag-vector}   # ≥0.9 复用缓存 pack
  cache: {ttl: 7d, invalidateOnDocChange: true, prewarm: true}
  ui: {sessionCtxView: true}               # session 界面 ctx 可视 + 缓存实效可控
```

## 4. 生命周期

1. **会话开启 = 两段（"一次 session 开两次"，用户裁决）**：
   - **第一段·侦察会话（discovery session）**：只做"了解本次任务"——**不停调用 core 工具**（`context.find` / `context.expand`）迭代查询，找出这个会话需要的上下文，产出任务会话的默认 ctx（ContextPack + tagSig）。
   - **复用判定**：任务 tagSig 与已有缓存 pack 的签名做**向量相似度（tag 空间 cosine）≥0.9 → 直接复用缓存 pack**，跳过侦察；未命中才装配新 pack 并入缓存。
   - **第二段·任务会话**：以 pack（含 ref+hash 引用清单）起步执行；需要更多上下文时**再调检索工具**（JIT），pack 只是起点不是上限。
2. **会话结束 → 会话上下文缓存**：pack 与会话日志压缩（ContextNotes：做了什么/结论/未决点/引用）一并落缓存，**携带同一套 tag 参数**（tags/tagRelevance/importance），供后续会话 0.9 匹配复用；同时按"哪些 chunk 被实际使用、命中率"回写检索因子（反馈闭环）。
3. **文档更新 → 提示更新 → 触发重建**：`DocApplied` / 仓 commit → index 重算 → **提示更新**（列出受影响的 stale 缓存条目，session 界面 + 事件可见）→ 触发受影响缓存的失效与预热重建（invalidate + prewarm）。
4. **ctx 可视可控**：session 界面展示本会话的 ctx（ContextPack 全文：tagSig / chunks(ref+hash) / tokens / 来源=复用或新建 / 命中统计），并可在该面板**设置缓存实效**（手动失效、调整 TTL）——失效走写面门控。
5. **亲和矩阵定时重算**：tag↔tag 亲和度由 ConnectOps 周期任务重算（见 connector.md 规则 8），因子可配置，结果版本化后生效。
6. **loop 轮专用**：跨轮交接 `loop-next.md` 走同一压缩纪律——pack 注入其压缩摘要（ref+hash 指向原文），散文原文仍是唯一权威通道。

## 5. 与其他概念的关系

- **Scheme**：索引元数据字段沿用 `conventions.tags`（`tags/importance/digest/tagRelevance`）；检索策略=ContextPolicy（声明面对象）；Scheme 本身作为声明面一族入索引。
- **Provider / ServiceDesc**：声明面打 tag（能力域/系统域），同一 tag 池——按 tag 一把捞起"规则+provider+服务描述+文档"四族上下文。
- **Event**：事件是上下文的第二来源（type→tags、urgency 参与打分）；详见 event.md 规则 16。
- **Skill**：缓存策略与 Skill 同构（`cachePolicy` 的 TTL/失效条件），复用同一套缓存纪律。
- **Agent / Session**：`Agent.spec.docsPolicy` 的"按需读"由此实现；两段开会话接入 `agent-session.md`。
- **Proposal**：提案是一等消费方——提交节点跑 `context.pack` 产 conflicts/supplements 对照（proposal.md §4.6），对话与审批面明确展示；提案本体带 `conventions.tags` 入同一 tag 池。
- **ConnectorOps**：索引构建/亲和重算/失效/预热=代码承载能力，归 `connectops-context`（R-ENG-3）。
- **Notification / Console**：stale 缓存的"提示更新"经事件+session 界面徽标呈现；ctx 可视与缓存实效控制在 console session 视图（见 runtime/console-ui.md）。

## 6. 设计规则

1. **索引先行**：任何检索必须建立在 DocIndex 上；未建索引时降级为"按 path 直接读"并在报告中标注，不静默。
2. **Tag 核心与四族打标**：tag∈唯一 tagType，词表无全局上限；**文档 / Scheme / Provider / ServiceDesc 都打 tag**（同一词表）；文档另带 `tagRelevance`（文档×tag 相关度）与 `importance`；缺字段=索引构建告警（不阻断），由 ConnectOps 补标（LLM 打标）后回写。
3. **限制在装配面**：ContextPack 携带的 tag 集受限——每 tagtype ≤5、总计 ≤20（ContextPolicy 可配）；**词表不设限，会话上下文设限**。
4. **检索而非全量**：agent 默认不得整篇读设计文档；顺序恒为 `index 命中 → chunk 摘要 → 按需展开原文`。单篇 >20KB 的文档（如 console-adoption）必须可章节级检索。
5. **两段开会话**：第一段侦察会话（core 工具迭代检索装配 ctx）→ 第二段任务会话（pack 起步 + JIT）；侦察结果 tagSig 与缓存 pack 的向量相似度 ≥0.9（cosine）即复用缓存，不重复装配。
6. **ref+hash 引用**：pack 中每条摘要必须带 `ref`（系统地址=`<repo>/<path>#<anchor>`）与 `hash`（commit/blob sha），可展开回原文；摘要与原文冲突以原文为准。
7. **因子可配置**：相关度=加权和（tag/affinity/keyword/recency/pin/prior），权重、半衰期、预算、pack tag 限制、复用阈值全部来自 ContextPolicy；改因子走 apply，不硬编码。
8. **上下文有预算**：每次装配有 token 预算（缺省=窗口 30%，可配）；超预算必压缩，压缩不得丢引用。
9. **缓存类 Skill + 提示更新**：L1=chunk 摘要缓存、L2=pack 缓存、L3=会话上下文缓存（同 tag 参数）；**文档更新 → index 重算 → 提示受影响缓存（stale 可见）→ 触发失效与预热重建**；审计面（event_log）不受缓存影响。
10. **ctx 可视可控**：session 界面展示本会话 ctx 全文（tagSig/chunks/tokens/来源/命中统计），并可**设置缓存实效**（手动失效、改 TTL）；失效为写面动作，走门控。
11. **会话结束回写**：会话上下文缓存 + ContextNotes + "实际用到的 chunk"命中统计（检索质量的反馈闭环）。
12. **loop-next 同纪律**：跨轮交接散文仍是唯一权威通道；pack 内只放其压缩摘要（ref+hash 指向原文）。
13. **底座规则**：会话按 tag 装载四族上下文（**rule / provider / service 描述 / document**）是**系统底层规则**（rule.md R-CTX），任何会话开工前必须完成或显式降级（`degraded:true`），不静默、不是可选优化。
14. **不漏事件**：事件参与索引与打分（type→tags、urgency），缓存只加速读取，不改变事实。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 索引漂移（文档改了索引没更新） | ⚠️ 中 | 检索到旧内容 | 内容指纹（sha）+ DocApplied/commit 主动失效 + 定时全量重建兜底 |
| 向量复用误判 | ⚠️ 低 | tag 相似但任务实际不同，复用了不合适的 pack | 阈值可配（0.9 偏保守）；复用 pack 仍可 JIT 再检索；命中统计反馈 |
| 摘要失真 | ⚠️ 中 | 压缩丢关键约束 | 强制 ref+hash 可展开；摘要失败降级为原文节选；冲突以原文为准 |
| 因子调参过拟合 | ⚠️ 低 | 权重只对历史任务最优 | 因子版本化 + 命中率反馈 + 定期回归集评测 |
| 缓存膨胀 | ⚠️ 低 | 磁盘增长 | TTL + LRU + 按 index commit 清理旧代；session 界面可手动实效 |
| 打标质量差 | ⚠️ 中 | 检索不到 | LLM 打标 + 人工可改 + tag 亲和传播兜底（漏标也能通过邻居命中） |

**结论：可行。全部为读侧增强，零写路径影响；最坏退化=回到"按路径读"，不阻塞既有流程。**

## 8. 待决问题

- chunk 粒度（章节 vs 段落）与最大 chunk 大小的默认值，需实测（建议先按章节，超 2k tokens 再切段）。
- tagtype 的初始命名集（domain/mech/surface/lifecycle/…）在首次全量打标时定，之后只增不改名（词表开放但改名=失效放大）。

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
