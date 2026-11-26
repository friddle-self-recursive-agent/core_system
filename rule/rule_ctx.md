---
name: rule-ctx
docType: Rule
scope: core_system
ownerRefs: [{kind: ServiceDesc, name: core_system}]
---
# Rule — 上下文与记忆（R-CTX）

> 所属：[rule.md](rule.md) 规则目录。规则 ID 全局稳定，拆分不改号。

> 用户裁决（2026-11-25）：文档先有 **index**，再分级别/分模块/打 tag/相关度；**动态调用工具取上下文，不读全量**；内置 RAG；类型对应缓存（类 Skill）+ 文档更新主动失效。（跨轮交接维持 `loop-next.md` 散文——用户明确认可。）
> 用户裁决（2026-11-26）：**tag 是这个 RAG 的核心**——tag 带 tagType；**文档 / scheme / provider / service 描述四族都打 tag**；词表无全局数量上限，**数量限制在会话装配面**（pack：每 tagType ≤5、总计 ≤20，可配）；会话**开两次**（侦察会话→任务会话），tagSig 向量相似 ≥0.9 复用缓存 pack；每条摘要带 ref+hash；会话结束落会话上下文缓存（同 tag 参数）；文档更新→index 重算→**提示更新**→触发缓存重建；**ctx 在 session 界面可视，可设缓存实效**。本规则组是**底层系统规则**。

## R-CTX-1 索引先行

任何检索/装配之前必须有索引（DocIndex）。索引是派生物、可丢弃可重建，**不入 git 权威**；未建索引=降级「按 path 直读」并显式标注（`degraded:true`），不得静默返回空。

## R-CTX-2 检索而非全量

agent 默认**不得整篇读设计文档**（尤其 >20KB 的单篇）；顺序恒为 `index 命中 → chunk 摘要 → 按需 expand 原文`。上下文装配走**通用接口**（`context.find / pack / expand`），不得各会话自建读法。

## R-CTX-3 Tag/TagType 核心（四族打标，词表开放、装配受限）

每个 tag 恰好归属一个 **tagType**（域注册，无全局数量上限）；**文档（Document）/ Scheme / Provider / ServiceDesc 四族对象都打 tag**（同一词表；Event 经 type→tags 入池）。文档额外带 `tagRelevance`（map<tag,0-1>，文档×tag 相关度）、`importance`（0–100，文档重要度，满分 100）、`level/module/digest`；缺字段=索引告警（不阻断），由 `connectops-context` 补标。**文档的 tag/tagType/importance 以同目录 `<name>.md.metadatainfo` 侧车承载（R-DOC-6）；导出/GitHub 镜像保留侧车。** **数量限制只在会话装配面**：ContextPack 携带的 tag 集每 tagType ≤5、总计 ≤20（ContextPolicy 可配）。tag 亲和矩阵（tag↔tag 相关度）由该 ConnectOps 周期重算，**因子可配置、版本化后生效**。

## R-CTX-4 两段开会话 + 向量复用

会话**开启两次**：第一段**侦察会话**只了解任务——**不停调用 core 工具**（`context.find/expand`）迭代检索，产出任务会话的默认 ctx（ContextPack + tagSig）；任务 tagSig 与缓存 pack 签名做 **tag 空间向量相似度（cosine）≥0.9 → 直接复用缓存 pack**，不重复装配。第二段**任务会话**以 pack 起步、按需 JIT 检索。

## R-CTX-5 ref+hash 引用与预算压缩

pack 中每条摘要必须带 **`ref`（系统地址=`<repo>/<path>#<anchor>`）+ `hash`（commit/blob sha）**，可展开回原文；摘要与原文冲突以原文为准。每次装配有 token 预算（缺省=窗口 30%，可配）；超预算必压缩、截断标注 `truncated:true`。跨轮交接 `loop-next.md` 同纪律：pack 内只放其**压缩摘要**（ref+hash 指向原文），散文原文仍是唯一权威通道。

## R-CTX-6 缓存类 Skill + 提示更新 + ctx 可视可控

三级缓存：chunk 摘要 / ContextPack / **会话上下文缓存**（键含内容指纹、extractor/策略/矩阵版本）。**文档更新（DocApplied / commit）→ index 重算 → 提示更新（受影响 stale 缓存条目可见，session 界面+事件）→ 触发失效与预热重建**；TTL 可配、可手动改。**ctx 在 session 界面可视**（tagSig/chunks(ref+hash)/tokens/来源/命中统计），并可**设置缓存实效**（手动失效、改 TTL；失效走写面门控）；审计面（event_log）不受缓存影响。

## R-CTX-7 会话结束回写

会话结束把日志压缩为 ContextNotes，并落**会话上下文缓存**（携带同一套 tag 参数：tags/tagRelevance/importance），供后续会话 0.9 匹配复用；回写「用到/未用到/需要但没有」的统计（检索因子的反馈闭环）。

## R-CTX-8 底座规则（会话按 tag 装载四族上下文）

会话开启时**按 tag 装载 rule / provider / service 描述 / document 四族上下文**是**系统底层规则**：任何会话（loop 轮、导入任务、console 交互、workflow 节点）开工前必须完成装配（或经两段式复用），装配失败必须显式降级（`degraded:true`）并可见，**不静默、不是可选优化**。

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](rule.md)）。
