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
- 已落地：**R-PUB-1 → [lint/personal-info.sh](../lint/personal-info.sh)**（IP/内网域名/部署路径/凭据名/个人选型扫描）；**R-DOC-6 → [lint/metadatainfo.sh](../lint/metadatainfo.sh)**（每篇文档侧车存在性与字段合法性）；**R-ENG-7 → [lint/max-file-lines.sh](../lint/max-file-lines.sh)**（单文件 ≤800 行硬上限，rule/rule_eng.md）。

## R-TYPE-3 规则验证模式：code→scheme→ConnectorOps；agent→丢规则给 agent（2026-11-26 用户裁决）

> 用户原话：「rule中代码的。->scheme->代码[ConnectorOps一个新的实现来实现代码级别审核]」「rule为agent的就是丢规则agent验证」「workflow代码开发流程看看有验证这个节点」。

1. **每条规则必须声明验证模式**：`code | agent | human`（缺省 `human`/policy）；不允许"无验证"的规则生效。
2. **code 三段链**：Rule 条目（`mode: code` + `checker`）→ Scheme `runtime.ruleChecks`（ruleId→checker/参数/severity 的机读注册表）→ **`connectops-code-audit` ConnectorOps 实现**（deploy-system 的 `connectops-code-audit` 仓，R-ENG-3 生命周期：声明→代码→build 生效→运行时，每次变更必提交）。三段 ruleId 双向可追。
3. **agent 就是丢规则**：`mode: agent` 的规则不做代码 checker；把规则原文（ref+hash）+ diff/上下文丢给指定 agent/服务 agent 验证，返回结构化 verdict + 证据；`unverified` 不算通过。
4. **Verify 节点必备**：dev-delivery 等代码开发流程的 `Verifying` 相位必须执行 code 规则审核（ConnectorOps）与 agent 规则验证；缺失=流程缺陷/unbound，不得跳过或默认通过。
5. **审核只读、验证≠批准**：`code-audit` 不改代码/不提交/不 Apply；验证通过不替代 Human/Gate 审批。
6. **失败显式**：checker 未注册/超时/崩溃、agent 不可用、verdict 不确定——显式失败或降级，不静默放行。

判据：Rule 条目有 mode；code 规则在 `ruleChecks` 有行且 checker 在册；Verify 输出含 code findings + agent verdict（或显式 unbound）；`error` finding/`fail` verdict 阻断 Deploy；同一 ruleId 在 Rule/Scheme/实现三处可追。

## 规则索引（type 标注）

| ruleId | type | checker |
|---|---|---|
| R-DOC-1..5 | policy | —（终态制靠人审+R-DOC 尾注存在性可 lint，暂缓） |
| R-DOC-6 | **lint** | lint/metadatainfo.sh（全仓 tracked `.md` 侧车与 0–100 分值） |
| R-DOC-7 | policy | —（sqlite 默认/git 导出；启动参数与导出任务由部署验收探针判定） |
| R-DOC-8 | **lint** | lint/single-scheme.sh（禁止单文件多 Scheme；导入落库必拆单文件单 Scheme；细粒度 `aspect`） |
| R-DOC-9 | policy | —（`ServiceDesc` ↔ `ServiceInstance` 设计/实现文档 1:N `[metadata 关联]` `trace` 双向追踪与过期检测） |
| R-DOC-10 | policy | —（Bug 文档为中间临时产物；任务完成且 Verify 验证 OK 后直接删除对应条目或整个 `bug.md` 临时文档） |
| R-ENG-1..4 | policy | —（R-ENG-4 Scheme 值修改免改代码 vs 契约改动必触发代码构建） |
| R-ENG-7 | **lint** | lint/max-file-lines.sh（单文件≤800 行——代码/标记语言全适用；dist 与 lockfile 豁免） |
| R-PUB-1 | **lint** | lint/personal-info.sh |
| R-PUB-2 | lint（部分） | personal-info.sh 扫 friddle_decision.md 残留引用 |
| R-PUB-3 | lint（目录级） | acceptance/ 根在 .gitignore、acceptance/<主题>/ 入库；checker 暂缓 |
| R-TYPE-* | policy | —（R-TYPE-3 的 `ruleChecks`/`connectops-code-audit` 由 Verify/CI 判据；实现落地后可转 lint） |
| R-CTX-* | policy | —（tag 核心索引/两段会话/缓存为运行期机制；pack 记录可审计，lint 暂缓） |
| R-UX-* | policy | —（界面文案/结构判据进 prep 探针与 DOM 断言，见 core_system_instance acceptance/console/console-ui.md §13.4/§14.7） |

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](rule.md)）。
