# Context — 上下文装配（Tag 核心 / 0–100 全局相关性 / 按 Tag 分片缓存 / 三段式会话与自演化）

| 项 | 值 |
|---|---|
| K8s 对照 | —（无直接对照；类比 informer 的本地分片缓存 + 调度器的 predicate/priority 打分） |
| 形态 | 机制概念（不新增存储对象）；派生产物 DocIndex / TagCtxShard / ContextPack / ContextNotes / CtxCache 可丢弃可重建 |
| 作用域 | 全局（检索面按 scope 过滤） |
| 状态 | 设计定稿（2026-11-26 用户裁决：**tag 是 RAG 核心**；**全系统分数统一 0–100** 与全局相关性公式 `Relevance(A,B) ∈ [0,100]`；**按 Tag 细粒度触发 CtxCache**（容量与提取大小均可调）；**人类评论因子 + 跨任务多样性防刷分 Rerank**；**按相关性阈值抑制文档重建写放大**）。**2026-11-27 用户裁决：三段式 Session 彻底改造**——新三段=**背景装配→预更新执行→属性回整**（会话零执行/属性默认自动），权威见 [session.md](session.md)；本文档只保留机制层（Relevance/CtxCache/Importance 算法不变） |

## 1. 定义

**上下文（Context）不是"把文档读进 prompt"，而是"按任务装配最小高信号 token 集、并在执行后异步自演化"的机制。** 它由五件事构成，**组织这五件事的核心键是 tag 与全局相关性函数 `Relevance(A, B)`**：

1. **索引（DocIndex）**：全部文档 + 事件 + 近期 Session + 声明面的结构化投影（级别 / 模块 / tag / 章节 / 摘要 / 内容指纹），是先决条件——**没有索引就没有检索**；
2. **全局相关性与打分（`Relevance(A, B) ∈ [0, 100]`）**：全系统一切分数（`importance`、`tagRelevance`、`affinity`、`humanScore`、事件 `importance`）统一为 **`0–100` 标度**；任意两实体（任务、文档、chunk、缓存分片、事件、提案、会话）的相关性由同一全局公式 `Relevance(A, B) ∈ [0, 100]` 计算；
3. **按 Tag 细粒度分片缓存（`CtxCache`：`TagCtxShard` + `ComboCache`）**：替代粗粒度整包 Cosine 匹配，**按单 Tag（`tagType:tag`）细粒度切分缓存分片**（命中任一 Tag 即触发对应分片缓存），辅以非对称加权覆盖率（`TagCoverage ≥ 90`）组合复用；**`CtxCache` 的存储总容量/分片大小与每次会话提取的预算（`takeBudget`）均可动态调整**；
4. **三段式 Session（2026-11-27 彻底改造，权威见 [session.md](session.md)）**：**第一段·背景装配**（LLM 描述命令→tag 分析与缓存命中→三路注入→builtin RAG→类似 session→developer_system 仓库发现→层层整理→产出背景 ≤5k 字逐块溯源可点击）；**第二段·预更新执行**（反复 ask 询问；**会话没有命令**——能做的永远是文档预更新 draft，命令执行都到 workflow 的 agent 节点；用户 apply 后进第三段）；**第三段·属性回整**（apply 触发：LLM 判断哪些文档的 ref/tag/重要程度/metainfo 要改，**默认自动更新**）；旧「会话自复用执行段/异步总结演化段+Judge 闸」定义作废——机制层（KV 前缀稳定/缓存/公式）全部保留；
5. **按相关性阈值抑制重建（防写放大雪崩）**：`DocApplied` 仅对满足 $\text{Relevance}(D_{\text{updated}}, B) \ge \theta_{\text{rebuild}}$ 的高相关文档/缓存触发重算与失效，靠调整相关度算法与阈值降低级联重建。

### 1.1 Tag 模型与 0–100 统一标度（RAG 核心）

