# Session — 会话（三段式：背景装配→预更新执行→属性回整）

| 项 | 值 |
|---|---|
| K8s 对照 | —（类比 kubectl exec 的交互面：会话只装配上下文与改声明，绝不直接动运行实体） |
| 形态 | 机制概念（Session 落 dsh 宿主会话；产物 SessionLog/ContextNotes/draft） |
| 作用域 | Global / System |
| 状态 | 定稿（2026-11-27 用户裁定：「这个不是新三段。一直都是这个三段」——本文档=三段式 Session 的落地权威描述，非重构；机制层 Relevance/CtxCache/Importance 见 concepts/context.md） |

## 1. 定义（2026-11-27 用户裁定：三段式一直就是这个三段，本文=落地权威）

一个逻辑意图/任务由**三段式 Session** 完成（不是新设计，是既有三段的落地定稿）：

| 段 | 名称 | 一句话 | 触发/结束 |
|---|---|---|---|
| **第一段** | **背景装配** | LLM 描述命令→tag 分析与缓存命中→三路注入→builtin RAG→类似 session→developer_system 仓库发现→层层整理→产出**背景**（≤5k 字，逐块溯源可点击） | 意图进入即开始；背景就绪即结束 |
| **第二段** | **预更新执行** | 反复 ask 询问；**能做的永远是文档预更新（draft）**——**没有命令**，命令都到 workflow 的 agent 节点执行 | 用户 apply 预更新即结束 |
| **第三段** | **属性回整** | LLM 判断过程中哪些文档的 ref/tag/重要程度/metainfo 属性要改，**默认自动更新** | apply 事件触发；回整完成即闭环 |

**两条铁律**：
1. **会话没有命令**：第二段的会话（chat 面，挂人）**不具备任何命令执行能力**——一切命令执行都由 **workflow 的 agent 节点**（headless agent，agent.md 两类形态）承担。会话的产出物只有一种：**文档预更新（draft）**。
2. **属性自动、内容人审**：第三段的**属性类**（ref/tag/重要程度/metainfo）apply 后**默认自动更新**（LLM 判断，无需逐条审）；**文档内容类**变更永远走第二段 draft→用户 apply 人审，不自动。

## 2. 边界

**是**：背景装配面（上下文获取与整理）；预更新面（draft 生成+ask 循环）；属性回整面（apply 后元数据自动维护）。

**不是**：
- 不是命令执行器（会话零执行；执行=workflow agent 节点）；
- 不是文档内容直改器（内容变更只有 draft→apply 一条路）；
- 不是记忆系统本体（记忆=文档域 Memory DocType+CtxCache，concepts/context.md）。

## 3. 第一段·背景装配

**管线（顺序即声明）**：

```
意图输入
 ① LLM 描述：把命令改写/描述清楚 → 上下文需求整理
 ② tag 分析：分析这段命令的 tag 与 tag 相关 → 先查 CtxCache 有没有满足要求的缓存上下文
   （命中=直接切片取用，TagCtxShard/ComboCache 机制不变，context.md）
 ③ 三路注入：
   - 工具使用（基础命令规范/默认查询 Skill）
   - service 描述及其 tag（ServiceDesc 货架）
   - global 的 index 及其 tag（DocIndex 顶层目录）
 ④ LLM 描述、获得相应上下文整理
 ⑤ builtin RAG 查询相关文档（context.find/pack/expand）——**核心约束：尽量使用系统查找上下文**，不靠记忆猜
 ⑥ 查找类似 session（导入 session 描述——SessionLog/ContextNotes 近期相关会话）
 ⑦ 经 developer_system 定位相应代码仓库 → 找到仓库（impl/docs 引用链）
 ⑧ 一层层整理，提取出基础的上下文
 ⑨ 产出【背景】
```

**背景（背景块）格式裁决**：
- **默认最多 5k 字**（预算可配，ContextPolicy 域）；
- **每一块有明确标识：哪个资源、哪个文件**（`[ServiceDesc/systems/x/system.yaml]`、`[Doc rule/rule_eng.md]`、`[Repo developer_system→<repo>#<path>]`…）；
- **点击可对应上下文**：控制台会话 ctx 面逐块可点，跳转到对应资源/文档/文件的完整上下文（溯源不是装饰，是日常操作）。

## 4. 第二段·预更新执行

- 会话内**反复沟通/ask 询问**（chat 面，可直接问人——与 headless 询问分轨，agent.md）；
- 执行的唯一形态：**把要做的事落成文档预更新（draft）**——`POST /v1/design-docs/draft` 管线（已实现），永远不直接改权威文档；
- **【没有命令】**：用户在会话里说"改代码/跑构建"→ 会话把它落成对应文档的预更新（如 WorkflowDesign/ImplDoc 修订），真执行走 doc apply → workflow 的 agent 节点（headless）——**命令都到 workflow 的 agent 节点执行的 agent**；
- 用户在会话/文档面**查看相应文档更新**（draft diff 可见）；
- 需要时**让用户 apply**（人审闸，唯一写权威入口）；**apply 后进入第三段**。

## 5. 第三段·属性回整

**触发**：`DocApplied`（第二段的预更新被 apply）即拉起——不再是异步 SessionClosed。

**做什么（还是 LLM 判断）**：回看整个过程，判断哪些文档的哪些属性需要更改：
- **ref 属性**（过程中解析/新产生的引用——顺手入册）；
- **tag 属性**（tags/tagRelevance——新主题该打的 tag、相关性升降）；
- **重要程度**（importance 0-100——含防刷分多样性折扣，context.md 算法不变）；
- **metainfo**（metadatainfo 侧车：trace{requires/implements/verifies/…}、digest 等元数据）。

