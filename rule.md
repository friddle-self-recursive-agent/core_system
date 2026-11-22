---
name: doc-rule
docType: Rule
scope: core_system
ownerRefs: [{kind: ServiceDesc, name: core_system}]
---
# Rule — 概念文档终态制

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

---

# Rule — 工程规则

## R-ENG-1 默认代码语言

默认用 **Go / TS** 写代码：

| 层 | 语言 | 说明 |
|---|---|---|
| 控制面服务（cored/igniter/驱动/后台） | Go | workservice 仓默认 |
| dsh 插件 / 前端 / 脚本胶水 | TS（或 JS ESM） | dsh 生态是 ESM+JS；插件用 JS/TS 直写 |

其他语言只在该生态强约束时使用（如 dsh 插件生态内不用 Go）。

## R-ENG-2 数据库初始化幂等

涉及数据库（ops DB SQLite 等）的实现必须带**幂等初始化脚本**：建表/迁移随代码版本走，重复执行无副作用，冷启动时自动补齐（对齐 P4 幂等硬契约）。

## R-ENG-3 Connector 驱动仓库归属

connector 驱动代码按**来源**分仓，`core_system_workservice/connectors/` 只放 **builtin 驱动**：

| 类别 | 判据 | 仓库 | 例 |
|---|---|---|---|
| builtin | core_system 自带、自举必需、与具体部署用法无关 | core_system_workservice/connectors/ | gitfs、dsh |
| 用法型 | 按部署用法决定的对接目标（换了部署就换掉） | 部署侧独立仓，如 **sybran_usage_connector** | onedev、nas、oss |

- 判据看"是否换了部署就不复用"，不看"是否被 builtin 系统引用"——builtin 系统（developer/storage 等）引用 onedev/nas/oss 只是本部署的用法，驱动本身不进 workservice。
- 用法仓按 A38 命名解析引用（无前缀=默认 org）；WorkService.connector 面 impl/download 指向驱动实际所在仓。
- workservice 仓不 import 用法仓；依赖方向恒为 用法仓 → workservice（契约层五方法接口）。
- 通用 connector（跨部署复用、不绑单一部署用法，如通知/邮件）进 **common_connector** 仓；依赖方向同上。

---

# Rule — 开发规范（公开暴露面）

## R-PUB-1 公开仓不暴露个人信息

本仓及姊妹仓（core_system_instance / core_system_workservice / core_system_dsh_plugin 等一切公开仓库）**禁止出现**：

| 类别 | 禁止内容 | 公开文档写法 |
|---|---|---|
| 网络位置 | IP 地址（含 RFC1918 内网段）、内网主机名/内网域名 | "一台内网机器"、`<内网域名>` |
| 部署路径 | root/home 开头的真实绝对路径（如 root 下部署目录） | `<部署根目录>/` |
| 凭据 | key/token 取值、真实 provider baseURL、绑定个人账号的 env 变量名 | `<PROVIDER>_API_KEY` + 来源声明（env/EnvironmentFile） |
| 个人选型 | 具体厂商/模型选型（哪家用什么模型） | "任一 provider 的 X 档"（P8：机制不假设模型能力） |

- **判据**：读者不需要知道"部署在哪、用谁家的什么"即可理解设计。
- 例外：产品名/包名/服务名（dsh-core-agent、@deepseek-ai/dsh）、GitHub org 名——公开身份，保留；文档示例统一用 example.com 段（203.0.113.x / api.example.com）。
- 占位符约定固定四个：`<内网域名>`、`<部署根目录>`、`<PROVIDER>_API_KEY`、"X 档"表述，实际值只存在于 R-PUB-2 的决策台账。
- **运行时实例同此**：Provider/连接器的运行时配置（真实代理地址、账号密码、机器锚点）只存部署侧（本地配置/ops DB 或 friddle_decision.md），公开文档一律占位符 + secret 引用式描述（concepts/provider.md 规则 6：声明面与运行时面分离）。

## R-PUB-2 个人决策不入公开仓

涉及本人环境/账号/选型的**决策**（如 LLM provider 直连方案细节、部署机器锚点）一律记 **friddle_decision.md**（仓库根，已 .gitignore，永不提交；每份克隆自行补建）。公开文档只保留机制性结论，细节处标注占位符，占位符↔实际值对照表只在该文件维护。

## R-PUB-3 运行时产物不入公开仓

workflow loop 的验收报告与版本记录（`acceptance/loop-<seq>.md` 等）是**运行时临时文档**：落 core_system_instance `acceptance/`（.gitignore），**永不提交**；公开仓只保留机制性描述（core_system_instance runtime/acceptance.md）。关键结论若影响设计，走文档更新提交（终态制），不走报告入库。

---

# Rule — 规则类型（type）

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
- 首个落地：**R-PUB-1 → [lint/personal-info.sh](lint/personal-info.sh)**（IP/内网域名/部署路径/凭据名/个人选型扫描）。

## 规则索引（type 标注）

| ruleId | type | checker |
|---|---|---|
| R-DOC-* | policy | —（终态制靠人审+R-DOC 尾注存在性可 lint，暂缓） |
| R-ENG-* | policy | — |
| R-PUB-1 | **lint** | lint/personal-info.sh |
| R-PUB-2 | lint（部分） | personal-info.sh 扫 friddle_decision.md 残留引用 |
| R-PUB-3 | lint（目录级） | acceptance/ 在 .gitignore 即通过（checker 暂缓） |
| R-TYPE-* | policy | — |