- **TagType 域注册**：每个 tag 恰好归属一个 tagtype（`domain` / `mech` / `surface` / `lifecycle` / `doc`…）；tagtype 与 tag 的**词表无全局数量上限**，随打标自然增长。
- **四族对象 + 事件 + 近期 Session 共享同一 Tag 池（分值统一 0–100）**：
  | 族 | 载体 | 打标与分值字段（统一 0–100） |
  |---|---|---|
  | Document | docs DB（SQLite 权威）与导出 md | `tags`（按 tagtype 归组）+ **`tagRelevance`**（`map<tag, 0-100>`，文档对该 tag 的相关度）+ **`importance`**（`0–100`）+ **`humanScore`**（`?0–100`，界面审核人类评论锚定分）+ level/module/digest（导出侧车见 R-DOC-6） |
  | Scheme | `core/scheme.yaml` 及 `aspect` 分册 | `tags` + `aspect`（该 kind/eventType/aspect 关联的问题域） |
  | Provider | provider 对象 | `tags`（能力域：llm/git/notify/…） |
  | ServiceDesc | `systems/<s>/system.yaml` | `tags`（系统级问题域） |
  | Event / Session | `event_log` / `SessionLog` & `ContextNotes` | Event 经 `type→tags` + `importance (0-100)` 入池；近期 Session 经任务 `tagSig` + `ContextNotes` 入池 |

- **数量限制不在词表，在会话装配面**：一次 ContextPack 携带的 tag 集 = **每 tagtype ≤5 个 tag、总计 ≤20 个 tag**（ContextPolicy 可配缺省）。词表开放、装配受限——这是"检索聚焦"的结构保证。

### 1.2 全局相关性公式 `Relevance(A, B) ∈ [0, 100]` 与防刷分 Importance 算法

#### ① 全局相关性基元 `Relevance(A, B) -> 0..100`
任意两个实体 $A$（如当前任务/查询/新提案/刚更新的文档）与 $B$（如候选文档/chunk/缓存分片/历史 Session/已有提案），统一映射到同一特征空间 $\Phi(X) = (\text{Tags}(X), \vec{r}_X, \text{Keywords}(X), \text{Scope}(X), \text{Kind}(X))$，其中 $\vec{r}_X(t) \in [0, 100]$ 为实体 $X$ 在标签 $t$ 上的相关度：

$$\text{Relevance}(A, B) = \text{clamp}_{0..100}\Big( w_{\text{tag}} \cdot S_{\text{tag}}(A, B) + w_{\text{aff}} \cdot S_{\text{aff}}(A, B) + w_{\text{kw}} \cdot S_{\text{kw}}(A, B) + w_{\text{scope}} \cdot S_{\text{scope}}(A, B) \Big)$$
（默认权重：$w_{\text{tag}}=0.45,\ w_{\text{aff}}=0.20,\ w_{\text{kw}}=0.25,\ w_{\text{scope}}=0.10$，$\sum w = 1$）：
1. **非对称加权 Tag 覆盖分 $S_{\text{tag}}(A, B) \in [0, 100]$（Tversky Recall，取代脆弱的离散 Cosine）**：
   $$S_{\text{tag}}(A, B) = \frac{\sum_{t \in \text{Tags}(A)} \vec{r}_A(t) \cdot \min\!\big(\vec{r}_A(t), \vec{r}_B(t)\big)}{\sum_{t \in \text{Tags}(A)} \big(\vec{r}_A(t)\big)^2} \times 100$$
   当 $B$（如缓存或大文档）除了包含 $A$ 所需的全部 Tag 外还带有额外 Tag 时，对称 Cosine 会因分母膨胀误判为低相似（漏判），而非对称覆盖分精准衡量「$A$ 的需求被 $B$ 满足了多少」。
2. **Tag 亲和传播分 $S_{\text{aff}}(A, B) \in [0, 100]$**：通过 `affinity[t_a][t_b] ∈ [0, 100]` 计算跨 Tag 语义邻近度（如 `proposal` 与 `approval` 亲和度 85）。
3. **文本/BM25 重合分 $S_{\text{kw}}(A, B) \in [0, 100]$**：标题、摘要与正文关键词重合度归一化至 `0–100`。
4. **作用域与引用链先验分 $S_{\text{scope}}(A, B) \in [0, 100]$**：同 `scope`/`module` 或直接引用得 `100`，`global` 得 `70`，跨无关系统得 `0`。

