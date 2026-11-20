# DocType — 文档类型注册（本系统的 CRD）

| 项 | 值 |
|---|---|
| K8s 对照 | CustomResourceDefinition：文档类型 = 自定义资源类型 |
| 形态 | doctypes/ 注册表（core/scheme.yaml 的 docTypes 段展开） |
| 作用域 | Builtin（注册表本身），类型可被各层使用 |
| 状态 | 设计稿 v1 |

## 1. 定义

"文档皆对象"（P1）的实现机制：每一种文档都是一个 Kind，必须先注册才能入库。注册内容：必填段、scope 规则、强制级别（按系统类别）、谁可写、准入档位。**新增一种文档类型 = 注册一个 DocType，不需要改任何代码**——这就是本系统的扩展模型，与 K8s 加 CRD 不加代码同构。

## 2. 边界

**是**：文档类型的元定义（schema 引用 + 治理属性）。

**不是**：
- 不是 Scheme（Scheme 是注册中心总表，DocType 是其中文档类型的定义条目展开；关系=CRD 机制与单个 CRD 的关系）；
- 不执行校验（校验是 Policy 按 DocType 登记的 schema 引用做）；
- 不限制散文内容：只约束**必须存在的结构段**（如 Goal 必须有"验收条款"段），段内是自然语言——结构化骨架+自然语言血肉。

## 3. 结构

```yaml
# doctypes/goal.yaml（一个 DocType 注册项）
apiVersion: doc.core/v1
kind: DocType
metadata:
  name: Goal
spec:
  appliesTo: {kinds: [ServiceDesc], scopes: [global, builtin]}
  required:                        # 必填段（Policy 校验）
    - intent                       # 意图陈述
    - acceptance                   # 验收条款（可验证）
  writers: [human, bind-role:owner] # 默认写者（Agent 默认无权）
  admission: normal | strict
  mandatory:                       # 强制级别（按 scope）
    builtin: required
    global: required
  lifecycle: versioned             # 变更走 Apply，generation 联动
```

## 4. 生命周期

注册（Builtin 级准入，人审）→ 生效（Policy 据此校验入库文档）→ 演进（只加不改：加可选段可以，改必填段含义必须升版本 Goal/v2 并留迁移期）→ 废弃（tombstone，存量文档只读）。

## 5. 与其他概念的关系

- ServiceDesc 的文档集、Instance 的实现侧 Docs，类型全部来自这里。
- Policy 是它的执法者；Scheme 是它的登记处。
- 内置首批类型清单见 doctypes/README.md（Goal、Desc、Rule、WorkflowDesign、Metrics、DataDesign、DataMetrics、Auth、DeployDesign、CodeDesign、ImplDoc、VerifyDoc、DriftReport、Runbook）。

## 6. 设计规则

1. 每个类型必须声明 `writers`，默认最窄（人/owner）。
2. 必填段控制在 ≤3 个：文档类型的职责是"防缺关键段"，不是"格式化写作"。
3. 同一语义不允许两个类型（A1 教训：Prometheus 型被并入 Metrics 型就是本规则的应用）。
4. `acceptance` 类可验证段是 Loop 的 Verifying 依据——**没有验收条款的 Goal 不予入库**（servicedesc.md 可行性的核心缓解）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 自然语言段无法机器校验 | ⚠️ 中 | 段存在≠段合格 | 分级校验：结构段 Policy 硬校验；语义质量由 Loop 分析阶段评估并计入 drift |
| 类型 proliferation | ⚠️ 低 | 人人想加新类型 | 注册=Builtin 级人审，天然高门槛 |
| 模板僵化 | ⚠️ 低 | 必填段过死 | 规则 2 限段数；anotations 可放自由内容 |

**结论：可行。结构化骨架+自然语言血肉的折中是本设计对"文档面向人又面向机"的核心回答。**

## 8. 原始设计标注

- A1/A2：原稿类型清单经本机制整理（去重、改名、补 Instance 侧类型）。

## 9. 待决问题

见 open-questions.md#doctype

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
