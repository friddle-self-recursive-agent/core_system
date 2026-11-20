# Builtin — 内部标记与最严作用域

| 项 | 值 |
|---|---|
| K8s 对照 | kube-system namespace + 系统级准入白名单 |
| 形态 | 一种 scope 值 + 一组强制规则（不是进程、不是注册表，A13） |
| 作用域 | 自身即作用域 |
| 状态 | 设计稿 v1 |

## 1. 定义

Builtin 是"这是控制面自己的东西"的标记。被打上 `scope: builtin` 的对象：builtinRoot Agent、Core 的自描述、Scheme、根 Credential 引用。它们管理其他一切，因此对它们的修改采用**全系统最严准入**。

原稿"内部基础系统配置，即用来标注是内部的"落为此设计。

## 2. 边界

**是**：一个 scope 枚举值 + 该 scope 的强制文档类型集 + 最严准入策略。

**不是**：
- 不是 Core（进程）也不是 Scheme（数据），只是标记（A13）；
- 不是"内置功能目录"：内置的**功能**（如 dsh Connector）仍是普通 Global 对象，只是由官方维护；Builtin 只留给控制面自身。

## 3. 结构

```yaml
# 规则集中于 core/builtin.policy.yaml
scope: builtin
members:                         # 白名单式成员管理，新成员需人审
  - agent/builtinRoot
  - system/core                  # Core 自描述
  - scheme/default
mandatoryDocTypes:               # Builtin 特例：强制文档类型（原稿要求）
  - Goal
  - Desc
  - Rule
  - Auth
defaultDocTypes:                 # 默认建议携带
  - Metrics
  - DataDesign
optionalDocTypes:                # 可选
  - 其余全部已注册类型
admission:
  default: human-review          # 一切修改默认人审
  forbidden:                     # 硬禁止（Policy 硬编码，配置改不动）
    - delete agent/builtinRoot
    - disable scheme
    - remove Auth docType from mandatory
```

## 4. 生命周期

bootstrap 时由点火器写入首批成员 → 新成员进入 = 高危变更（人审+双人复核可选）→ 成员退出几乎不允许（finalizer 保护）。

## 5. 与其他概念的关系

- Scope 四层之一（builtin > global > system > instance 的准入严格度序）。
- Policy 读取它的成员表决定准入档位。
- builtinRoot 是它的第一个成员，也是唯一硬编码不可删的对象。

## 6. 设计规则

1. Builtin 成员数保持个位数；膨胀即设计坏味（控制面该瘦）。
2. `forbidden` 清单在 Policy 里**硬编码兜底**，文档侧配置只能收紧不能放宽——防止"改文档→放宽→自毁"递归。
3. Builtin 对象的 Loop 参数（重试/升级）最保守：任何失败直接 Escalate，不自动修复自己。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 硬编码与声明式原则张力 | ⚠️ 低 | "一切皆文档" vs 少数硬规则 | 显式写进 P9 最小自举原则：点火器+forbidden 清单是被承认的例外 |
| Builtin 文档类型强制集过死 | ⚠️ 低 | 控制面自身想加自定义文档 | optional 段全开放，只强制最小集 |

**结论：可行。纯治理设计，无技术风险。**

## 8. 原始设计标注

- A13：Core/Scheme/Builtin 三分（进程/数据/标记）。
- 原稿"Builtin 有默认文档类型、强制文档类型、可选文档类型描述" → §3 三段清单。

## 9. 待决问题

见 open-questions.md#builtin

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