**然后默认自动更新这些属性**（写 metadatainfo 侧车+索引投影，不经人审）。

**闸门收窄裁决（对旧第三段的修改）**：
| 产出 | 旧规则 | 新规则 |
|---|---|---|
| 属性类（ref/tag/importance/metainfo） | Judge Agent 裁决才生效 | **默认自动更新**（用户裁决） |
| 缓存补全（TagCtxShard 归因裁剪） | Judge 裁决 | 随属性回整自动（缓存=派生物可丢弃可重建，本无风险） |
| 内容级 Proposal | Judge+查重 | 不变：查重+人审闸保留（内容不是属性） |

## 6. 与旧设计的机制衔接（保留不变）

- **Relevance(A,B) 0-100 全局相关性、Importance 防刷分算法、TagCtxShard 按Tag分片缓存、takeBudget 可调**：全部保留（context.md）——第一段②的缓存命中、第三段的 importance/tagRelevance 回整就是用这套机制；
- **第二段前缀稳定**：反复询问仍在同一会话（保 Prefix KV Cache）——变的只是会话不做执行，不是会话被切碎；
- **DocApplied 相关性阈值重建**（≥75 标 stale）：不变，第三段属性回整后照常触发；
- **归因轨迹记录**（used_effective/queried_irrelevant/missed_in_phase1）：保留，供第三段回整与缓存补全用。

## 7. 与其他概念的关系

- **Agent（两类形态）**：会话挂 chat agent（人的交互面）；执行走 workflow 的 headless agent 节点——本设计是两类形态裁决的彻底贯彻；
- **Workflow service 节点（2026-11-27 session 裁决「builtin 的 service 的 agent 可以用 session 来解决」）**：service 内部 agent 的执行载体=**本文档同一 session 机制层**（workflow.md §1.3）——run 落 unit=service 节点 → 引擎为 service 的 agent（`ServiceDesc.instances.agentRefs`）开一个执行 session，`contextPassing` 上一轮上下文（判断结论/plan 与 diff/验收 findings/审批记录）作为**首轮输入注入**，run 挂起在该节点等 session 心跳终结 → 沿表续行且 `history.sessionId` 回填真实会话锚。与三段式的关系：三段式=「人与文档」的会话形态（第二段只产 draft），service 执行 session=「引擎与系统」的会话形态（工具面=该系统 ops，产出=op 执行结果）——机制层（背景装配/CtxCache/回整）共用，第二段「会话没有命令」铁律对它不适用（它是执行体不是咨询面）；
- **Workflow**：会话预更新 apply → DocApplied → workflow 引擎（developer-loop 主干或 default-task）接管执行；
- **developer_system**：第一段⑦仓库发现的通路（ServiceInstance impl/docs 引用链）；
- **Draft 管线**：第二段的唯一产出通道（design-docs/draft→apply）；
- **ContextPolicy 域**：背景 5k 预算、packLimits、缓存参数的配置面。

## 8. 设计规则

1. **会话零执行**（铁律 1）：控制台会话面不提供任何命令执行入口；会话 agent 的工具面不含执行型 ops。
2. **背景 ≤5k 字逐块溯源**：超预算按 RankScore 截断；块标识缺资源/文件=装配 bug（Lint 级要求）。
3. **属性回整只碰元数据**：第三段永不改文档正文/权威对象 spec——越界即回滚并记账。
4. **默认自动、例外人审**：属性自动更新如需关闭（`autoMeta: false`），ContextPolicy 域可配；内容类永远人审。
5. **第一段约束**：尽量使用系统查找上下文（RAG/缓存/索引优先）；类似 session 只导入描述不导入全文。

## 9. 可行性分析（含现状账）

| 环节 | 状态 |
|---|---|
| builtin RAG（contextidx：`/v1/context/index\|find\|relevance`） | **已实现部署** |
| draft 预更新→apply 管线（design-docs/draft + apply） | **已实现部署** |
| tag 池/metadatainfo 侧车/docrepo 元数据直出（#/tags 面已落地） | **已实现部署** |
| SessionLog/ContextNotes 近期 session 记录 | **已实现** |
| CtxCache/TagCtxShard 机制（context.md） | 设计定稿（部分随 contextidx 落地） |
| 第一段⑨背景块溯源点击（会话 ctx 面逐块跳转） | **未实现（UI 轮）** |
| 第一段⑥类似 session 检索面 | 部分（SessionLog 在，检索排序面未接） |
| 第一段⑦developer_system 仓库发现自动化 | **未实现（引用链在，自动定位未接）** |
| 第三段属性回整器（apply 触发+默认自动） | **未实现（declared-deferred）** |

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 背景 5k 装不全 | ⚠️ 中 | 大任务上下文超预算 | 块化按 RankScore 截断+第二段 JIT 补拉（context.find 不变） |
| 属性自动改错 | ⚠️ 低 | LLM 误判 tag/importance | 只碰元数据可随时人工改回+归因轨迹可审计 |
| 会话被误当成执行器 | ⚠️ 中 | 用户在会话里要求直接跑 | 规则 1 工具面无执行 ops+话术引导落 draft |
| 第三段漏回整 | ⚠️ 低 | apply 后回整器未拉起 | DocApplied 事件驱动+漏回整=下轮第一段②缓存缺失可见 |

**结论：可行。三段中两段半的底座已实现（RAG/draft/tag 面）；本次改造主要是管线重排+闸门收窄+两个新面（背景溯源 UI、属性回整器）。**

## 10. 待决问题

见 open-questions.md#session

## 11. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
