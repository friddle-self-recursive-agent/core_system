---
name: rule-pub
docType: Rule
scope: core_system
ownerRefs: [{kind: ServiceDesc, name: core_system}]
---
# Rule — 开发规范（R-PUB，公开暴露面）

> 所属：[rule.md](rule.md) 规则目录。规则 ID 全局稳定，拆分不改号。

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

## R-PUB-3 运行时产物不入公开仓；设计与验收基线分层

workflow loop 的验收报告与版本记录（`acceptance/loop-<seq>.md` 等）是**运行时临时文档**：落 core_system_instance `acceptance/` 根（.gitignore），**永不提交**；公开仓只保留机制性描述（core_system_instance runtime/acceptance.md）。

- **分层例外（2026-11-26 用户裁决）**：`acceptance/<主题>/` 下可提交**设计/验收基线文档**（如 `acceptance/console/console-ui.md`）——与运行时报告物理分层（根目录忽略，主题子目录入库）；每篇同样带 `.metadatainfo` 侧车（R-DOC-6）。
- 关键结论若影响设计，走文档更新提交（终态制），不走报告入库。

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](rule.md)）。
