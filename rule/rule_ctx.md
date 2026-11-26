---
name: rule-ctx
docType: Rule
scope: core_system
ownerRefs: [{kind: ServiceDesc, name: core_system}]
---
# Rule — 上下文与记忆（R-CTX）

> 所属：[rule.md](rule.md) 规则目录。规则 ID 全局稳定，拆分不改号。

> 用户裁决（2026-11-25）：文档先有 **index**，再分级别/分模块/打 tag/相关度；**动态调用工具取上下文，不读全量**；内置 RAG；类型对应缓存（类 Skill）+ 文档更新主动失效。（跨轮交接维持 `loop-next.md` 散文——用户明确认可。）
> 用户裁决（2026-11-26）：**tag 是这个 RAG 的核心**——tag 带 tagType；**文档 / scheme / provider / service 描述四族都打 tag**；词表无全局数量上限，**数量限制在会话装配面**（pack：每 tagType ≤5、总计 ≤20，可配）；**全系统分数统一 0–100**（`importance`、`tagRelevance`、`affinity`、全局相关性基元 `Relevance(A, B) ∈ [0, 100]`）；**三段式 Session**（①获取上下文侦察段→②任务执行段（会话自复用保 Prefix KV Cache + 动态增量更新 + 触发任务缓存）→③**异步**总结与演化段：提 Proposal / 正向归因补缓存 / 防刷分 Rerank + **独立审核 Agent 裁决与界面人类评论因子**）；**CtxCache 按 Tag 细粒度分片触发（`TagCtxShard`）+ 非对称覆盖率拼装**，缓存容量与单次提取大小（`takeBudget`）均可动态调整；文档更新按 `Relevance(UpdatedDoc, Target) ≥ rebuildThreshold` 控制关联重建（避免全量写放大雪崩）；**ctx 在 session 界面可视，可设缓存实效**。本规则组是**底层系统规则**。

## R-CTX-1 索引先行

任何检索/装配之前必须有索引（DocIndex）。索引是派生物、可丢弃可重建，**不入 git 权威**；未建索引=降级「按 path 直读」并显式标注（`degraded:true`），不得静默返回空。

## R-CTX-2 检索而非全量

agent 默认**不得整篇读设计文档**（尤其 >20KB 的单篇）；顺序恒为 `index 命中 → chunk 摘要 → 按需 expand 原文`。上下文装配走**通用接口**（`context.find / pack / expand`），不得各会话自建读法。

## R-CTX-3 Tag/TagType 核心与 0–100 统一分值（四族打标，词表开放、装配受限）

每个 tag 恰好归属一个 **tagType**（域注册，无全局数量上限）；**文档（Document）/ Scheme / Provider / ServiceDesc 四族对象都打 tag**（同一词表；Event 经 type→tags 入池，Session 经任务 tag 入池）。
- **全系统分数统一为 `0–100` 整数/定点数**：文档 `importance`（0–100）、`tagRelevance`（`map<tag, 0-100>`，文档×tag 相关度）、`affinity`（`tag↔tag` 亲和度 0–100）、事件 `importance`（0–100）、以及**全局相关性打分函数 `Relevance(A, B) ∈ [0, 100]`**（衡量任意两对象/任务/文档/缓存/提案 A 与 B 的相关性，唯一相关性测试基元）。
- **系统内部权威 + 侧车导出**：所有 tag/relevance/importance（含界面人类审核评分 `humanScore`）在系统内部（SQLite `docs DB` / `DocIndex`）维护并随 Rerank 动态演化；同目录 `<name>.md.metadatainfo` 侧车是内部元数据的**导出快照**（R-DOC-6/7），导出/GitHub 镜像保留。
- **数量限制只在会话装配面**：ContextPack 携带的 tag 集每 tagType ≤5、总计 ≤20（ContextPolicy 可配）。tag 亲和矩阵由 `connectops-context` 周期重算，**因子可配置、版本化后生效**。

## R-CTX-4 三段式 Session + 按 Tag 细粒度触发 CtxCache + 会话自复用

一个逻辑任务/意图由**三段式 Session** 协同完成，兼顾 **Prefix KV Prompt Caching** 与自递归演化：

1. **第一段·获取上下文 Session（侦察段）**：
   - **最小底座预插入**：仅预插基础命令使用规范（查本系统的 CLI/Skill 工具说明）+ 相应顶层目录 Index（Catalog 一句话货架）；
   - **按 Tag 细粒度触发 CtxCache + 差量侦察**：Agent 先识别任务目标 Tag 集，直接按单 Tag 触发细粒度缓存分片 **`TagCtxShard[tagType:tag]`**（或通过非对称加权覆盖率 `TagCoverage(Task, ComboCache) ≥ 90` 命中组合缓存）；**已命中且未失效的 Tag 分片直接提取（提取大小 `takeBudget` 可动态调整）**；侦察会话**只对未命中/stale 的差量 Tag** 调用命令拉取（完整 Tag 词表与 TagRule、四族对象 Rule/Doc/Scheme/Provider/Service、当前活跃/近期关联 Event、**近期相关 Session**、各对象 `importance` 与 `Relevance(A,B)`），装配产出 `ContextPack`。
