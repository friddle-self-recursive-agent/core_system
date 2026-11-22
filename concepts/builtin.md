# Builtin — 起源标记（core_system 自带开发）

| 项 | 值 |
|---|---|
| K8s 对照 | kube-system（仅类比"随系统自带"这一点；不带特权语义） |
| 形态 | 标记：`scope: builtin`（居住地）+ 起源语义"core_system 系统本来开发" |
| 状态 | 定稿（终态制，rule.md） |

## 1. 定义

Builtin 用来标记**"这是 core_system 系统本来开发的"**，仅此而已。具体说：对象随 core_system 的代码仓一起开发、随默认代码一起带出——例如默认代码中带了最基础的 `builtin_developer_system`、`builtin_deploy_system`、`builtin_storage_system`，以及 SelfRecursiveCore、builtin-connector、builtin-user-system。

builtin 的内容就是**最基础的循环调用代码**：使用某个基座（如 agent dsh）所必需的、内置于默认代码的最小调用实现。它们不是永久专属：未来可被**复杂真实系统取代**——install service 装入成熟系统（如 developer-system 换成 onedev 实装）后，对应 builtin 项退位为可替换的默认实现（见 §4）。

它**不携带任何对 Scheme/Service 的要求**（与"每一个 Scheme/Service 必须怎样"无关）。强制文档类型、必带级别、准入严格度，是 **Scheme（DocType 注册）和每个 Service 自己强调的事情**，不是 Builtin 概念的内生属性。

## 2. 边界

**是**：起源标记 + 居住地约定（core/ 与 systems/builtin/ 目录）+ 基础循环调用代码的默认实现。

**不是**（早期错误设计，已删）：
- 不携带强制文档类型（必带级别归 DocType 注册与 Service 自身声明，doctypes/README.md §3）；
- 不携带准入档位（治理档位是权限系统规则的事，可按 origin/scope 匹配配置）；
- 没有"Builtin 成员"受管集合（只有"谁随代码自带"这个事实）；
- 不是权限（origin 与权限无关；权限仍是 P7 并集 + 权限系统）。

**唯一相关硬规则**：builtinRoot 不可删除——这是保护特定关键对象的权限系统硬规则，不是 Builtin 类的类级规则。

## 3. 结构

```yaml
# 无独立对象。表达方式：
metadata:
 scope: builtin # 居住地（core/ 或 systems/builtin/）
 labels:
 core/origin: builtin # 起源标记（权限系统可按此匹配治理规则，可选）
```

## 4. 生命周期

对象随 core_system 代码仓诞生（内置系统=代码和 connector 内置，在 workservice 仓）→ 升级随代码发版走（文档侧变更仍走 Apply）→ **可被安装的复杂真实系统取代**：install service 装入成熟系统后，同能力的 builtin 项降级为默认/回退实现，去留按各 Service 自己的声明处理 → 第三方后来合入 core_system 代码仓的系统，是否标 builtin 属命名/治理约定（open-questions）。

## 5. 与其他概念的关系

- Scope（concepts/scope.md）：builtin 是四层 scope 之一，但**只有归属与名字解析语义**，无严格度语义。
- DocType/Service：必带文档级别由它们自己声明。
- 权限系统：要给"自带物"配人审可以，写规则匹配 `core/origin: builtin` 即可——配置层的事。
- Builtin 起源的对象清单：self-recursive-core、developer/deploy/storage 三系统、builtin-connector、builtin-user-system、builtinRoot、Scheme 本体。

## 6. 设计规则

1. Builtin 只回答"从哪来"（core_system 自带开发），不回答"必须怎样"。
2. 任何把要求（必带文档/人审/成员审批）绑死在 Builtin 概念上的设计即违宪（本文件 就是反例）。
3. 起源标记用 scope+label 双表达：scope 管住哪，label 供 权限系统 匹配。
4. builtinRoot 不可删为独立硬规则（保护关键对象），不泛化为类规则。
- 终态制：本文档只展示最终结果，变更历史只在 annotations.md（[rule.md](../rule.md) R-DOC-1/3）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 起源边界模糊 | ⚠️ 低 | 后来合入代码仓的算不算 builtin | open-questions 列项；建议判据=是否随默认代码发版 |
| 治理配置无处安放 | ⚠️ 低 | 原靠 builtin 硬管的场景 | 权限系统 规则按 origin label 配置（等能力、不同机制） |

**结论：可行。概念变简单了，删掉的治理语义在 权限系统/DocType/Service 层都有正确归宿。**

## 8. 待决问题

见 open-questions.md#builtin

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