#### ② 装配排序分 `RankScore(A -> B) -> 0..100`
仅当 $\text{Relevance}(A, B) \ge \theta_{\text{min}}$（缺省 20，防止毫不相关的文档仅凭高重要度混入）时参与排序：
$$\text{RankScore}(A \to B) = \text{clamp}_{0..100}\Big( 0.70 \cdot \text{Relevance}(A, B) + 0.20 \cdot \text{Importance}(B) + 0.10 \cdot \text{Recency}(B) \Big)$$

#### ③ 防同质任务刷分的 `Importance(B) ∈ [0, 100]` 算法（带人类评论因子与多样性折扣）
为防止连续 5 个同质任务（如连续修 5 个前端小样式）把边缘文档的全局 `importance` 刷到 100、挤掉 L0 宪法，**局部高频与全局重要度严格解耦**：
- **局部高频只升 `tagRelevance(B, tag)`**；
- **全局 `Importance(B)` 由三部分合成**：
  $$\text{Importance}(B) = \text{clamp}_{L_{\text{floor}}..100}\Big( \alpha_L \cdot I_{\text{base}}(\text{level}) + \alpha_H \cdot I_{\text{human}}(B) + \alpha_E \cdot \Delta_{\text{emp}}(B) \Big)$$
  1. **层级基准与宪法保底 $I_{\text{base}}(\text{level})$**：L0 宪法刚性保底 $L_{\text{floor}} = 95$（永不被挤出）、L1 概念基准 $80$、L2 运行时基准 $70$、L3 证据基准 $40$、L4 笔记基准 $30$；
  2. **界面人类审核/评论因子 $I_{\text{human}}(B) \in [0, 100]$**：用户在 Console 界面审核/点评文档或会话 ctx 时给出的评分（含评论指向的加减权）；一旦人类显式打分，$I_{\text{human}}$ 拥有最高锚定权重（$\alpha_H = 0.60$）；
  3. **跨任务多样性折扣经验项 $\Delta_{\text{emp}}(B) \in [-15, +15]$**：当任务序列 $\{T_1, \dots, T_k\}$ 将文档 $B$ 归因为 `used_effective` 时，第 $i$ 个任务对全局 `Importance(B)` 的贡献必须乘以**任务多样性折扣因子 $w_{\text{div}}(T_i)$**：
     $$w_{\text{div}}(T_i) = 1 - \max_{j < i} \frac{\text{Relevance}(T_i, T_j)}{100}$$
     - 若近期 5 个任务彼此高度相关（$\text{Relevance}(T_i, T_j) = 90$），后续任务的 $w_{\text{div}} = 0.10$，几乎不抬升全局 `Importance(B)`（只调高该域 `tagRelevance`）；
     - 唯有**跨不同领域、彼此低相关**（$\text{Relevance}(T_i, T_j) \le 30 \Rightarrow w_{\text{div}} \ge 0.70$）的多个任务都依赖文档 $B$ 时，$B$ 的全局 `Importance(B)` 才会实质上升；且每轮叠加 EMA 均值回归，杜绝全仓分数通胀。

### 1.3 跨轮交接不变

跨轮记忆分工不变（用户裁决）：**跨轮交接仍以 `loop-next.md` 散文为准**；Context 只负责读侧投影——pack 内携带 loop-next 的**压缩摘要**（ref+hash 指向原文，原文始终权威可展开）。

## 2. 边界

**是**：文档/事件/近期 Session/声明面的检索面、装配面、压缩面、按 Tag 分片缓存面；三段式 Session 的背景获取、执行期增量补充与异步总结演化；ctx 的可视、人类评分与缓存实效控制面。

**不是**：
- 不是文档权威（权威是 SQLite `docs DB`；索引与 `CtxCache` 是**派生物**，删掉可重建）；
- 不是无门槛自动篡改器（第三段异步总结产出的 Rerank / 缓存更新 / Proposal 草案，**必须经另一独立审核 Agent 裁决**，不会无脑直接 Apply）；
- 不破坏 Prefix KV Prompt Cache（多轮对话复用本 Session，前缀规范化定序，不每轮推翻重建 prompt 头部）；
- 不做全量灌入（"把 13MB 文档全读一遍"是本概念明确要消灭的反模式）；
- 不是权限面（tag 不替代 role/scope 过滤；检索与 ctx 展示都在调用者权限域内进行）。

