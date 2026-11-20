# Scheme — 类型注册表

| 项 | 值 |
|---|---|
| K8s 对照 | client-go scheme + CRD 注册机制 |
| 形态 | 一份数据文档（core/scheme.yaml）+ Core 内的内存索引 |
| 作用域 | Builtin |
| 状态 | 设计稿 v1 |

## 1. 定义

Scheme 是所有"可存在之物"的类型注册表：**对象类型**（Agent、ServiceDesc、Connector…）、**文档类型**（Goal、Rule、Metrics…，见 DocType）、**事件类型**。未注册的类型，Core 拒绝存储、Event 拒绝路由、Agent 拒绝引用——这是防止文档面腐化的第一道闸门。

同时承担**事件路由表**职责（A15：原稿"event loop 查看 dsh"的 dsh 理解为 Dispatch 索引，并入本概念，不单独造词）：

```yaml
# core/scheme.yaml（节选）
apiVersion: core/v1
kind: Scheme
metadata:
  name: default
  scope: builtin
spec:
  version: core/v1
  kinds:
    - {kind: Agent,          storage: global/agents/<name>/agent.yaml}
    - {kind: ServiceDesc,    storage: systems/<name>/system.yaml}
    - {kind: ServiceInstance,storage: systems/<s>/instances/<name>/instance.yaml}
    - {kind: WorkService,    storage: workservices/<name>/workservice.yaml}
    - {kind: Connector,      storage: global/connectors/<type>/connector.yaml}
    - {kind: Ref,            storage: global/refs/<name>.yaml}
    - {kind: Bind,           storage: global/binds/<name>.yaml}
    - {kind: Credential,     storage: "仅引用，明文不入库"}
  docTypes:                   # 引用 doctypes/README.md 的注册表
    - Goal / Desc / Rule / WorkflowDesign / Metrics / DataDesign /
      DataMetrics / Auth / DeployDesign / CodeDesign /
      ImplDoc / VerifyDoc / DriftReport
  eventTypes:
    - {type: ExternalChanged, source: connector, route: owner-instance-loop}
    - {type: MetricThreshold, source: metrics,  route: selector-match-loop}
    - {type: DocApplied,      source: core,     route: owner-loop}
    - {type: ApprovalNeeded,  source: policy,   route: bind-human}
    - {type: HeartbeatLost,   source: core,     route: parent-agent}
  dispatch:                   # “dsh”：事件如何找到处理者
    - {on: ExternalChanged, for: workservice/gitlab, dispatch: instances/*/loops/*}
```

## 2. 边界

**是**：数据 + 索引。Core 启动时载入内存，变更走 Apply。

**不是**：
- 不是 Core 进程（A13）；
- 不校验内容（校验是 Policy 按 Scheme 注册的 schema 做，Scheme 只登记 schema 引用）；
- 不产生 Event（只在 Event 已发生后查表路由）。

## 3. 生命周期

bootstrap 时由 builtinRoot 写入首版 → 之后只能**追加与扩容**（加新类型、加可选字段），破坏性变更需新版本号 `core/v2` 并保留 v1 兼容期（与 CRD 版本策略一致）。Scheme 自身修改属 Builtin 级准入（默认人审）。

## 4. 与其他概念的关系

- DocType 是 Scheme 里 `docTypes` 段的展开定义（DocType=CRD，Scheme=注册中心）。
- Event 产生后由 Core 按 Scheme.dispatch 路由。
- Core 启动自检：文档库中所有对象的 GVK 必须能在 Scheme 命中，否则启动失败（防野对象）。

## 5. 设计规则

1. 一类一注册：同一种能力出现两个未合并的注册项即违宪（P10）。
2. 存储路径写进注册项（对象落在哪个目录由 Scheme 决定，instance 仓 layout.md 与之对齐）。
3. 类型演进只加不改：删字段、改语义必须升版本。
4. dispatch 表必须穷举事件类型的缺省路由；路由不到的事件进死信（DeadLetter）并告警，不允许静默丢弃。

## 6. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 事件路由表随规模膨胀 | ⚠️ 低 | 系统×事件类型组合多 | 缺省路由 + Selector 匹配，不逐系统枚举 |
| 版本演进复杂度 | ⚠️ 中 | 文档类型改版牵连所有存量文档 | 只加不改策略 + 存量兼容期 + 迁移由 Loop 执行 |
| dsh 语义误解（A15） | ⚠️ 低 | 原稿 dsh 若另有所指需重定义 | 已并入 dispatch；待用户裁决 |

**结论：可行，成熟模式（CRD 注册的翻版）。**

## 7. 原始设计标注

- A15：dsh → dispatch 索引，并入 Scheme。

## 8. 待决问题

见 open-questions.md#scheme

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
