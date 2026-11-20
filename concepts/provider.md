# Provider — 外部能力账号包

| 项 | 值 |
|---|---|
| K8s 对照 | 无直接对应（组合了 Secret+ConfigMap+Endpoint 的"账号"概念；类比 cloud provider credential profile） |
| 形态 | 对象：`global/providers/<name>.yaml` |
| 作用域 | Global（可被 System/Instance 引用） |
| 状态 | 设计稿 v0.3（R2 新增，A27） |

## 1. 定义

Provider 回答："用谁家的 API、拿什么钥匙、怎么配、走哪个连接"。Agent 理论上要绑定 Provider——提供相应的 API 账号密码或接口（LLM API、IM 通知、云厂商……）。四要素：

- **auth**（属于）：认证方式与归属（scheme + secret 引用）；
- **config**：baseUrl、模型列表、限流等环境参数；
- **connector**：走哪个 ConnectorOps（**可为空**——本地工具/无接口依赖的能力）；
- **secret**：密钥本体走 Credential 引用（明文永不入库，credential.md 规则不变）。

## 2. 边界

**是**：账号能力包（auth+config+connector+secret 的聚合声明）。

**不是**：
- 不是 ConnectorProvider（那是驱动**类型**；本概念的 connector 字段引用的是 **ConnectorOps**——名字相近，两物，A27 备注）；
- 不是 Credential（Credential=一把钥匙；Provider=一个账号包，可含多把钥匙+config+通道）；
- 不是 WorkService（WorkService=被管理的外部系统；Provider=访问某能力的账号视角，同一系统可有多份 Provider：只读号/管理员号）；
- 四要素皆可为空（空 Provider=纯本地能力占位，合法）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Provider
metadata:
  name: llm-main
  scope: global
spec:
  kind: llm                          # llm | im | email | cloud | generic
  auth:
    scheme: bearer
    secret: credential/llm-api-key   # secret 概念→Credential 引用
  config:
    baseUrl: https://api.example.com/v1
    models: [glm-5, glm-4-flash]
    rateLimit: {rpm: 60}
  connector: ""                      # 可为空（直连 HTTP，无 ConnectorOps）
---
apiVersion: core/v1
kind: Provider
metadata:
  name: im-feishu
  scope: global
spec:
  kind: im
  auth: {scheme: oauth2, secret: credential/feishu-app}
  config: {app: cli_xxx, chatId: oc_xxx}
  connector: ops/http-api            # 走通用 http ConnectorOps
```

## 4. 生命周期

登记（人审——Provider 是钥匙集合的索引，高危）→ 被 Agent/Notification 引用 → 密钥轮换只动 Credential（Provider 不变）→ 注销（Finalizer：确认无引用）。

## 5. 与其他概念的关系

- Agent.spec.providers 引用（Agent 的能力账号面；权限并集的一部分，P7）。
- Notification 的 channel 走 Provider（im/email/webhook 各配其 Provider）。
- Credential 仍管钥匙本体（轮换/吊销/扫描规则全部沿用）。

## 6. 设计规则

1. Provider 变更走人审（它是"谁拿钥匙"的答案）。
2. secret 字段只允许 Credential 引用（出现明文=Policy 拒绝+扫描告警）。
3. connector 为空时，Agent 直连须在 config 声明目标域（审计可查出口）。
4. 一个 Provider 一个用途；多环境=多 Provider（llm-main / llm-backup）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 与 Credential 职责接近造成双簿记 | ⚠️ 中 | 钥匙信息两处出现 | 硬边界：Provider 不存密钥本体，只存引用+config；Policy Lint 交叉校验引用存在 |
| Provider 泛滥 | ⚠️ 低 | 每个外部账号一个 | 命名规范 `<kind>-<用途>`；无引用 Provider 告警 |

**结论：可行。纯簿记聚合，风险由边界规则压住。**

## 8. 原始设计标注

- A27（R2）：新增概念（auth/config/connector 可空/secret 四要素）。

## 9. 待决问题

见 open-questions.md#provider

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
