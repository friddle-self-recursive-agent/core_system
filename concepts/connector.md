# Connector — ConnectorOps / ConnectorProvider（v0.3 拆分）

| 项 | 值 |
|---|---|
| K8s 对照 | Provider≈CSI driver 实现（类型+代码绑定）；Ops≈VolumeAttachment/StorageClass（挂载使用） |
| 形态 | 两个 Kind：`ConnectorProvider`（类型标注+代码绑定，Global）+ `ConnectorOps`（操作挂载，Global/System/Instance） |
| 状态 | 设计稿 v0.3（R2 修正：原单一 Connector 拆为两个，A25） |

## 1. 定义（为什么拆）

原单一 Connector 混了两件事：**"这类驱动由什么代码实现"**（类型层）和**"这个系统挂了一份什么样的操作"**（使用层）。拆开：

- **ConnectorProvider**（类型层）：支持什么类型（types 标注）、具体对应什么代码或工具（impl 绑定）、契约支持度（get/plan/apply/verify/watch/undo）。纯注册，不含环境信息。
- **ConnectorOps**（使用层）：挂载在 global 或某个 service/instance 里的"一份可调用操作"。引用一个 Provider，加上环境（endpoint/config/credential）、暴露的 op 子集、绑定的 Workflow。**Agent 默认挂 ConnectorOps**（不是直接挂 Provider）。

默认供给：builtin 服务 `builtin-connector`（systems/builtin/connector/）提供全局默认 ops（gitfs/dsh/http 等通用操作）；**每个 ServiceInstance 可以自己实现自己的 ConnectorOps**（就近遮蔽，scope 规则）——"builtin service: connector，每个 service instance 自己实现这个 connector"。

**使用要权限**：Agent 能调哪些 ops = 其引用的 ConnectorOps 并集，再被 Policy 裁剪（P7）。

## 2. 边界

**Provider 是**：类型注册项（Scheme 闸门管它）；**不是**：不含 endpoint/凭证/工作流。

**Ops 是**：一份可调用的操作（环境+子集+Workflow）；**不是**：不是代码本体（代码在 Provider 的 impl）；不做业务判断。

**二者都不是**：不是外部系统本体（WorkService）、不是 Plugin（Plugin 扩展 dsh 自身，Ops 对接外部）。

## 3. 对象结构

```yaml
# 类型层：global/connectors/onedev-driver/provider.yaml
apiVersion: core/v1
kind: ConnectorProvider
metadata:
  name: onedev-driver
  scope: global
spec:
  types: [scm, ci]                       # 支持什么类型（类型标注）
  impl: {repo: workservice, path: connectors/onedev}   # 对应代码或工具
  contract:
    get: true  plan: true  apply: true  verify: true
    watch: true
    undo: partial                        # none ⇒ 使用处 Policy 强制人审
---
# 使用层：systems/<s>/instances/<i>/connector-ops/onedev-ci.yaml（或 global/connectors/ops/<name>.yaml）
apiVersion: core/v1
kind: ConnectorOps
metadata:
  name: onedev-ci
  scope: builtin-developer-system/local-ci
spec:
  provider: onedev-driver                # 类型来源
  workflow: default-task                 # 绑定的 Workflow（见 concepts/workflow.md）
  config: {endpointRef: ref/onedev-endpoint}
  credentials: [credential/onedev-robot]
  ops: [checkout, build-status, gate-status, verify]   # 暴露子集
status:
  conditions:
    - {type: Reachable, status: "True"}
    - {type: ProviderVersion, status: "True", reason: "v0.1"}
```

## 4. 生命周期

Provider：注册（代码入库+Apply）→ 被引用 → 版本升级（新版并存，兼容期）→ 废弃（无引用后）。
Ops：创建（引用 Provider+配环境+绑 Workflow）→ 探活（conditions）→ 配置漂移=drift → 删除（Finalizer 清外部注册物，如 webhook）。

## 5. 与其他概念的关系

- **Workflow**：每个 Ops 必绑一个 Workflow（op 的调用走态机；builtin 有默认），见 concepts/workflow.md。
- **Provider（大写概念）**：外部能力账号包（auth/config/connector/secret）里的 connector 字段引用 **ConnectorOps**——注意两词：`ConnectorProvider`（驱动类型）与 `Provider`（账号能力包）不同物，见 concepts/provider.md。
- WorkService 引用 ops 驱动自己；TaskScheme 步骤的 `connector:` 字段指 ConnectorOps 名。
- 权限：Agent 引用 ops（P7）；ops 的credentials 单独授权（credential.md）。

## 6. 设计规则

1. Provider 未注册的 type，Ops 不予创建（Scheme 闸门）。
2. Ops 必绑 Workflow（缺省 default-task）。
3. `undo: none` 的 Provider，其 Ops 的每次 apply 走人审。
4. 一个外部系统的驱动只注册一个 Provider；环境差异全在 Ops 层。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 拆分后概念数膨胀 | ⚠️ 低 | 但消除了"类型/使用"混用的双源 | 命名硬区分：Provider=类型，Ops=使用 |
| 每 instance 自实现 ops 的重复 | ⚠️ 中 | 用户明确要求（不共享状态） | 全局默认 ops 兜底 + 模板生成 |
| 其余同 v0.2（适配面/幂等/undo） | ⚠️ 中 | 拆分不改变契约难度 | 见原可行性结论：成熟工程，无研究性风险 |

**结论：可行。拆分是纯结构改善，把"类型"与"使用"各归其位。**

## 8. 原始设计标注

- A25（R2）：Connector 拆为 ConnectorOps/ConnectorProvider；Agent 默认挂 ops；builtin 服务 `connector` 提供默认 ops；使用要权限。

## 9. 待决问题

见 open-questions.md#connector

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