## 3. 结构

```yaml
# DocIndex（派生物；按仓/docs DB 构建，按相关性阈值增量更新）
apiVersion: context.core/v1
kind: DocIndex
spec:
  builtAt: "2026-11-26T00:00:00Z"
  source: {backend: sqlite, highWaterRv: 128, commit: "<export-sha>"}
  docs:
    - path: concepts/event.md
      level: L1               # L0 宪法 / L1 概念 / L2 运行时设计 / L3 证据 / L4 笔记
      module: event           # 主模块（单值）
      tags:                   # 按 tagtype 归组（tag∈唯一 tagType）
        domain: [event, notification]
        mech: [dedup, urgency]
      tagRelevance: {dedup: 90, urgency: 80, notification: 60}   # 统一 0-100 标度
      importance: 85          # 0-100（文档重要度，满分 100）
      humanScore: null        # ?0-100（界面人类评论/审核打分；有值时锚定 importance）
      digest: "事件分诊与去重；类型→标签；相关度因子"
      sha: "<blob sha>"
      chunks:
        - id: "event#r16"     # path#<anchor>（章节锚）
          heading: "6. 设计规则 16"
          summary: "type→tags、importance 0-100、亲和矩阵定时重算"
          sha: "<chunk 归一化内容 sha>"
          tokens: 180
  objects:                  # 声明面三族 + 近期 Session 入同一索引（tag 池共享）
    - {kind: Scheme, path: core/scheme.yaml, aspect: root, tags: {domain: [scheme]}}
    - {kind: Provider, name: "<provider 名>", tags: {domain: [llm, gateway]}}
    - {kind: ServiceDesc, name: "<system 名>", tags: {domain: [core, deploy]}}
    - {kind: SessionLog, name: "<session id>", tags: {domain: [console], mech: [cache]}, importance: 75}

# TagCtxShard（按单 Tag 细粒度触发的缓存分片——粒度更细、极易命中、规范定序保 KV Cache）
apiVersion: context.core/v1
kind: TagCtxShard
spec:
  tagKey: "mech:cache"        # <tag_type>:<tag>（原子触发键）
  shardMaxTokens: 6000        # 分片大小可动态调整（ContextPolicy.cache.shardMaxTokens）
  tokens: 3200
  chunks:                     # 按 Relevance(tag, chunk) 与 importance 预排好序的摘要块
    - {ref: "core_design/concepts/context.md#3", hash: "<sha>", relevance: 95, importance: 90, tokens: 800, summary: "..."}
    - {ref: "core_system_instance/runtime/context-rag.md#6", hash: "<sha>", relevance: 92, importance: 85, tokens: 950, summary: "..."}
  builtAt: "2026-11-26T03:00:00Z"
  expiresAt: "2026-12-03T03:00:00Z"
  hits: 14
  stale: false

# ContextPack（第一段交付给第二段的背景包；由命中的 TagCtxShard + 差量侦察拼装而成）
apiVersion: context.core/v1
kind: ContextPack
spec:
  query: {text: "...", kinds: [Workflow], modules: [console], takeBudget: 30000}   # 拿到的大小 takeBudget 可按会话动态调整
  tagSig:                 # 会话装配面的受限 tag 集（每 tagType ≤5、总计 ≤20）
    domain: [{tag: console, weight: 95}, {tag: workflow, weight: 80}]
    mech: [{tag: cache, weight: 90}, {tag: retrieval, weight: 75}]
  shardsHit: ["domain:console", "mech:cache"]     # 直接按 Tag 触发命中的缓存分片
  deltaSearched: ["mech:retrieval"]               # 仅对未命中/stale 的 Tag 做第一段差量侦察
  chunks:
    - {ref: "core_design/concepts/workflow.md#1.3", hash: "<blob sha>@<commit>", why: "TagShard domain:workflow 命中", score: 88, tokens: 900}
    - {ref: "core_system_instance/acceptance/console/console-ui.md#11", hash: "<blob sha>@<commit>", why: "TagShard domain:console 命中", score: 84, tokens: 2400}
    - {ref: "loop-next.md#全文", hash: "<blob sha>@<commit>", why: "跨轮交接压缩摘要", score: 100, tokens: 800}
  citations: ["<repo>@<commit>:<path>#<anchor>"]
  tokens: 24500                                    # ≤ takeBudget
  cacheKey: "pack:<canonical-tagSig>:<indexVersion>"
  provenance: {discoverySession: "<侦察段 id>", tagShardHitRate: 75, comboCoverage: 92}

# ContextPolicy（可配置因子；声明面对象，走 apply）
apiVersion: context.core/v1
kind: ContextPolicy
spec:
  scoreScale: "0-100"         # 全系统统一 0-100 标度
  relevanceWeights:           # 全局 Relevance(A, B) 权重（Σ=1）
    tagCoverage: 0.45         # 非对称加权 Tag 覆盖率（Tversky Recall）
    affinity: 0.20            # Tag 亲和矩阵传播
    keyword: 0.25             # 关键词/BM25
    scopePrior: 0.10          # 作用域/模块/引用链先验
  rankWeights:                # RankScore(A -> B) 排序权重
    relevance: 0.70
    importance: 0.20
    recency: 0.10
  importanceModel:            # 防同质刷分的 Importance 合成参数
    levelFloors: {L0: 95, L1: 65, L2: 50, L3: 20, L4: 10}
    levelBases:  {L0: 98, L1: 80, L2: 70, L3: 40, L4: 30}
    humanWeight: 0.60         # 界面人类评论/审核因子权重
    diversityDiscount: true   # 启用 w_div = 1 - max Relevance(T_i, T_j)/100
    requireJudgeAgent: true   # 第三段总结产出必须经另一独立审核 Agent 裁决
  recency: {halfLifeDays: 30}
  budget:                     # CtxCache 容量与单次提取大小均可调
    cachePoolMaxTokens: 500000
    shardMaxTokens: 6000
    defaultTakeRatio: 0.30
    defaultTakeMaxTokens: 60000
    minTakeTokens: 2000
  packLimits: {maxTagsPerType: 5, maxTagsTotal: 20}
  reuse:
    mode: "tag-shard-first + asymmetric-coverage"
    comboCoverageThreshold: 90   # TagCoverage(Task, ComboCache) ≥ 90 整包切片复用；否则逐 Tag 触发 TagCtxShard
  cache:
    ttl: 7d
    rebuildThreshold: 75         # DocApplied 时仅 Relevance(UpdatedDoc, Target) ≥ 75 才标 stale 并触发重建（抑制写放大）
    prewarm: true
  proposalGate:
    dedupRelevanceThreshold: 85  # Relevance(Draft, Existing) ≥ 85 合并不重提
  ui: {sessionCtxView: true, humanReviewFactor: true, adjustableCacheSize: true}
```

