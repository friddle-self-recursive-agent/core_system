---
name: rule-eng
docType: Rule
scope: core_system
ownerRefs: [{kind: ServiceDesc, name: core_system}]
---
# Rule — 工程规则（R-ENG）

> 所属：[rule.md](rule.md) 规则目录。规则 ID 全局稳定，拆分不改号。

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

**代码承载的部署能力按小概念归 deploy-system 的 git 仓库**（2026-11-24 用户裁决，取代按来源分仓的旧口径）：

| 项 | 口径 |
|---|---|
| 归属 | 凡以代码承载的部署能力（ConnectorOps 驱动、通道适配、工具型 skill 实现等）一律归 **deploy-system**（默认实现=default-deploy-system）管理的 git 仓库 |
| 命名 | 按小概念建仓 `connectops-<concept>`：如 `connectops-chrome`、`connectops-dsh`、`connectops-opencode`、`connectops-gh`（builtin 系统默认使用 github → 该仓） |
| 生命周期 | 声明（docs/scheme）→ 仓库代码 → **build 生效** → 运行时；**每次变更必定提交**（override 亦同，github 等远端一样走提交，不存在"运行时改代码"） |
| 构建产物 | digest 入账（幂等，P4）；未 build 生效的实现不得被运行态引用（缺口可见=`execution=unbound`） |
| 豁免 | core_system 引擎本体（workservice/plugin）不在此列；随引擎打包的最小驱动（gitfs/dsh 等）保留在 `core_system_workservice/connectors/` 并注明理由 |

- 依赖方向恒为：deploy-system 仓 → workservice 契约层（connectors 五方法接口），反向禁止。
- 旧口径的"用法型/通用型"分类由本模型吸收：分仓判据=是否属于**部署能力代码**，不以跨部署复用性区分。
- 存量仓（common_connector / 部署侧用法仓）按新命名逐步迁移（迁移期双轨；新代码一律 `connectops-*`）。
- **宿主工具面贡献不算 connector 驱动**（E5b 归属裁决）：agent-comm 四 op 工具是 core_system_dsh_plugin 对 dsh 宿主 `ctx.tools.register` 的贡献——进程内通道、无独立通信栈，工具宿主=plugin 仓本体，不建新仓；声明集种子（ConnectorOps/WorkService 对象）是文档库数据，非代码。

## R-ENG-4 Scheme 值修改 vs 触发代码改动的判定边界（2026-11-26 用户裁决）

> 用户原话：「这里面我理解的。假如代码不需要改动的。只需要改动scheme的值和行为描述的。假如scheme值不支持或者shceme改动。那就必须触发相应代码改动了。所以我觉得逻辑很合理。scheme可以设计拆的更细更多方面。aspect: xxxx」。

1. **只改已支持的 Scheme 值与行为描述 → 免改代码、声明即生效**：
   - 当用户或 Agent 编排新流程/调整系统行为时，若现有代码驱动与 `aspect` 契约已支持该能力，**只需修改 Scheme / TaskScheme 的值、参数组合或行为描述**；
   - 经 Apply 写入 SQLite `docs DB` 后即时生效，**不新建/修改代码仓库，不触发重编译**（彻底保留 TaskScheme 声明式编排的敏捷性）。
2. **Scheme 值不被现有代码支持或 Scheme 契约本身改动 → 必触发代码改动**：
   - 当改动引入了现有代码不支持的枚举值/驱动 `op`/新参数，或修改/新增了某 `aspect` 的 Scheme 结构契约（`scheme 改动`）时，系统将其判定为 `execution=unbound / scheme-contract-changed`；
   - **必须自动触发对应的代码改动任务**（按 `aspect` 路由至 `core_system_workservice` 或 `connectops-<concept>` 仓库修改代码、build 生效并提交 git）。

## R-ENG-5 多任务并发调度（2026-11-26 用户裁决）

1. **无关才并发**：无依赖 + `touches` 写集不相交 + `exclusive` 不冲突，才允许同时开 agent；任一不满足=串行/blocked。
2. **默认保守、可调**：`scheme.runtime.taskScheduler` 的 `maxConcurrent/perService/perRepo/leaseTtl` 可经 Apply 调整；单任务 `limits` 只收紧不放宽。
3. **隔离工作区**：代码任务用 worktree/branch；落地走合并队列；不得并发写 main。
4. **每任务一 session**：宿主 spawn 桥固定命令/参数，载荷不进 shell；单飞 + 租约 + 幂等。
5. **失败隔离**：失败只阻塞依赖者，无关任务继续；重试上限后 failed+Escalate，不静默重试。
6. **可观测**：Task.status + `TaskStateChanged` + 任务中心；会话/工作流/节点可互跳。

判据：两个无依赖且写集不相交的任务并发 running；同 repo 默认串行；调整上限后生效且留痕；失败任务不拖垮无关任务；任务中心可见阻塞原因。

## R-ENG-6 并发工作分支与 worktree 规约（2026-11-26 用户裁决）

