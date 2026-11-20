# Credential — 凭证

| 项 | 值 |
|---|---|
| K8s 对照 | Secret（但明文永不入库，库内只有引用） |
| 形态 | 引用对象：global/credentials/<name>.yaml；真值在外部（env/vault/agent 本地钥匙串） |
| 作用域 | Global（Builtin 有根凭证） |
| 状态 | 设计稿 v1 |

## 1. 定义

Connector 访问外部系统需要钥匙（token/密码/key）。Credential 对象只登记"这把钥匙叫什么、给谁用、在哪取、何时轮换"，**明文永不进文档库**（git 里出现密钥是经典事故，这里从机制上禁止）。

## 2. 边界

**是**：钥匙的登记与授权（哪类 Connector 在哪个 scope 可用这把钥匙）。

**不是**：
- 不是密钥存储（存储在外部 KMS/env/本地钥匙串，运行时解析）；
- 不是 Bind（Bind 是人的责任关系，Credential 是机器身份的钥匙）；
- 不是 Auth 文档（Auth 是"系统授权给谁用"的**设计声明**，Credential 是**一把具体的钥匙**；一个 Auth 设计可能对应多把 Credential）。

## 3. 结构

```yaml
apiVersion: core/v1
kind: Credential
metadata:
  name: gitlab-robot
  scope: global
  finalizers: [core/revoke-credentials]
spec:
  kind: token                    # token | password | ssh-key | oauth
  source:                        # 真值在哪（运行时解析）
    {vault: secret/gitlab-robot} # 或 {env: GITLAB_TOKEN} / {keychain: item-id}
  grantedTo:
    - {connector: gitlab-driver, scopes: [global]}
  rotation: {every: 90d, by: connector/vault-driver}
status:
  lastRotated: 2026-09-30
  health: {checkedAt: ..., valid: true}
```

## 4. 生命周期

登记（人审，Policy 高危项）→ 授权给 Connector → 周期轮换（轮换本身也是一个 WorkService+Connector 干的活，递归适用本设计）→ 吊销（Finalizer：先解除所有 grantedTo 再删登记）。

## 5. 与其他概念的关系

- Connector 持引用、运行时解析；WorkService 的 credentials 字段引用它。
- Auth 文档（DocType）定义授权**设计**，Credential 实例化**钥匙**。
- 审计：谁用了哪把钥匙做什么，进 Revision 审计流。

## 6. 设计规则

1. 明文检测：Policy 对全库做密钥模式扫描（高熵串/已知前缀），命中即拒绝入库并告警——包括 Ref、Docs 正文。
2. grantedTo 最小化：默认无授权，逐 Connector 显式授予。
3. 轮换是强制的：无 rotation 声明的 Credential 告警；超期未换降权（Connector 调用需人审）。
4. 日志与 DriftReport 中凭证只以名引用，永不展开。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 依赖外部 KMS 才安全 | ⚠️ 低 | v1 可以先用 env/本地钥匙串起步 | source 抽象已隔离；升级只是换 source |
| 密钥模式扫描漏报 | ⚠️ 低 | 高熵检测不完美 | 与规则 4（永不展开）双保险；扫描是兜底不是唯一防线 |
| 轮换引发大面积失败 | ⚠️ 中 | 换钥匙瞬间在途调用失败 | 轮换走双钥匙过渡期（新旧并行 N 小时），Connector 契约支持 |

**结论：可行。纯治理+簿记，机制标准。**

## 8. 原始设计标注

- 原稿 Auth 是文档类型（设计层），但钥匙放哪没说——本概念补齐机器身份侧。

## 9. 待决问题

见 open-questions.md#credential

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
