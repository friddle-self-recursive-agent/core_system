# Builtin — 起源标记（core_system 自带开发）

| 项 | 值 |
|---|---|
| K8s 对照 | kube-system（仅类比"随系统自带"这一点；不带特权语义） |
| 形态 | 标记：`scope: builtin`（居住地）+ 起源语义"core_system 系统本来开发" |
| 状态 | 设计稿 v0.5（R4 修正：原"最严作用域+强制文档集"语义错误，A37） |

## 1. 定义

Builtin 用来标记**"这是 core_system 系统本来开发的"**，仅此而已。具体说：对象随 core_system 的代码仓一起开发、随默认代码一起带出——例如默认代码中带了最基础的 `builtin_developer_system`、`builtin_deploy_system`、`builtin_storage_system`，以及 SelfRecursiveCore、builtin-connector、builtin-user-system。

它**不携带任何对 Scheme/Service 的要求**（R4：与"每一个 Scheme/Service 必须怎样"没有关系）。强制文档类型、必带级别、准入严格度，是 **Scheme（DocType 注册）和每个 Service 自己强调的事情**，不是 Builtin 概念的内生属性。

## 2. 边界（v0.5 重划）

**是**：起源标记 + 居住地约定（core/ 与 systems/builtin/ 目录）。

**不是**（v0.2 的错误设计，已删）：
- ~~强制文档类型三档~~（必带级别归 DocType 注册与 Service 自身声明，doctypes/README.md §3）；
- ~~默认人审/最严准入~~（治理档位是 Policy 规则的事，可按 origin/scope 匹配配置，但不是概念自带）；
- ~~成员白名单管理~~（没有"Builtin 成员"这种受管集合；只有"谁随代码自带"这个事实）；
- 不是权限（origin 与权限无关；权限仍是 P7 并集 + Policy）。

**保留的唯一硬规则**：builtinRoot 不可删除——这是保护**特定关键对象**的 Policy 硬规则，不是"Builtin 类对象"的类级规则。

## 3. 结构

```yaml
# 无独立对象。表达方式：
metadata:
  scope: builtin          # 居住地（core/ 或 systems/builtin/）
  labels:
    core/origin: builtin  # 起源标记（Policy 可按此匹配配置治理规则，可选）
```

## 4. 生命周期

对象随 core_system 代码仓诞生（R1.3：内置系统=代码和 connector 内置，在 workservice 仓）→ 升级随代码发版走（文档侧变更仍走 Apply）→ 第三方后来合入 core_system 代码仓的系统，是否标 builtin 属命名/治理约定（open-questions）。

## 5. 与其他概念的关系

- Scope（concepts/scope.md）：builtin 是四层 scope 之一，但**只有归属与名字解析语义**，无严格度语义。
- DocType/Service：必带文档级别由它们自己声明（A37）。
- Policy：要给"自带物"配人审可以，写规则匹配 `core/origin: builtin` 即可——配置层的事。
- Builtin 起源的对象清单（v0.5）：self-recursive-core、developer/deploy/storage 三系统、builtin-connector、builtin-user-system、builtinRoot、Scheme 本体。

## 6. 设计规则

1. Builtin 只回答"从哪来"（core_system 自带开发），不回答"必须怎样"。
2. 任何把要求（必带文档/人审/成员审批）绑死在 Builtin 概念上的设计即违宪（本文件 v0.2 就是反例，A37）。
3. 起源标记用 scope+label 双表达：scope 管住哪，label 供 Policy 匹配。
4. builtinRoot 不可删为独立硬规则（保护关键对象），不泛化为类规则。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 起源边界模糊 | ⚠️ 低 | 后来合入代码仓的算不算 builtin | open-questions 列项；建议判据=是否随默认代码发版 |
| 治理配置无处安放 | ⚠️ 低 | 原靠 builtin 硬管的场景 | Policy 规则按 origin label 配置（等能力、不同机制） |

**结论：可行。概念变简单了，删掉的治理语义在 Policy/DocType/Service 层都有正确归宿。**

## 8. 原始设计标注

- A37（R4）：Builtin=起源标记；原 v0.2 的"最严作用域+强制文档集+成员白名单"删除；要求归 Scheme/Service 自身。
- R0 原稿"Builtin 有默认/强制/可选文档类型"由本修正覆盖（档位定义移至 doctypes/README.md §3）。

## 9. 待决问题

见 open-questions.md#builtin

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
