# Connector — 外部系统幂等驱动

| 项 | 值 |
|---|---|
| K8s 对照 | CSI/CNI/Device Plugin（驱动契约）+ operator 里 kubeclient 的位置 |
| 形态 | 代码 + 声明（global/connectors/<type>/：connector.yaml + src/） |
| 作用域 | Global（系统专属驱动放 systems/<s>/connectors/，同样全局注册） |
| 状态 | 设计稿 v1 |

## 1. 定义

Connector 是"用代码做胶水"的正式化：把一个外部系统（WorkService）的操作封装成**统一幂等契约**，并把它外部发生的变化转成 Event。Agent 和 Loop 只面对契约，不面对千差万别的外部 API。

契约五个方法（全部幂等，P4）：

```
get(spec)            -> state          读现状
plan(spec, state)    -> diff           算差距（不执行）
apply(spec, dryRun)  -> actions|result 执行（可预演）
verify(state, spec)  -> bool           验证是否一致
watch()              -> events         外部变化 → Event 流
undo(actionLog)      -> void           回滚（做不到的类型显式声明 undoUnsupported）
```

原稿例子：Connector 是 DSH —— 即"Agent 怎么使用 DSH（分布式 shell）"的用法与代码就是一个 `dsh` 类型的 Connector。

## 2. 边界

**是**：驱动层。吃声明、吐状态/事件。**纯机械**。

**不是**：
- 不做业务判断（不读 Goal、不决定"该不该修"，那是 Agent）；
- 不是外部系统本体（那是 WorkService）；
- 不是 Agent 的一部分（代码集中入库，Agent 只引用 type+version，A16）；
- 不持有凭证明文（运行时按 Credential 引用解析）。

## 3. 对象结构

```yaml
# global/connectors/gitlab-driver/connector.yaml
apiVersion: core/v1
kind: Connector
metadata:
  name: gitlab-driver
  scope: global
spec:
  type: gitlab-driver            # Agent/WorkService 引用的就是 type
  version: v1.2
  runtime: {lang: go, entry: src/main}
  contract:                      # 五方法支持度声明
    get: true  plan: true  apply: true  verify: true
    watch: true
    undo: partial                # partial|full|none；none ⇒ Policy 强制人审
  capabilities: [scm, ci-trigger] # 与 WorkService.capabilities 对齐
  configSchema:                  # 使用方需提供的参数 schema
    endpoint: {type: ref}
    token:  {type: credential-ref}
```

## 4. 生命周期

注册（代码入库+Apply 声明）→ 被引用 → 版本升级（新 version，旧版保留兼容期）→ 废弃（无人引用后可删，Scheme 记 tombstone）。

## 5. 与其他概念的关系

- WorkService 引用它驱动自己；Agent 引用它获得能力（权限并集的一部分，P7）。
- 它的 watch() 是 Event 的第一生产者（外部世界的入口）。
- Credential 为它供钥匙；Ref 为它供地址。

## 6. 设计规则

1. 契约五方法缺省即拒绝注册（watch 可降级为轮询并显式声明 `watch: poll(30s)`）。
2. 无 dry-run 的外部 API，Connector 内部用 get+plan 模拟 dry-run。
3. Connector 代码即权限：能注册新 Connector 的权限 ≥ 改 Auth 文档，Policy 默认人审。
4. 禁止 Connector 内嵌另一个 Connector 形成
   逻辑编排——编排属于 Agent 的 plan，不属于驱动层。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 适配器黑洞 | ⚠️ 中 | 长尾外部系统写不完 | 分级：官方维护常用类型；一次性系统用 `dsh`/`http`/`sql` 三个通用驱动兜底 |
| 通用驱动太危险 | ⚠️ 中 | dsh 能跑任意命令=最大权限面 | 通用驱动默认逐调用审批（Policy 拦截）+ 命令白名单模板 |
| undo 不完整导致回滚断链 | ⚠️ 中 | actionLog 中断后无法完整回滚 | apply 分步落盘 actionLog；中断续跑；undoUnsupported 强制人审 |
| 版本兼容矩阵复杂 | ⚠️ 低 | Connector 版本 × 外部系统版本 | WorkService.Status.VersionSupported 条件位显式呈现 |

**结论：可行。这是最传统、工程确定性最高的部分，适配器模式 + 统一契约，无研究性风险。**

## 8. 原始设计标注

- A16：代码入库、Agent 引用 type。
- 原稿"Connector 连接现有系统和 workload / type->对应代码（如 DSH）" → 落为本契约模型。

## 9. 待决问题

见 open-questions.md#connector

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
