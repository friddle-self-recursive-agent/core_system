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
