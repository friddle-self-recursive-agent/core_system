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

变更历史只记录在 [annotations.md](annotations.md) 的 A-清单（裁决台账：问题→决议→涉及文档→状态）。概念被删除/合并时不留墓碑文件，直接从 concepts/ 移除，台账记档即可。

## R-DOC-3 按概念落规则

每个概念文档的"设计规则"一节末行固定携带本条：

> 终态制：本文档只展示最终结果，变更历史只在 annotations.md（rule.md）。

## R-DOC-4 适用范围

- **适用**：concepts/ 全部概念文档、concepts/README 索引。
- **不适用**：annotations.md（它就是历史）、concept-review.md（复审记录）、requirements/（原稿存档）、open-questions.md（问题演进允许带上下文）。

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
