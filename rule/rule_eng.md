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
- 存量仓（common_connector / sybran_usage_connector）按新命名逐步迁移（迁移期双轨；新代码一律 `connectops-*`）。
- **宿主工具面贡献不算 connector 驱动**（E5b 归属裁决）：agent-comm 四 op 工具是 core_system_dsh_plugin 对 dsh 宿主 `ctx.tools.register` 的贡献——进程内通道、无独立通信栈，工具宿主=plugin 仓本体，不建新仓；声明集种子（ConnectorOps/WorkService 对象）是文档库数据，非代码。

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](rule.md)）。
