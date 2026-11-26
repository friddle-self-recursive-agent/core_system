---
name: doc-rule
docType: Rule
scope: core_system
ownerRefs: [{kind: ServiceDesc, name: core_system}]
---
# Rule — 规则目录（总文档）

| 项 | 值 |
|---|---|
| 形态 | **目录**：`rule/rule_xxx.md` 每篇描述一个方面；`rule/rule.md` 是规则集这个对象的总文档（本文件） |
| 作用域 | core_system（Builtin 规则） |
| 元数据 | 每篇文档旁附 `<name>.md.metadatainfo`（tag / tag_type / importance 0–100；R-DOC-6） |
| 状态 | 定稿（终态制，rule.md） |

## 1. 布局

| 文件 | 方面 | 规则组 |
|---|---|---|
| rule.md | 规则目录总文档：布局 / 编号 / 元数据 / 索引（本文件） | — |
| rule_doc.md | 文档规则：终态制 / 双仓承载 / 元数据侧车 | R-DOC-* |
| rule_eng.md | 工程规则：语言 / 幂等 / 代码归属 | R-ENG-* |
| rule_ux.md | 人机交互：对话 / scheme / 用户视角 / 报告主界面 / 工作台 | R-UX-* |
| rule_ctx.md | 上下文与记忆：索引 / 检索 / tag / 缓存 | R-CTX-* |
| rule_pub.md | 公开暴露面：脱敏 / 决策台账 / 运行时产物 | R-PUB-* |
| rule_type.md | 规则类型与 checker 契约 + 规则索引 | R-TYPE-* |

## 2. 文档模型（rule 也是一个文档）

1. **规则集是一个文档对象**：`rule/rule.md` 是它的总文档（frontmatter / scope / ownerRefs 齐全）；`rule_xxx.md` 是同一对象的分册，每篇也各自是 `docType: Rule` 的文档，可单独引用、检索、校验、带侧车。
2. **一个文件一个方面**：新增方面=新增 `rule_<aspect>.md` 并在 §1 登记；不改他人文件。
3. **ID 全局稳定**：`R-<组>-<n>` 跨文件唯一、只增不改号；拆文件不改 ID；跨方面引用写 ruleId（如 R-CTX-3）。
4. **总文档不重复条款**：本文件只放布局 / 编号 / 元规则 / 索引；条款正文只在方面文件中（单一真相）。
5. **规则类型与 checker**：`type: policy|lint` 与 checker 契约见 [rule_type.md](rule_type.md)；lint 型必须有代码实现。
6. **元数据侧车**：每篇 `.md` 旁 `<name>.md.metadatainfo` 保留 `tags`（`{tag, tag_type}`）与 `importance`（0–100，满分 100）；缺失/非法=lint 红（R-DOC-6，checker=`../lint/metadatainfo.sh`）。
7. **导出保留**：GitHub 导出/镜像带 `rule/` 目录与侧车；索引只链接，不复制条款。

## 3. 索引

- 规则类型/checker 总表：[rule_type.md](rule_type.md)「规则索引（type 标注）」
- 文档规则：[rule_doc.md](rule_doc.md)
- 工程规则：[rule_eng.md](rule_eng.md)
- 人机交互：[rule_ux.md](rule_ux.md)
- 上下文与记忆：[rule_ctx.md](rule_ctx.md)
- 公开暴露面：[rule_pub.md](rule_pub.md)

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](rule.md)）。
