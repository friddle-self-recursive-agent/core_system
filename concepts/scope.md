# Scope — 四层作用域与名字解析

| 项 | 值 |
|---|---|
| K8s 对照 | Namespace（+ 集群级/命名空间级资源二分，扩展为四分） |
| 形态 | metadata.scope 字段的枚举值 + 解析规则 |
| 作用域 | 自身即规则 |
| 状态 | 设计稿 v1 |

## 1. 定义

Scope 解决"这个东西归谁、在哪儿找"。四层只有**归属与名字解析**语义（v0.5，A37：准入严格度不是 scope 的内生属性，治理档位由 权限系统 规则配置，可按 scope/origin 匹配）：

| 层 | 值 | 住哪 | 语义 | 例 |
|---|---|---|---|---|
| Builtin | `builtin` | core/、systems/builtin/ | **起源标记**：core_system 自带开发（v0.5） | builtinRoot、Scheme、自带三系统 |
| Global | `global` | global/ | 全局共享 | Agent、Connector、Bind、WorkService、Ref |
| System | `<system-name>` | systems/<name>/ | 系统私有域 | 该系统的文档 |
| Instance | `<system>/<instance>` | systems/<s>/instances/<i>/ | 实例私有域 | ImplDoc、DriftReport |

## 2. 名字解析规则（就近遮蔽）

引用一个名字（如 `connectors/gitlab-driver`）时，从引用者所在层逐层向外找，命中即停：

```
Instance → System → Global → Builtin
```

允许低层遮蔽高层（系统私有 Connector 覆盖全局同名），禁止跨枝引用他人 System 内部对象（要引用先提升为 Global 或走 Ref）。

## 3. 边界

**是**：归属规则 + 解析顺序 + 准入档位映射。

**不是**：
- 不是物理隔离（都在一个 git 库，逻辑隔离靠 权限系统）；
- 不是 Label（selector.md：Label 是横向选择，Scope 是纵向归属，二者正交——"找出所有 domain=ci 的系统"用 Label，"这个文档属于哪个系统"用 Scope）；
- 不是权限模型本体（权限是 P7 并集，Scope 只决定默认准入档位）。

## 4. 生命周期

对象创建时定 scope，之后不可改（改归属=删除重建+级联，走 Finalizer）。

## 5. 与其他概念的关系

- 权限系统 按 scope 档位取默认准入策略。
- Ref 的"属于哪个 System 还是 Global"（原稿问题）= `metadata.scope` 取值问题，由创建者按"谁依赖它"就近声明。
- Builtin 是四层之一，仅起源标记（builtin.md v0.5）。

## 6. 设计规则

1. scope 不可变；改名/迁移=重建。
2. 就近遮蔽只许收敛能力（子域覆盖必须是更受限版本），不许放大权限。
3. 跨系统依赖只允许三种形态：引用 Global 对象、被 Apply 提案、Ref 指路。
4. 每层目录结构由 instance 仓 layout.md 固化，目录即 scope（文件系统天然实现了解析路径）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 遮蔽导致调试困惑 | ⚠️ 低 | 名字命中哪层不直观 | 所有引用解析结果记录进审计；`core resolve <name>` 调试命令 |
| 逻辑隔离被 git 权限绕过 | ⚠️ 中 | 有仓库写权限的人可改任何 scope | v1 承认（单库）；权限系统 在 Apply 层拦；多库/子模块列入远期 |

**结论：可行。目录即 scope 让 v1 零成本实现。**

## 8. 原始设计标注

- 原稿"----global----"与"Ref 属于哪个 System 还是 Global" → 本概念正式化。

## 9. 待决问题

见 open-questions.md#scope

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
