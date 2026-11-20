# Policy — 准入控制

| 项 | 值 |
|---|---|
| K8s 对照 | ValidatingAdmissionWebhook / Admission 链 |
| 形态 | 规则对象（global/policies/）+ Policy 引擎（Core 内置，硬规则兜底） |
| 作用域 | 全局生效，规则可按 scope/Label 限定 |
| 状态 | 设计稿 v1 |

## 1. 定义

Policy 是 Apply 写路径上的强制闸门（A9）：文档即权限 ⇒ 每次写入先过准入。检查四类：

1. **结构**：DocType 必填段、保留字段、枚举值。
2. **权限**：这个 fieldManager 能写这个 scope 的这个对象吗（P7 执法者）。
3. **风险**：命中高危清单（改 Auth 文档、改 Builtin、注册 Connector、绑 Credential）→ 人审（ApprovalNeeded Event → Bind）。
4. **一致性**：交叉引用存在性、owner 链无环、finalizer 配对。

## 2. 边界

**是**：写路径守卫，规则本身也是文档（走 Apply 修改，但改 Policy 的 Policy 最严）。

**不是**：
- 不是审计（审计是 Revision 的历史记录；Policy 是事前，审计是事后）；
- 不是 Loop 的验证阶段（Policy 查"该不该写"，Verifying 查"写完之后现实对不对"——一个在写前，一个在写后）；
- 不是加密/网络隔离（v1 单库信任模型，见 scope.md 可行性）。

## 3. 结构

```yaml
apiVersion: core/v1
kind: Policy
metadata:
  name: default-admission
  scope: global
spec:
  rules:
    - match: {scopes: [builtin], kinds: [ServiceDesc, Scheme]}
      effect: humanReview                    # 一律人审
    - match: {docTypes: [Auth]}
      effect: humanReview
    - match: {kinds: [ConnectorProvider, Provider, Bind]}   # v0.8：Credential→Provider（A40）
      effect: humanReview
    - match: {fieldManager: "agent/*", fields: ["spec.*"]}
      effect: deny                           # P6：Agent 不得写 Spec（默认）
    - match: {fieldManager: "loop-engine", fields: ["status.*"]}
      effect: allow                          # Status 唯一写者
    - match: {connector: {undo: none}}
      effect: humanReview                    # 无回滚驱动的每次变更
  hardcoded:                                  # 硬规则（配置不可放宽，builtin.md §3）
    - deny delete agent/builtinRoot
    - deny disable scheme
```

## 4. 生命周期

bootstrap 时点火器写入默认 Policy → 修改走 Apply 且命中自身规则（改 Policy 需人审，最小自引用）→ 硬规则随二进制发版。

## 5. 与其他概念的关系

- 在 Apply 内执行（apply.md §3 流程第 2 步）。
- 消费 DocType 的 writers、Scope 档位、Builtin 成员表、Connector.contract（undo 支持度）。
- 审批流 = ApprovalNeeded Event → Bind → 人 Apply 决定。**没有独立工作流引擎**。

## 6. 设计规则

1. 默认拒绝、显式放行（写权限白名单制）。
2. 硬规则与配置规则双层：配置只能收紧（builtin.md 规则 2 的执法处）。
3. Policy 判定必须可解释：每次 deny 附规则 id 与理由（进审计）。
4. 规则求值顺序确定（声明序），首个命中生效，杜绝歧义。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 人审成为吞吐瓶颈 | ⚠️ 中 | 默认从严会堵死 | 规则按 fieldManager/Label 粒度放行高频低危路径；观测面监控审批积压，动态放宽是运营决策 |
| Lint 级语义校验误报 | ⚠️ 低 | 自然语言交叉检查不完美 | Lint 只警告不拒绝（warning 与 deny 分级） |
| 硬规则升级需发版 | ⚠️ 低 | 不敏捷 | 接受：硬规则集合刻意极小（3 条） |

**结论：可行。风险是运营性（审批流量）而非技术性；分档放行是标准解。**

## 8. 原始设计标注

- A9：本概念为原稿缺失项（文档即权限的防线）。

## 9. 待决问题

见 open-questions.md#policy

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