## 4. 生命周期（三段式 Session 闭环）

1. **第一段·背景装配（2026-11-27 彻底改造，权威见 [session.md](session.md) §3）**：LLM 描述命令 → tag 分析并**先查 CtxCache**（`TagCtxShard`/`ComboCache` 命中直接切片取用，非对称覆盖率复用与 `takeBudget` 不变；未命中差量走检索）→ 三路注入（工具使用规范 / service 描述及 tag / global index 及 tag）→ **builtin RAG 查询相关文档**（核心约束：尽量使用系统查找上下文）→ 类似 session 导入描述 → 经 developer_system 定位代码仓库 → 层层整理产出**背景**：默认最多 5k 字、每一块明确标识哪个资源哪个文件、点击可对应上下文；
2. **第二段·预更新执行（会话零执行）**：会话内反复 ask 询问（同一会话保 Prefix KV Cache、JIT 补拉 `context.find/expand`、归因轨迹记录不变）；**会话没有命令**——能做的永远是**文档预更新（draft）**，命令执行都到 workflow 的 agent 节点（headless，agent.md 两类形态）；用户查看 draft diff → apply 后进第三段；
3. **第三段·属性回整（apply 触发，默认自动）**：LLM 判断过程中哪些文档的 **ref / tag / 重要程度(importance) / metainfo** 属性要改，**默认自动更新**（写 metadatainfo 侧车+索引投影）；缓存归因裁剪（`used_effective`/`queried_irrelevant`/`missed_in_phase1` 补偿进 `TagCtxShard`）随回整自动；**内容级 Proposal 仍查重+人审**；旧「Judge Agent 裁决一切第三段产出」收窄为只闸内容类（session.md §5 闸门收窄裁决）；防刷分 Importance/TagRelevance Rerank 算法（多样性折扣 $w_{\text{div}}$ 与 `humanScore` 因子）在回整中照常使用；
4. **文档更新 → 相关性阈值过滤 → 局部提示与重建**：
   - `DocApplied` 发生时，计算 $\text{Relevance}(D_{\text{updated}}, B) \in [0, 100]$；
   - **仅对 $\text{Relevance}(D_{\text{updated}}, B) \ge \theta_{\text{rebuild}}$（缺省 75，可调）的关联文档与 `TagCtxShard` / `ContextPack` 标 `stale:true` 并触发重建**；靠调整相关度算法得出的值降低无关/弱相关文档重建，阻断写放大雪崩。

