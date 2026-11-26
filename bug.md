---
name: architecture-and-runtime-bugs
docType: VerifyDoc
scope: core_system
ownerRefs: [{kind: ServiceDesc, name: core_system}]
---
# Bug 与架构矛盾清算基线（bug.md）

> 所属：core_design 概念与规则对账基线；配套运行时验收落点见 core_system_instance `acceptance/bugs/bug.md` 与 `runtime/acceptance.md`（R-DOC-5 双仓同步）。

## 1. 架构矛盾与后期隐患清算总表（BUG-001 ~ BUG-009）

| 编号 | 领域 | 发现的矛盾 / 不足 / 后期隐患 | 裁决方案与落点规则 |
|---|---|---|---|
| **BUG-001** | 会话与上下文 | `agent.md`（按需自取）、`agent-service-protocol.md`（Catalog 预插）、`context.md`（两段式 RAG）三套机制并存打架 | **R-CTX-4 / R-CTX-8**：统一为**三段式逻辑 Session**（①第一段侦察：预插基础命令+目录 Index，按 Tag 触发 `TagCtxShard`，仅对差量 Tag 拉取 Tag/TagRule/四族/Event/**近期相关 Session** → ②第二段执行：会话自复用+JIT 增量更新 → ③第三段**异步**总结演化：提 Proposal / 正向归因补缓存 / 防刷分 Rerank + **独立审核 Agent 裁决**） |
| **BUG-002** | 打分标度 | 文档 `importance`（0–100）、事件/会话 `importance`（1–5）、`tagRelevance`/`affinity`（0–1）三套标度混用，缺统一相关性基元 | **R-CTX-3 / R-DOC-6**：全系统分值（含事件 `importance` 与界面人类评论因子 `humanScore`）**统一为 `0–100`**；定义唯一全局相关性函数 **`Relevance(A, B) ∈ [0, 100]`** |
| **BUG-003** | Prefix KV Cache | 每轮开新侦察会话重排头部 ContextPack，导致现代 LLM 的 Prefix KV Prompt Cache 100% 击穿 | **R-CTX-4 / R-CTX-5**：多轮对话**始终自复用当前 Session 本身**；`CtxCache` 按 `TagCtxShard` 规范字典序定序缓存并在会话中触发任务缓存；**`CtxCache` 容量与每次拿到的 `takeBudget` 均可动态调整** |
| **BUG-004** | 缓存触发粒度 | 离散 Tag 空间整包 `Cosine ≥ 0.9` 既高漏判（超集缓存被额外 Tag 稀释分母）又高误判 | **R-CTX-4 / R-CTX-6**：改为**按单 Tag 细粒度分片触发缓存（`TagCtxShard[tagType:tag]`）** + **非对称加权覆盖率（Tversky Recall `TagCoverage(Task, Cache) ≥ 90`）** |
| **BUG-005** | 写放大雪崩 | `DocApplied` 无差别触发全量索引重建与全部 Pack 失效，引发 O(N) 级联写放大风暴 | **R-CTX-6**：靠调整全局相关性算法分值与阈值抑制重建——**仅当 `Relevance(UpdatedDoc, B) ≥ rebuildThreshold`（缺省 75）时才标 stale 并触发重建**；侧车仅在定时导出 Git 时刷新 |
| **BUG-006** | 分数通胀与自写失控 | 连续 5 个同领域任务会把边缘文档 `importance` 刷到 100 挤出 L0 宪法；执行 Agent 自总结直接 Apply 无制衡 | **R-CTX-4 / R-CTX-7**：① 局部高频只调 `tagRelevance`；② 全局 `Importance` 乘以**跨任务多样性折扣** $w_{\text{div}}(T_i)=1-\max_{j<i}\text{Relevance}(T_i,T_j)/100$ + **L0 刚性保底 95** + **界面人类评论因子 `humanScore`**；③ 第三段异步产出正向归因（`used_effective / queried_irrelevant / missed_in_phase1`）与查重 Proposal（`Relevance ≥ 85` 合并），**必须经另一独立审核 Agent 裁决通过**后方可 Apply |
| **BUG-007** | 业务系统与财务账本 | 业务系统混入最外层根项目（单 `cored` 只挂单 `docsRoot`）；且把控制面带 `dedupWindow` 去重的 Event Bus 当成财务分录账本（Ledger） | **concepts/business-system.md / event.md 规则 17**：① `business-system` 不在最外层根项目中，单独设计，`sybran` 运行**第二个独立的 `cored` 与独立 `docs DB`**；② **高频业务流、财务分录与逐笔对账由业务代码承接，自己走自己的内部事件与账本**；外层控制面只收**系统级事件、报警事件、对账失败事件** |
| **BUG-008** | Scheme 粒度与代码触发 | 多 Scheme 塞进单文件耦合严重；改 Scheme 值何时免改代码、何时触发代码编译边界不清 | **R-DOC-8 / R-ENG-4**：① Scheme 按 `aspect: <xxx>` 细粒度拆分，**禁止多 Scheme 在一个文件**（仅 `import` 导入包例外，落库必拆单文件，checker=`lint/single-scheme.sh`）；② 只改已支持 Scheme 的值与行为描述免改代码，值不支持或改 Scheme 契约必触发代码改动 |
| **BUG-009** | 存储后端 | Git 工作树作运行时主存储存在并发锁与高频提交瓶颈 | **R-DOC-7**：默认权威切换为 **SQLite `docs DB`**（`--docs-backend sqlite` 缺省，root 禁选 git）；Git 作为定时按规则导出（含 `.md.metadatainfo`）并 push 远程的公开/备份格式 |

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule/rule.md](rule/rule.md)）。