2. **第二段·任务执行 Session（执行段）**：
   - **会话自复用（保 Prefix KV Cache）**：多轮对话与连续执行**始终复用当前 Session 本身**（固定规范化前缀顺序，不每轮推翻重排头部 Prefix），在会话中按需触发和拉取任务缓存（`CtxCache` 容量上限与每次拿到的 `takeBudget` 均可调）；
   - **动态增量更新（JIT）**：执行中途发现背景不足或跨模块时，再次调用上下文命令增量拉取并更新当前会话持有的上下文集，忠实记录引用轨迹（`used_effective` / `queried_irrelevant` / `missed_in_phase1`）。
3. **第三段·总结与演化 Session（异步后台段 + 独立 Agent 裁决）**：
   - **天然异步**：第二段结束即向用户/上游返回结果（零主链路时延阻塞），由 `SessionClosed` 事件异步触发第三段总结 Session（类 Sleep-Time Compute）；
   - **固定产出三项候选，经独立审核 Agent（Judge Agent）+ 界面人类评论因子裁决后才可 Apply**：
     1. **不合理处提 Proposal（带门槛与查重）**：仅当任务遇到真实阻塞、规则冲突或文档与代码实测不一致（必带 `ref+hash` 证据）时才生成提案草稿；提单前先算 `Relevance(DraftProposal, ExistingProposals & Docs)`（`≥ 85` 自动合并补充至已有单据，不重复建单）；
     2. **正向归因裁剪生成/补充记忆缓存（Attribution Pruning）**：将实际引用的 `used_effective` 提权入缓存（`+5~+15`）、试错无关的 `queried_irrelevant` 剔除并降权（`-5~-10`）、第一段漏召回靠第二段补拉救场的 `missed_in_phase1` 补打当前任务 Tag 并重点写入对应 `TagCtxShard`；
     3. **防同质刷分的 Importance / TagRelevance Rerank**：局部高频只调 `tagRelevance(doc, tag)`；全局 `importance(doc)` 必须叠加**跨任务多样性折扣** $w_{\text{div}}(T_i) = 1 - \max_{j<i}\text{Relevance}(T_i,T_j)/100$（5 个高相关同质任务不抬升全局 `importance`）+ **L0 宪法刚性保底（95–100）** + **界面人类审核/评论因子（`humanScore`）**，且总结产出的 Rerank/Cache/Proposal 草案**必须经另一独立审核 Agent 校验通过**（高危或人类钉住项经界面人审）后方可生效。

## R-CTX-5 ref+hash 引用与可调预算压缩

pack 与 `CtxCache` 分片中每条摘要必须带 **`ref`（系统地址=`<repo>/<path>#<anchor>`）+ `hash`（commit/blob sha）**，可展开回原文；摘要与原文冲突以原文为准。**`CtxCache` 的存储容量（`cacheSizeLimit` / `shardMaxTokens`）与每次会话拿到的提取预算（`takeBudget`，缺省=窗口 30%，可按会话/按调用动态调整）均支持配置与按需伸缩**；超预算必压缩、截断标注 `truncated:true`。跨轮交接 `loop-next.md` 同纪律：pack 内只放其**压缩摘要**（ref+hash 指向原文），散文原文仍是唯一权威通道。

## R-CTX-6 细粒度 Tag 缓存 + 相关性阈值控制重建 + ctx 可视可控

三级缓存：L1 chunk 摘要 / L2 **按 Tag 细粒度分片缓存（`TagCtxShard[tagType:tag]`）与组合 ContextPack** / L3 **会话上下文缓存**（键含内容指纹、extractor/策略/矩阵版本）。
- **按相关性阈值抑制重建写放大**：`DocApplied` / 仓 commit 发生时，仅增量重算变更文档自身 chunk；对关联文档与下游 `CtxCache` 条目 $B$，先通过全局相关性算法计算 $\text{Relevance}(D_{\text{updated}}, B) \in [0, 100]$——**仅当 $\text{Relevance}(D_{\text{updated}}, B) \ge \theta_{\text{rebuild}}$（`ContextPolicy.cache.rebuildThreshold`，缺省 75，可调）时才标 `stale:true` 并触发失效与预热重建**；低相关条目不重建，依靠调整相关度算法与阈值消灭全量写放大雪崩。
- **ctx 在 session 界面可视且人类可评**：展示 tagSig / 命中的 `TagCtxShard` / chunks(ref+hash) / tokens / 来源 / 命中统计，支持手动失效、改 TTL、改提取大小，并在界面审核时提供**人类评论/评分因子（`humanScore` 0–100）**直接锚定文档/缓存重要度；写操作走写面门控，审计面（event_log）不受缓存影响。

## R-CTX-7 异步总结回写与双 Agent 审校闭环

第二段会话结束即异步启动第三段总结 Session，把日志压缩为 ContextNotes 并产出归因统计（`used_effective / queried_irrelevant / missed_in_phase1`）、`TagCtxShard` 增量更新与 Rerank 候选；经独立审核 Agent（Judge Agent）判定通过后落入会话上下文缓存与索引元数据，形成「检索 → 执行轨迹 → 异步归因 → 独立审校/人评 → 缓存与分值进化」的闭环。

## R-CTX-8 底座规则（按 Tag 装载四族上下文 + 近期 Session）

会话开启时**按 tag 装载 rule / provider / service 描述 / document 四族上下文（及近期相关事件与近期相关 session）**是**系统底层规则**：任何会话开工前必须经 CtxCache 按 Tag 触发复用或第一段差量侦察完成装配（多轮对话复用本会话自身上下文并按需触发任务缓存），装配失败必须显式降级（`degraded:true`）并可见，**不静默、不是可选优化**。

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](rule.md)）。