## 5. 与其他概念的关系

- **Scheme**：索引元数据字段沿用 `conventions.tags`（统一 `0–100`）；Scheme 支持按 `aspect: <xxx>` 细粒度拆分（单文件单 Scheme，R-DOC-8），每个 aspect 独立打 Tag 入索引。
- **Provider / ServiceDesc**：声明面打 tag（能力域/系统域），同一 tag 池——按 tag 一把捞起"规则+provider+服务描述+文档+近期事件+近期 session"。
- **Event**：事件经 `type→tags` 与 `importance (0-100)` 参与索引与打分（event.md 规则 16）。
- **Agent / Session**：统一 `agent.md`、`agent-service-protocol.md` 与 `agent-session.md` 的三段式会话生命周期。
- **Proposal**：第三段总结 Session 的制度化出口（先查重 `Relevance ≥ 85` 再提单）+ 提交节点上下文对照（proposal.md §4.6）。
- **ConnectorOps**：索引构建/亲和重算/按阈值失效/预热归 `connectops-context`（R-ENG-3）。
- **Console**：session 界面展示 ctx 面板（命中的 `TagCtxShard`、chunks、tokens、来源、命中率），支持**动态调整缓存容量与提取大小**、手动失效/改 TTL、以及**人类审核评论打分（`humanScore`）**。

## 6. 设计规则

