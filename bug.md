---
name: architecture-and-runtime-bugs
docType: VerifyDoc
scope: core_system
ownerRefs: [{kind: ServiceDesc, name: core_system}]
---
# Bug 与架构矛盾清算基线（bug.md · 临时文档）

> **[临时文档 / R-DOC-10 生命周期约定]**：正式设计中不一致的地方就是这些 Bug，本文件属于驱动修复与验收的**中间临时产物**。当某项任务完成并经 Verify 验证 OK 后，对应 Bug 条目即刻删除；**当全部条目验证 OK 后，本文件（含 `bug.md.metadatainfo` 侧车）直接 `git rm` 删除**，正式设计仓只保留收敛一致的终态文档。
> 所属：core_design 概念与规则对账基线；配套运行时验收落点见 core_system_instance `acceptance/bugs/bug.md` 与 `runtime/acceptance.md`（R-DOC-5 双仓同步）。

## 1. 架构矛盾与后期隐患清算总表（BUG-001 ~ BUG-014，验证 OK 后即删）

| 编号 | 领域 | 发现的矛盾 / 不足 / 后期隐患 | 裁决方案与落点规则 |
|---|---|---|---|
| **BUG-001** | 会话与上下文 | `agent.md`（按需自取）、`agent-service-protocol.md`（Catalog 预插）、`context.md`（两段式 RAG）三套机制并存打架 | **R-CTX-4 / R-CTX-8**：统一为**三段式逻辑 Session**（①第一段侦察：预插基础命令+目录 Index，按 Tag 触发 `TagCtxShard`，仅对差量 Tag 拉取 Tag/TagRule/四族/Event/**近期相关 Session** → ②第二段执行：会话自复用+JIT 增量更新 → ③第三段**异步**总结演化：提 Proposal / 正向归因补缓存 / 防刷分 Rerank + **独立审核 Agent 裁决**） |
| **BUG-002** | 打分标度 | 文档 `importance`（0–100）、事件/会话 `importance`（1–5）、`tagRelevance`/`affinity`（0–1）三套标度混用，缺统一相关性基元 | **R-CTX-3 / R-DOC-6**：全系统分值（含事件 `importance` 与界面人类评论因子 `humanScore`）**统一为 `0–100`**；定义唯一全局相关性函数 **`Relevance(A, B) ∈ [0, 100]`** |
| **BUG-003** | Prefix KV Cache | 每轮开新侦察会话重排头部 ContextPack，导致现代 LLM 的 Prefix KV Prompt Cache 100% 击穿 | **R-CTX-4 / R-CTX-5**：多轮对话**始终自复用当前 Session 本身**；`CtxCache` 按 `TagCtxShard` 规范字典序定序缓存并在会话中触发任务缓存；**`CtxCache` 容量与每次拿到的 `takeBudget` 均可动态调整** |
| **BUG-004** | 缓存触发粒度 | 离散 Tag 空间整包 `Cosine ≥ 0.9` 既高漏判（超集缓存被额外 Tag 稀释分母）又高误判 | **R-CTX-4 / R-CTX-6**：改为**按单 Tag 细粒度分片触发缓存（`TagCtxShard[tagType:tag]`）** + **非对称加权覆盖率（Tversky Recall `TagCoverage(Task, Cache) ≥ 90`）** |
| **BUG-005** | 写放大雪崩 | `DocApplied` 无差别触发全量索引重建与全部 Pack 失效，引发 O(N) 级联写放大风暴 | **R-CTX-6**：靠调整全局相关性算法分值与阈值抑制重建——**仅当 `Relevance(UpdatedDoc, B) ≥ rebuildThreshold`（缺省 75）时才标 stale 并触发重建**；侧车仅在定时导出 Git 时刷新 |
| **BUG-006** | 分数通胀与自写失控 | 连续 5 个同领域任务会把边缘文档 `importance` 刷到 100 挤出 L0 宪法；执行 Agent 自总结直接 Apply 无制衡 | **R-CTX-4 / R-CTX-7**：① 局部高频只调 `tagRelevance`；② 全局 `Importance` 乘以**跨任务多样性折扣** $w_{\text{div}}(T_i)=1-\max_{j<i}\text{Relevance}(T_i,T_j)/100$ + **L0 刚性保底 95** + **界面人类评论因子 `humanScore`**；③ 第三段异步产出正向归因（`used_effective / queried_irrelevant / missed_in_phase1`）与查重 Proposal（`Relevance ≥ 85` 合并），**必须经另一独立审核 Agent 裁决通过**后方可 Apply |
| **BUG-007** | 业务系统与财务账本 | 业务系统混入最外层根项目（单 `cored` 只挂单 `docsRoot`）；且把控制面带 `dedupWindow` 去重的 Event Bus 当成财务分录账本（Ledger） | **concepts/business-system.md / event.md 规则 17**：① `business-system` 不在最外层根项目中，单独设计，`业务实例` 运行**第二个独立的 `cored` 与独立 `docs DB`**；② **高频业务流、财务分录与逐笔对账由业务代码承接，自己走自己的内部事件与账本**；外层控制面只收**系统级事件、报警事件、对账失败事件** |
| **BUG-008** | Scheme 粒度与代码触发 | 多 Scheme 塞进单文件耦合严重；改 Scheme 值何时免改代码、何时触发代码编译边界不清 | **R-DOC-8 / R-ENG-4**：① Scheme 按 `aspect: <xxx>` 细粒度拆分，**禁止多 Scheme 在一个文件**（仅 `import` 导入包例外，落库必拆单文件，checker=`lint/single-scheme.sh`）；② 只改已支持 Scheme 的值与行为描述免改代码，值不支持或改 Scheme 契约必触发代码改动 |
| **BUG-009** | 存储后端 | Git 工作树作运行时主存储存在并发锁与高频提交瓶颈 | **R-DOC-7**：默认权威切换为 **SQLite `docs DB`**（`--docs-backend sqlite` 缺省，root 禁选 git）；Git 作为定时按规则导出（含 `.md.metadatainfo`）并 push 远程的公开/备份格式 |
| **BUG-010** | Event 分层与 Scope 隔离 | 底层 `Heartbeat` 事件缺一等注册或混入默认界面淹没注意力；Event 缺一等 `metadata.scope` 且 Agent 处理 Event 未约束 `eventScopes` 导致跨系统串台风险 | **event.md 规则 18–19 / agent.md 规则 8**：① 注册一等 `Heartbeat` 事件，与 `ReconcileTick` 等同划入 `tier: infra` + **`visibility: default-hidden`（默认不展示）**，异常失活 `HeartbeatLost`/`SessionStalled` 为 `tier: attention` 默认上屏；② Event 强制带四层 `metadata.scope`，Agent 声明 `spec.eventScopes`，派发与消费双侧强制校验 `event.metadata.scope ∈ agent.spec.eventScopes` |
| **BUG-011** | 设计↔实现 1:N 追踪 | `ServiceDesc` 设计文档与 `ServiceInstance` 实现/验证文档存在 **1:N** 映射，缺乏 `[metadata 关联]` 导致设计变更时无法自动定位哪 N 篇 `ImplDoc` 过期（腐化说谎） | **R-DOC-9 / servicedesc.md 规则 5 / serviceinstance.md 规则 5**：在 frontmatter `metadata.trace` 与 `<doc>.md.metadatainfo` 侧车建立双向 `1:N` 关联（`ImplDoc/VerifyDoc` 声明 `trace.implements` / `verifies` + `designRev`，`DocIndex` 自动反向聚合至设计文档 `trace.implemented_by` / `verified_by`）；设计更新自动标下游 N 篇实现文档 `stale` 并赋相关性结构耦合满分 `100` |
| **BUG-012** | 回滚分类与文档描述 | 原 `undo: full\|partial\|none` 过于笼统，未区分**要不要回滚**、**四类回滚主体**以及**回滚文档描述**，易导致不可逆操作被盲目回滚或复杂半成品无文档硬退 | **workservice.md 规则 8 / task-scheme.md 规则 8 / workflow.md 规则 19**：显式声明 `rollback: {policy: never\|auto\|ask\|optional, type: irreversible\|code\|agent\|human, description, docRef?}`——先定要不要回滚（可 ask），再按**根本无法回滚 (`irreversible`) / 代码回滚 (`code`) / Agent 读文档回滚 (`agent`) / 人按文档回滚 (`human`)** 分派，且强制附带回滚文档描述 |
| **BUG-013** | 并发冲突任务裁决 | 两个同时冲突的任务在落地时若静默重试或后写覆盖，会破坏一致性或后台互踩 | **apply.md 规则 7 / task-scheduler.md 规则 11 / workflow.md 规则 20**：两个冲突任务在 **`Apply` 这一关就会因乐观锁被拦下**（保障最终一致）；第一个任务 Apply 后，第二个任务判断有无实质冲突，**一旦有冲突直接询问上级 Agent 或人类：「暂停第一个任务 (`pause-first`) 还是放弃当前任务 (`abort-current`)？」** |
| **BUG-014** | 外部内容可信度检验 | 内部系统与外部第三方数据源未在 `Provider`/`ConnectorOps` 层区分 `trustLevel`，外部返回内容未经检验直入 Context 存在注入/污染风险 | **provider.md 规则 9 / connector.md 规则 10 / workflow.md 规则 21**：**默认内部系统都是可信的（`trustLevel: trusted`）**；外部系统 `Provider` 和 `ConnectorOps` 添加 `trustLevel: external` 字段；在 **Workflow 级别可配置 `trustGate`（`mode: code \| agent`）**，由外部检验 Agent 或代码先判断一遍内容是否 OK 后再放行 |

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule/rule.md](rule/rule.md)）。
