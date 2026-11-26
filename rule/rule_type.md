---
name: rule-type
docType: Rule
scope: core_system
ownerRefs: [{kind: ServiceDesc, name: core_system}]
---
# Rule — 规则类型（R-TYPE）

> 所属：[rule.md](rule.md) 规则目录。规则 ID 全局稳定，拆分不改号。

## R-TYPE-1 每条规则可带 type

Rule 文档内的每条规则条目可携带 `type` 字段（缺省 `policy`）：

| type | 含义 | 执行方式 |
|---|---|---|
| `policy`（缺省） | 设计/流程约束，需语义判断 | 人审 + Workflow 巡检 |
| `lint` | 可机械判定的约束（正则/结构可查） | **必须挂 checker 代码**，Apply/CI 时运行，违规即拒绝/报警 |

**一旦 type=lint，必须有代码实现**：checker 放 core_system（本仓 `lint/` 或 workservice `lint/`），体量大或跨仓共用时独立成仓。没有 checker 的 lint 规则=未生效，Apply 拒绝注册。

## R-TYPE-2 checker 契约

- 双向可追溯：规则条目写 `checker: lint/<name>.sh`，checker 头部注释回指 ruleId。
- lint 只做机械判定，判不准的留在 policy（可行性：正则/结构校验成本低；风险=规则改了 checker 没改，靠 ruleId 回指 + 巡检比对压住）。
- 已落地：**R-PUB-1 → [lint/personal-info.sh](../lint/personal-info.sh)**（IP/内网域名/部署路径/凭据名/个人选型扫描）；**R-DOC-6 → [lint/metadatainfo.sh](../lint/metadatainfo.sh)**（每篇文档侧车存在性与字段合法性）。

## 规则索引（type 标注）

| ruleId | type | checker |
|---|---|---|
| R-DOC-1..5 | policy | —（终态制靠人审+R-DOC 尾注存在性可 lint，暂缓） |
| R-DOC-6 | **lint** | lint/metadatainfo.sh（全仓 tracked `.md` 侧车） |
| R-ENG-* | policy | — |
| R-PUB-1 | **lint** | lint/personal-info.sh |
| R-PUB-2 | lint（部分） | personal-info.sh 扫 friddle_decision.md 残留引用 |
| R-PUB-3 | lint（目录级） | acceptance/ 根在 .gitignore、acceptance/<主题>/ 入库；checker 暂缓 |
| R-TYPE-* | policy | — |
| R-CTX-* | policy | —（tag 核心索引/两段会话/缓存为运行期机制；pack 记录可审计，lint 暂缓） |
| R-UX-* | policy | —（界面文案/结构判据进 prep 探针与 DOM 断言，见 core_system_instance acceptance/console/console-ui.md §13.4/§14.7） |

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](rule.md)）。