> 用户原话：「看看其他session 都移动到agent/xxx agent开头。不要放到根目录」。

1. **分支命名**：一切并发/agent 工作分支一律 `agent/<name>` 前缀（`agent/scheduler`、`agent/console`…）；不得裸用 `docs/*`、`feat/*` 等散名；`main` 只收合并结果（根目录=main 不留未合并工作）。
2. **worktree 位置**：worktree 一律放项目根下的 `worktrees/<repo>/<branch-slug>`（如 `self-recursive-agent/worktrees/core_system_workservice/agent-scheduler`），**不放系统临时目录根（/tmp 等）与仓库工作树内**——临时目录会被清理、散放会与其他会话互撞。
3. **生命周期**：合并进 main 后立即 `git worktree remove`；分支保留至确认无回滚需要再删；未合并的 worktree 不得强删。
4. **判据（机读）**：`git worktree list` 每仓只剩主线；`git branch` 无 `docs/*|feat/*` 类散名；`worktrees/` 下每个子目录对应在册 agent 分支。

## R-ENG-7 单文件行数硬上限（2026-11-26 用户裁决）

一切代码文件（`.go`/`.ts`/`.js`/`.jsx`/`.tsx`/`.css`/`.html`/`.sh`/`.py`/`.mjs`/`.cjs` 等一切代码与标记语言）**不允许超过 800 行**（含注释与空行；生成产物 `dist/` 构建输出与 lockfile 豁免）。

1. **超限必须拆分**：Go 按职责拆文件/子包；TS/JS 按模块/屏拆；CSS 按组件域拆。拆分原则=**单一职责、命名可寻址、不改行为**（重构零语义变化）。
2. **checker**：[lint/max-file-lines.sh](../lint/max-file-lines.sh)（type=lint，机械可判）：`git ls-files` 遍历 tracked 代码文件，awk 数行，>800 即红并输出文件名与行数；豁免词形=`dist/`、`*.lock`、`pnpm-lock.yaml`、`package-lock.json`、`go.sum`。
3. **判据（机读）**：① lint 脚本 exit 0；② 超限文件清单为空；③ 新增文件默认受检（受检集合=git ls-files，无需登记）；④ 豁免仅限构建产物与 lockfile。

## R-ENG-8 临时/验证文件规约（2026-11-26 用户裁决）

> 用户原话：「记得临时文件，验证文件。gitignore记得不提交。默认在仓库内也放到tmp下」。

1. **位置**：一切临时文件与验证产物（截图、探针脚本、一次性 fixture、构建旁产物）默认放**仓库内 `tmp/` 目录**——不放仓库根、不放系统 /tmp（会被清理且跨会话互撞，理由同 R-ENG-6 worktree 规约）。
2. **永不入库**：`tmp/` 与常见临时产物词形（根级 `*.jpeg`/`*.png` 等）必须进 `.gitignore`；验证截图等验收证据若需长期留存，改放 `acceptance/<主题>/` 走正式文档入库（instance 仓分层例外），不冒充临时文件。
3. **checker**：mode=agent——agent 侧自查：产生临时文件即落 `tmp/`；`git status` 出现根级临时词形即移入；提交前 `git status --short` 零意外 untracked。
4. **判据（机读）**：① 各仓 `.gitignore` 含 `tmp/`；② `git status --short` 无根级截图/临时产物；③ 临时文件唯一合法仓库内位置=`tmp/`。

## R-ENG-9 数据零编造（2026-11-28 用户裁决）

> 用户原话：「显示不需要展示不编造。默认就是不编造数据。这是规则。数据不要编造。」

**默认就是不编造数据**——一切展示/投影/统计/报告/产物面，缺省=只呈现真实存在的数据；没有数据就诚实显示没有。

1. **展示面**：无数据=诚实空态（「暂无 / 0 / —」显式缺席词形），禁止一切假数据（假模板卡、假历史账、幽灵词条、占位假数字、写死的示例值）；空态不得冒充有内容。
2. **投影/统计面**：count/列表/时间线一律来自真实账目源（事件账/run 账/会话账/对象库），不推算、不脑补、不编造默认值；投影缺席=显式 null/「缺席」标注（「不冒充空对象」口径），缺口如实可见。
3. **Agent/LLM 产物**：判决、摘要、报告只依据真实输入（被审物原文/账目/对象现势）；输入不可得=显式「（被审物不可读 / 缺席）」占位，不编造内容冒充真实判断（审批判决 subject 占位即先例）。
4. **修复方向**：数据缺失的修复=修数据链（投影注册/心跳回写/快照字段补全），**不是展示侧造数兜底**——「core-headless 相关任务/会话恒空」类问题修投影断链，不在前端造卡充数。
5. **判据（机读）**：① 任一展示数值可溯源到真实账目源；② 展示层零硬编码示例数据/零 mock 充数（fixtures 仅限测试）；③ 空态语义=真实缺席且可见；④ LLM 产物含显式不可得占位而非虚构。

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](rule.md)）。

