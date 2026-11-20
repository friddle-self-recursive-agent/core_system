# WorkService — 外部真实系统

| 项 | 值 |
|---|---|
| K8s 对照 | Node（能力提供方）/ External Provider（如 ExternalDNS 面对的云厂商） |
| 形态 | workservices/<name>/ 目录：Desc + Connector 引用 |
| 作用域 | Global |
| 状态 | 设计稿 v1 |

## 1. 定义

WorkService 是被纳入管理面的**外部第三方真实系统**：gitlab、jenkins、prometheus、公司内部已有的任何系统。它们不是本控制面创建的，但本控制面要对它们声明期望、观测现实、施加变更——全部经由 Connector（A11 边界）。

例：`developer-system`（ServiceDesc）依赖 `gitlab`、`jenkins`（WorkService）。

## 2. 边界

**是**：外部系统的"在册声明"：它是什么（Desc）、用什么驱动它（Connector 引用）、它在哪（Endpoint/Ref）、健康如何（Status）。

**不是**：
- 不是本系统的实例（那是 ServiceInstance，Q2 裁决）；
- 不是 Connector（Connector 是驱动代码，WorkService 是被驱动者的声明；一个 gitlab WorkService 引用一个 gitlab-driver Connector）；
- 不被 Loop 直接改配置：一切变更走 Connector 的幂等 apply（P4）；
- 不吞并临时引用：只在册"常驻管理"的外部系统，临时指路用 Ref。

## 3. 对象结构

```yaml
# workservices/gitlab/workservice.yaml
apiVersion: core/v1
kind: WorkService
metadata:
  name: gitlab
  scope: global
  labels: {category: scm}
  finalizers: [core/revoke-credentials]
spec:
  descRef: desc.md                 # 这个外部系统是什么、提供什么能力
  capabilities: [scm, ci-trigger, mr-review]   # 能力标签，供 Desc 侧按能力引用
  connectorOps:                                 # v0.3：引用 ConnectorOps（使用层）
    - ops/onedev-ci
  endpoint: {ref: ref/scm-endpoint}            # v0.10：Ref=逻辑声明，真实地址由 owning system 解析（A46）
  auth: {provider: provider/gitlab-robot}     # v0.8：凭证走 Provider（A40）
status:                            # Connector watch + 健康探测回写
  observedGeneration: 4
  conditions:
    - {type: Reachable, status: "True"}
    - {type: VersionSupported, status: "True", reason: "17.x in [16,18)"}
```

## 4. 生命周期

在册（Apply）→ Connector 持续 watch（外部变化→Event）→ 版本漂移/不可达→Event→相关 Loop 处理 → 注销（Finalizer：吊销凭证、解除 Webhook 注册等外部副作用）。

## 5. 与其他概念的关系

- 被 ServiceDesc 的 workserviceRefs 按能力引用（Desc 不绑实现，引用时按 capabilities 匹配）。
- ConnectorOps 是它的驱动（类型由 ConnectorProvider 提供）；Ref 指它的地址；Provider 是账号与钥匙包（v0.8 起钥匙内化于 Provider，A40）。
- Prometheus 作为 WorkService 在册后，"监控实现"就有了归宿（A1 的下半句）。

## 6. 设计规则

1. 能力声明（capabilities）是 Desc 侧引用的依据：换 gitlab→gitea 只动 WorkService+ConnectorOps/Provider，不动 Desc（"能力声明，不绑实现"的兑现处）。
2. WorkService 的 Status 只描述"它自身健康/版本/可达"，不描述"我的系统好不好"（后者在 Instance）。
3. 外部系统的任何写操作必须可回滚：Connector 契约含 undo 语义（见 connector.md）。
4. 一个外部系统一个 WorkService 对象；同系统多环境=多对象（gitlab-prod / gitlab-test）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 适配面大，每个外部系统都要写 Connector | ⚠️ 中 | 工程量随系统数线性涨 | Connector 模板库 + 常见类型官方维护（gitlab/jenkins/k8s/prometheus/ssh(dsh) 先行） |
| 外部系统不可控变更（升级/改 API） | ⚠️ 中 | 现实先变，文档后知 | Connector watch 差异→Event→Loop 对账（这正是本系统的主场：drift 是常态输入而非异常） |
| 幂等/undo 在某些外部系统做不到 | ⚠️ 中 | 如某些 API 无 dry-run | Connector 内部用"读-比-写-验证"模拟；真做不到的类型标注 `undoUnsupported`，权限系统 强制人审 |

**结论：可行，且是本设计最先能落地的部分（不依赖 Agent 全自治）。**

## 8. 原始设计标注

- A11：与 ServiceInstance 的边界=Q2（外部第三方 vs 本系统实例化）。
- A1：Prometheus 从文档类型降为此处的 WorkService。

## 9. 待决问题

见 open-questions.md#workservice

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
