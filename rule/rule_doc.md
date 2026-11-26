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

## R-DOC-6 元数据侧车（2026-11-26 用户裁决）

每一份文档 `<name>.md` 在其同目录携带 `<name>.md.metadatainfo`（严格同名 + `.metadatainfo` 后缀），作为导出/索引元数据载体：

| 字段 | 形态 | 说明 |
|---|---|---|
| `tags` | `[{tag, tag_type}]` | 至少 1 个；每个 tag 归属唯一 tagType（R-CTX-3） |
| `importance` | int 0–100 | 重要度分，满分 100 |

- **侧车不存正文**：正文仍以 `.md` 为准（单一真相）；侧车只承载索引/导出元数据。
- **导出保留**：GitHub 导出/镜像必须带侧车；侧车随文档同目录、同提交；搬文档=搬侧车。
- **生成与校验**：由 DocIndex/打标流程生成或校正；缺侧车、字段非法、孤儿侧车=红，checker=`lint/metadatainfo.sh`。
- **尺度**：文档重要度=0–100；事件分诊的 `importance`（event.md 规则 16）仍是 1–5，两者不混用。
- **初始 tag_type 词表**：`domain` / `mech` / `surface` / `lifecycle` / `doc`（开放；只增不改名，沿 R-CTX-3）。
- 判据：全仓 tracked `.md` 均有合法侧车；`tags` 非空且每项有 `tag`+`tag_type`；`importance` 为 0–100 整数。

## R-DOC-7 文档库默认 sqlite；git=导出/公开（2026-11-26 用户裁决）

> 用户原话：「Git 文档库 后期就是内置系统的导出和存储而已。默认调整为sqlite吧。然后后面就是定时按规则导出然后push远程」「Root不能选git了。就sqlite+本地storage。git就是相当于output导出然后public」。

1. **默认权威=sqlite**：文档内容权威=docs DB（`--docs-backend sqlite` 缺省；`doc` 表 `(kind,scope,name)` + `resourceVersion` 乐观锁），本地 storage 承载文件/产物；新建部署不再以 git 为权威。
2. **git=导出/公开格式**：git 布局只作**导出/公开**（output/public）：按规则定时从 sqlite 导出工作树 → commit → push 远程；git 历史=导出快照，**不是逐次写账本**。
3. **root 不得选 git**：core_system（root）部署固定 sqlite + 本地 storage，启动参数不得出现 `--docs-backend git`；兼容期非 root 部署可显式 `--docs-backend git`，迁移后同上。
4. **逐次内容历史=sqlite 侧待补**：当前 `apply_log` 有操作流水（谁/何时/哪个 rv/结果），但无逐次正文快照；`GET /v1/rev-content` 在 sqlite 后端诚实降级（503），不得冒充。补 `doc_history` 表或等价读面为下一段。
5. **导出不阻塞写路径**：导出/推送失败只告警并留痕，不回滚 sqlite 写；导出频率/目标/分支=部署侧配置，规则写在本仓、实际值不入公开仓。
6. **迁移**：`--docs <旧git布局根>` 对空库一次性种子导入，保留各对象 `resourceVersion`；非空库不导入（幂等）。
7. 判据：cored stderr 有 sqlite 后端锚（`文档库已挂载 db=…（sqlite 后端…）`）；首启种子导入行；同一 apply 全周期（create→noop→409）在 sqlite 全绿；root 启动参数无 `--docs-backend git`；导出任务产出 git commit 且 push 成功（失败可见）。

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](rule.md)）。
