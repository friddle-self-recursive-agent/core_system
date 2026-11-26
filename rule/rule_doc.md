---
name: rule-doc
docType: Rule
scope: core_system
ownerRefs: [{kind: ServiceDesc, name: core_system}]
---
# Rule — 文档规则（R-DOC）

> 所属：[rule.md](rule.md) 规则目录。规则 ID 全局稳定，拆分不改号。

## R-DOC-1 终态展示

概念文档（concepts/*.md）**只展示最终结果**：定义、边界、结构、生命周期、关系、设计规则、可行性、待决问题、审阅标注区。

**不展示**：版本号（v0.x）、修正轮次（R1–R12）、A-编号引用、"原始设计标注"等任何变更叙事。读者拿到的就是当前有效的设计，不需要拼装演进史。

## R-DOC-2 历史的唯一去处

变更历史只在 **git 提交历史**（概念文档无台账文件；裁决记录随提交信息留痕）。概念被删除/合并时不留墓碑文件，直接从 concepts/ 移除。

## R-DOC-3 按概念落规则

每个概念文档的"设计规则"一节末行固定携带本条：

> 终态制：本文档只展示最终结果，变更历史只在 git 历史（rule.md）。

## R-DOC-4 适用范围

- **适用**：concepts/ 全部概念文档、concepts/README 索引。
- **不适用**：requirements/（原稿存档）、open-questions.md（活问题清单）、git 历史（唯一历史）。

## R-DOC-5 双仓承载与目录分层（2026-11-26 用户裁决）

每一份设计**两仓承载、缺一不可**：

| 仓 | 承载 |
|---|---|
| **core_design**（GitHub `core_system`） | 概念与规则：concepts/、rule/、core/scheme.yaml（声明面权威） |
| **core_system_instance** | 机读落地口径：runtime/*.md（流程/接口/判据）、acceptance/<主题>/ 设计/验收基线（如 console-ui） |

- 改设计=**两仓同步提交并 push**（触发 loop 下轮 pull 对账收录）；只改一侧=未完成。
- 概念文档与 runtime/acceptance 文档头部互相回链（概念→落地口径；落地→概念依据）。
- **目录按用途分层**（可多文件夹区分）：`runtime/`=机制与接口；`acceptance/<主题>/`=设计/验收基线（入库）；`acceptance/` 根=运行时验收报告（loop-*.md，不入库，见 R-PUB-3）。

## R-DOC-6 元数据侧车与 0–100 全局统一标度（2026-11-26 用户裁决）

每一份文档 `<name>.md` 在其同目录携带 `<name>.md.metadatainfo`（严格同名 + `.metadatainfo` 后缀），作为系统内部索引元数据（SQLite `docs DB` / `DocIndex`）的**导出快照与外部索引载体**：

| 字段 | 形态 | 说明 |
|---|---|---|
| `tags` | `[{tag, tag_type, relevance?}]` | 至少 1 个；每个 tag 归属唯一 tagType（R-CTX-3）；可选 `relevance`（int 0–100，文档对该 tag 的相关度，缺省 80） |
| `importance` | int 0–100 | 重要度分，满分 100（由基准分 + 界面人类评论因子 `human_score` + 跨任务多样性经验分合成，见 R-CTX-4） |
| `human_score` | `?int 0–100` | 可选；界面审核时人工给出的评论/重要度锚定分（有值时优先锚定 `importance`） |
| `trace` | `?{requires?, implements?, verifies?, implemented_by?, verified_by?}` | 可选；`ServiceDesc` 设计文档与 `ServiceInstance` 实现/验证文档之间的 **1:N `[metadata 关联]` 双向设计追踪**（见 R-DOC-9） |

- **系统内部权威 + 侧车导出**：正文以 `.md`（或 SQLite `doc.content`）为准（单一真相）；tag / relevance / importance 在系统内部维护并随第三段总结 Session 的 Rerank（经独立审核 Agent 与人类评论因子裁决）动态更新；侧车是导出至 Git 工作树/GitHub 镜像时的元数据载体（R-DOC-7 定时导出时同步刷新侧车，不会反向触发写放大）。
- **导出保留**：GitHub 导出/镜像必须带侧车；侧车随文档同目录、同提交；搬文档=搬侧车。
- **生成与校验**：由 DocIndex/打标/导出流程生成或校正；缺侧车、字段非法、孤儿侧车=红，checker=`lint/metadatainfo.sh`。
- **全系统统一 0–100 标度**：文档 `importance`、`tagRelevance`、`affinity`、事件分诊 `importance`（event.md 规则 16）、以及全局相关性函数 `Relevance(A, B)` **一律统一为 `0–100` 标度**（消灭旧 1–5 与 0–1 混用）。
- **初始 tag_type 词表**：`domain` / `mech` / `surface` / `lifecycle` / `doc`（开放；只增不改名，沿 R-CTX-3）。
- 判据：全仓 tracked `.md` 均有合法侧车；`tags` 非空且每项有 `tag`+`tag_type`（`relevance` 若出现必为 0–100 整数）；`importance`（及可选 `human_score`）为 0–100 整数。

## R-DOC-7 文档库默认 sqlite；git=导出/公开（2026-11-26 用户裁决）

> 用户原话：「Git 文档库 后期就是内置系统的导出和存储而已。默认调整为sqlite吧。然后后面就是定时按规则导出然后push远程」「Root不能选git了。就sqlite+本地storage。git就是相当于output导出然后public」。

1. **默认权威=sqlite**：文档内容权威=docs DB（`--docs-backend sqlite` 缺省；`doc` 表 `(kind,scope,name)` + `resourceVersion` 乐观锁），本地 storage 承载文件/产物；新建部署不再以 git 为权威。
2. **git=导出/公开格式**：git 布局只作**导出/公开**（output/public）：按规则定时从 sqlite 导出工作树（含 `.md.metadatainfo` 侧车）→ commit → push 远程；git 历史=导出快照，**不是逐次写账本**。
3. **root 不得选 git**：core_system（root）部署固定 sqlite + 本地 storage，启动参数不得出现 `--docs-backend git`；兼容期非 root 部署可显式 `--docs-backend git`，迁移后同上。
4. **逐次内容历史=sqlite 侧待补**：当前 `apply_log` 有操作流水（谁/何时/哪个 rv/结果），但无逐次正文快照；`GET /v1/rev-content` 在 sqlite 后端诚实降级（503），不得冒充。补 `doc_history` 表或等价读面为下一段。
5. **导出不阻塞写路径**：导出/推送失败只告警并留痕，不回滚 sqlite 写；导出频率/目标/分支=部署侧配置，规则写在本仓、实际值不入公开仓。
6. **迁移**：`--docs <旧git布局根>` 对空库一次性种子导入，保留各对象 `resourceVersion`；非空库不导入（幂等）。
7. 判据：cored stderr 有 sqlite 后端锚（`文档库已挂载 db=…（sqlite 后端…）`）；首启种子导入行；同一 apply 全周期（create→noop→409）在 sqlite 全绿；root 启动参数无 `--docs-backend git`；导出任务产出 git commit 且 push 成功（失败可见）。

## R-DOC-8 Scheme 单文件单对象与细粒度 Aspect（2026-11-26 用户裁决）

> 用户原话：「scheme可以设计拆的更细更多方面。aspect: xxxx」「禁止多scheme再一个文件。除非导入scheme。自己保存的不允许多scheme在一个文件」。

1. **禁止多 Scheme 在一个文件（自己保存的权威文件）**：系统自身保存的任何 Scheme / TaskScheme 文件（含 git 导出布局与 docsRoot 下的 `.yaml`），**严格一文件一 Scheme 对象**（禁止在单文件内用 `---` 拼接多个 Scheme，也禁止把多个独立 Scheme 塞入同一文件）。
2. **导入例外（仅限导入输入源）**：外部导入（`import`）允许接收多 Scheme 聚合文件作为输入包，但**导入落库/保存时必须自动拆分为单文件单 Scheme**（每对象独立 `(kind, scope, name)` 与独立存储路径）。
3. **按 `aspect: <xxx>` 细粒度拆分**：Scheme 与 TaskScheme 支持声明 `aspect: <xxx>`（如 `aspect: kinds` / `docTypes` / `eventTypes` / `dispatch` / `runtime` / `context` / `build` / `verify` / `reconcile` 等），按方面细粒度拆分管理與触发（见 concepts/scheme.md §5 规则 7–8）。
4. **type: lint**：checker=`lint/single-scheme.sh`（扫描全仓 `.yaml` 中 `kind: Scheme` / `kind: TaskScheme` 文档数，单文件出现 >1 个 Scheme 对象即红）。

## R-DOC-9 ServiceDesc 与 ServiceInstance 设计↔实现文档 1:N `[metadata 关联]` 追踪（2026-11-26 用户裁决）

> 用户原话：「其中 systemdesc 和 systeminstance 有些设计文档和实现文档是一对N关系。要能做设计跟踪到[metadata关联]」。

1. **1:N 映射关系**：`ServiceDesc` 下的 1 篇设计文档（`Goal` / `Desc` / `Rule` / `CodeDesign` / `DataDesign` / `WorkflowDesign` 等）在落地上往往对应 **N 篇** `ServiceInstance` 侧的实现文档（`ImplDoc`）或验证文档（`VerifyDoc`）（跨多实例或同一实例内跨多模块/子仓）；反之 1 篇 `ImplDoc` 亦可关联多篇设计文档的指定章节（`N:M`，以设计→实现 `1:N` 为主轴）。
2. **`[metadata 关联]` 双端结构（frontmatter `metadata.trace` + 侧车 `<doc>.md.metadatainfo` `trace` 段 + SQLite `DocIndex`）**：
   - **实现/验证文档端（`ImplDoc` / `VerifyDoc`，N 端主动声明）**：
     - `trace.implements: [{doc: "<设计文档 URI/路径>", sections?: ["<章节/条款锚点>"], designRev?: "<对齐时的设计 rv/sha>"}]`
     - `trace.verifies: [{doc: "<设计或实现文档 URI/路径>", sections?: ["<条款锚点>"], targetRev?: "<rv/sha>"}]`
   - **设计文档端（`ServiceDesc` 文档，1 端自动聚合）**：
     - 可选声明 `trace.requires: [ImplDoc, VerifyDoc]`（声明必须具备下游实现/验证覆盖）；
     - `DocIndex` 与定时导出器自动反向聚合生成 `trace.implemented_by: [{doc, instance, sections?, status: synced|stale}]` 与 `trace.verified_by: [...]`（完整呈现 1 对 N 实现矩阵）。
3. **版本漂移（Suspect Link）与孤儿设计（Orphan）自动检测**：
   - 当 1 端设计文档更新（`resourceVersion` / `blobSha` 推进），系统沿 `trace.implemented_by` 将关联的全部 N 篇下游 `ImplDoc` / `VerifyDoc` 标为 `status: stale`（并在 `Relevance(A,B)` 中赋予结构耦合先验满分 `100`），驱动 Workflow 对账生成 `DriftReport`；
   - 声明了 `trace.requires` 但 `implemented_by` 为空的设计文档/章节，对账自动报警为「孤儿设计（Orphaned Design）」。
4. **工作台可视**：通用对象工作台（R-UX-7）打开任一设计或实现文档时，直接展示 `1:N` / `N:1` 的 `trace` 关联树与 `synced | stale` 状态徽章，点击即可跨 `ServiceDesc ↔ ServiceInstance` 跳转。

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](rule.md)）。
