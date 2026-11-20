# Selector — 标签选择器

| 项 | 值 |
|---|---|
| K8s 对照 | Label / LabelSelector |
| 形态 | metadata.labels + 查询语法（相等/集合） |
| 作用域 | 全局横向 |
| 状态 | 设计稿 v1 |

## 1. 定义

Label 是贴在任何对象上的键值元数据；Selector 是按 Label 选对象的表达式。用途三处：

1. **事件路由**：Event.selector 匹配到哪些 Loop/Agent（Scheme.dispatch 用）；
2. **依赖匹配**：ServiceDesc 按 `capabilities` 标签选用 WorkService（不点名）；
3. **观测聚合**：观测面按 Label 聚合（"所有 domain=ci 系统的 drift 数"）。

## 2. 边界

**是**：横向查询的元数据。

**不是**：
- 不是身份（身份=Kind+name+scope；Label 可变，身份不可变）；
- 不是 Scope（纵向归属，见 scope.md §3）；
- 不是权限（改 Label 不改权限；但高危 Label 如 `tier=control-plane` 变更属 权限系统 敏感项）；
- 不携带语义承诺：Label 不保证对象真有该能力（能力承诺在 WorkService.capabilities 与 Connector.contract，Label 只是索引）。

## 3. 结构

```yaml
metadata:
  labels:
    domain: ci
    tier: exec
    capabilities: scm,ci-trigger    # 复合值用逗号（v1 简化，不求表达式完备）

# 查询
{domain: ci}                        # 相等
{domain: in [ci,cd]}                # 集合
```

## 4. 生命周期

随对象创建/更新（走 Apply）；删除对象即消失。无独立生命周期。

## 5. 与其他概念的关系

- Event 路由、Desc→WorkService 能力匹配、观测聚合三处消费。
- Scheme.dispatch 的缺省路由也用 Selector 表达（"凡 domain=devtools 的 ExternalChanged → developer-system 的 Loop"）。

## 6. 设计规则

1. Label 值受约束（小写字母数字中划线，复合逗号分隔），v1 不做表达式引擎。
2. 保留 Label 前缀 `core/*`（系统用）：`core/tier`、`core/capabilities`。
3. 修改 `core/*` 前缀 Label 属敏感变更（权限系统 加档）。
4. 选择不到任何对象不报错（空集合法），但 dispatch 空集要留痕（审计）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| Label 腐化/拼写漂移 | ⚠️ 低 | domain=CI vs ci | 取值建议注册枚举（Scheme 可维护推荐值表），Lint 告警未注册值 |
| 复合值表达能力弱 | ⚠️ 低 | v1 故意从简 | 够用为先，表达式引擎留 v2（登记 open-questions） |

**结论：可行，无风险。**

## 8. 原始设计标注

- 原稿无此概念（补充）：事件"分发"与"汇总观测"都需要它，缺了这两处就要硬编码。

## 9. 待决问题

见 open-questions.md#selector

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
