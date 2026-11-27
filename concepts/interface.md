# Interface — builtin 系统能力契约（builtin-system 内容）

| 项 | 值 |
|---|---|
| K8s 对照 | 内置 API 的契约面：契约随内置系统，外部 provider 用同形 op 接入 |
| 形态 | `systems/builtin/<s>/interfaces/<name>.yaml` |
| 作用域 | System（builtin 系统内） |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. 定义（2026-11-27 用户裁决）

Interface 是 **builtin-system 的内容**：core-system 的内置系统（builtin-user-system、builtin-developer-system…）**创建并拥有**能力契约（op 集+语义+版本）。core_system 调用这些 builtin 时**直接调接口**（进程内 Go interface，`connectors` 包 OpsConnector 五方法即现成模式）。

**以后要接入 ldap / 接入其他的，只需要用 ops 实现这个 interface**：外部系统把契约 op 集（可多不可少）实现为 ConnectorOps/WorkService.tools 的 ops，并在自己 ServiceDesc `provides` 标注 `{interface, version, impl: ops}`——零平台代码耦合。

## 2. 边界

**是**：builtin 系统的契约内容；外部 ops 接入的对账锚（provides 标注+Lint）。

**不是**：
- **不是系统间调用协议——系统间相互直接 ServiceWork 调用是系统间自己的事情，跟本项目无关**；相应**接口授权文档在各自系统写清楚**（各系统仓内自理）。
- 不是实现代码（在 connectors 包/connectops-<concept> 仓）；不是工具挂载（ConnectorOps）；不做权限判断（P7 归 Role）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Interface
metadata:
  name: user-directory
  scope: builtin/user-system        # 契约归所属 builtin 系统所有
spec:
  version: v1                       # scheme 版本化：name 不变 version 递增（同 major 兼容演进，破坏性变更升 major）
  semantics: "用户/群组目录查询与认证校验"
  ops:                              # 契约 op 集（外部接入用 ops 实现：可多不可少，Lint 对账）
    - {op: user-get, params: {uid}, idempotent: true}
    - {op: user-auth, params: {uid, password}, idempotent: true}
    - {op: user-search, params: {filter}, idempotent: true}
    - {op: group-get, params: {group}, idempotent: true}
    - {op: group-members, params: {group}, idempotent: true}
status: {}
```

实现方标注（ServiceDesc.spec，scheme.yaml 已扩字段）：

```yaml
spec:
  provides:                         # 我实现了哪些契约
    - {interface: user-directory, version: v1, impl: builtin}   # builtin-user-system：内置直调
    # ldap-user-system 侧同款标注 impl: ops（用 ops 实现同一契约，connector.md 规则 13）
  requires:                         # 我依赖哪些契约（缺失时 resolver 逐层询问，workflow.md §9b 同款）
    - {interface: contact-resolution, version: v1}
```

`impl` 取值：`builtin`（内置，进程内 Go 接口直调）｜`ops`（外部接入，用 ops 实现同一契约）。

## 4. 生命周期

契约随所属 builtin 系统演进：版本递增（同 major 兼容：加 op/可选参数；破坏性升 major）→ 弃用标记 → 无实现方引用才可删。外部 provider 上下线不触发契约变更，只触发 `provides` 对账。

## 5. 与其他概念的关系

- **ServiceDesc**：`provides`/`requires` 标注实现与依赖（锚点面）。
- **WorkService/ConnectorOps**：外部接入的实现与挂载面（ops 实现）；Interface.ops 是 op 语义对账权威。
- **Template resolver**：requires 缺失时逐层询问（默认/安装/导入）。

## 6. 设计规则

1. **契约归 builtin 系统**（2026-11-27 用户裁决）：Interface 是 builtin-system 的内容，非全局独立注册面；第三方**不得**创建/修改 builtin 契约。
2. **版本化**：`name + spec.version` 为身份；同 major 向后兼容；消费方 `requires.version` 精确绑定，缺省=同 major 最新。
3. **外部接入只需用 ops 实现**：接入 ldap/其他=把契约 op 集实现为 ops（可多不可少、语义对齐）+ 一条 `provides` 标注；无平台代码改动。
4. **Lint 对账**：`provides[].interface` 必须指向在册 builtin 契约；实现方 ops ⊇ 契约 ops；`impl: builtin` 的能力必须存在于核心 connectors 包（编译期保证）。
5. **系统间自理（边界外）**：系统间相互直接 ServiceWork 调用、接口授权文档，由各系统在自己仓内写清楚——本项目不做约定不纳管。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 契约与 ops 实现漂移 | ⚠️ 低 | provider op 变更后 provides 悬空 | 规则 4 Lint + WorkService 变更触发对账 |
| builtin Go 接口与 YAML 契约漂移 | ⚠️ 低 | 两面各改各的 | 规则 4 编译期保证+接口方法注释回指 interface.yaml |
| 越界纳管系统间调用 | ⚠️ 低 | 平台把手伸进系统间事务 | 规则 5 显式边界：本项目不管，各系统文档自理 |

**结论：可行。契约是 builtin 系统的一小块声明内容，外部接入=ops 实现+一行标注，平台零耦合。**

## 8. 待决问题

见 open-questions.md#interface

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