1. **索引先行**：任何检索必须建立在 DocIndex 上；未建索引时降级为"按 path 直接读"并在报告中标注（`degraded:true`），不静默。
2. **Tag 核心、四族+Event+Session 入池与 0–100 统一标度**：tag∈唯一 tagType，词表无全局上限；**Document / Scheme / Provider / ServiceDesc / Event / 近期 Session** 共享同一 tag 池；全系统 `importance`、`tagRelevance`、`affinity`、`humanScore` 与全局相关性函数 `Relevance(A, B)` **一律统一为 `0–100` 标度**。
3. **限制在装配面**：ContextPack 携带的 tag 集受限——每 tagtype ≤5、总计 ≤20（ContextPolicy 可配）；**词表不设限，会话上下文设限**。
4. **检索而非全量**：agent 默认不得整篇读设计文档；顺序恒为 `TagCtxShard / index 命中 → chunk 摘要 → 按需展开原文`。
5. **三段式 Session 与异步总结**：①获取上下文段（最小底座预插 + 按 Tag 触发 `TagCtxShard` + 仅对未命中 Tag 差量侦察四族/Event/近期 Session）→ ②任务执行段（**会话自复用保 Prefix KV Cache** + 动态触发任务缓存 + JIT 增量更新）→ ③**异步**总结与演化段（提 Proposal / 正向归因补缓存 / 防刷分 Rerank）。
6. **按 Tag 细粒度触发缓存 + 容量/提取大小双可调**：`CtxCache` 以单 Tag 分片 `TagCtxShard[tagType:tag]` 为原子触发单元，辅以非对称覆盖率 `TagCoverage(Task, Cache) ≥ 90`；**缓存总大小/分片大小与每次会话拿到的 `takeBudget` 均支持动态调整**。
7. **独立审核 Agent + 人类评论因子 + 防同质刷分算法**：第三段总结不是自动直通 Apply——必须由**另一独立审核 Agent（Judge Agent）**审校通过；全局 `importance` 重算必须乘以跨任务多样性折扣 $w_{\text{div}}(T_i) = 1 - \max_{j<i}\text{Relevance}(T_i,T_j)/100$（5 个高相关任务只升局部 `tagRelevance` 不刷全局 `importance`），叠加 L0 宪法保底（95–100）与界面**人类审核评论因子（`humanScore`）**。
8. **按相关性阈值抑制重建写放大**：`DocApplied` 时仅对满足 $\text{Relevance}(D_{\text{updated}}, B) \ge \theta_{\text{rebuild}}$（缺省 75，可配）的关联文档与缓存分片触发失效与重建，通过调整相关度算法分值降低级联重建。
9. **ref+hash 引用**：pack 与缓存分片中每条摘要必带 `ref` + `hash`，可展开回原文；摘要与原文冲突以原文为准。
10. **提案查重门槛**：第三段提 Proposal 必带实测冲突/阻塞 `ref+hash` 证据，且先算 `Relevance(Draft, Existing)`（`≥ 85` 自动合并补充，不重复提单）。
11. **ctx 可视可控可评**：session 界面展示 ctx 全貌，支持调缓存大小/提取预算/TTL/手动失效，并在审核界面提供人类评论打分入口。
12. **loop-next 同纪律**：跨轮交接散文仍是唯一权威通道；pack 内只放其压缩摘要（ref+hash 指向原文）。
13. **底座规则**：会话按 tag 装载四族上下文及近期事件/会话是**系统底层规则**（rule/rule_ctx.md R-CTX），任何会话开工前必须完成或显式降级（`degraded:true`）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 文档更新写放大雪崩 | ⚠️ 中→低 | 频繁 Apply 若全量重建会拖垮索引与缓存 | 按 `Relevance(UpdatedDoc, B) ≥ rebuildThreshold` 局部失效重建；侧车仅在定时导出 Git 时刷新 |
| 每轮新建侦察破环 Prefix KV Cache | ⚠️ 高→低 | 每轮重排头部或重开会话导致 Prefill 成本飙升 | 会话本身跨轮自复用 + `TagCtxShard` 规范字典序定序拼装 + 第一段仅差量侦察未命中 Tag |
| 离散 Cosine ≥ 0.9 漏判与误判 | ⚠️ 中→低 | 整包 Cosine 命中率极低 | 改为按单 Tag 细粒度触发 `TagCtxShard` + 非对称覆盖率 `TagCoverage(Task, Cache) ≥ 90` |
| 同质任务刷分导致 Importance 通胀 | ⚠️ 高→低 | 连续 5 个同类任务把边缘文档刷到 100 | 跨任务多样性折扣 $w_{\text{div}}$ + 局部/全局解耦 + L0 刚性保底 95 + 独立审核 Agent + 人类评论因子 |
| 第三段总结增加主链路时延 | ✅ 低 | 若同步执行会拖慢每次响应 | 第三段总结天然异步（`SessionClosed` 后台触发），主链路零阻塞 |
| 摘要失真 | ⚠️ 中 | 压缩丢关键约束 | 强制 ref+hash 可展开；冲突以原文为准 |

**结论：可行。三段式异步闭环 + 按 Tag 细粒度分片缓存 + 0–100 全局相关性公式，既保住了 Prefix KV Cache 性能，又通过双 Agent 审校与多样性折扣实现了安全的自递归演化。**

## 8. 待决问题

- chunk 粒度（章节 vs 段落）与最大 chunk 大小的默认值，需实测（建议先按章节，超 2k tokens 再切段）。
- tagtype 的初始命名集（domain/mech/surface/lifecycle/…）在首次全量打标时定，之后只增不改名（词表开放但改名=失效放大）。

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
