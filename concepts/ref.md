# Ref — 第三方临时指针

| 项 | 值 |
|---|---|
| K8s 对照 | ObjectReference / Service(ExternalName) |
| 形态 | 一份小对象：global/refs/<name>.yaml 或系统目录内 refs/ |
| 作用域 | Global 或 System（原稿问题"Ref 属于哪个 System 还是 Global"→ 由 Scope 规则裁决） |
| 状态 | 设计稿 v1 |

## 1. 定义

Ref 解决原稿场景："我的系统是监控，但我的代码在别处"——**指路，不搬运**。它是指向任何不在册资源的轻量指针：外部 URL、另一个仓库、一篇文档、一个人。带生命周期（临时语义），失效可被发现。

## 2. 边界

**是**：一个指针 + 元数据（指向什么、谁拥有、活多久、为何存在）。

**不是**：
- 不是 WorkService：不注册驱动、不做幂等管理、不代表"常驻纳管"，只是指一下（需要被驱动=升级为 WorkService）；
- 不是链接集合页面：Ref 是对象（有 GVK、可被引用、可被 Policy 校验），不是 README 里的裸链接；
- 不复制内容：目标变了 Ref 不知道内容，只知道"还在不在"（可达性探测）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Ref
metadata:
  name: jenkins-docs
  scope: developer-system        # 或 global
  labels: {category: external-doc}
  ownerRefs: [{kind: Agent, name: ci-repair-agent}]   # 谁引用谁负责
spec:
  target: https://wiki.example.com/jenkins-pipeline
  kind: url                      # url | repo | doc | object | human
  purpose: "Jenkinsfile 约定参考，实现侧对齐用"
  ttl: 90d                       # 过期策略；manual=不过期但需年检 Event
  probe: {httpHead: true, interval: 1d}   # 可选可达性探测
status:
  lastProbe: {at: 2026-11-19T10:00:00Z, ok: true}
  expires: 2027-02-18
```

## 4. 生命周期

创建（谁用谁建，ownerRef 挂引用者）→ 存续期探测 → TTL 到期 → Event 通知 owner（续期/升级 WorkService/放死）→ 死信清理。

## 5. 与其他概念的关系

- WorkService 的 endpoint 用 Ref 指地址（地址是"临时"信息：环境迁移只改 Ref）。
- Agent 的 refs 是其上下文与权限的一部分（P7）。
- 与 Owner：无主 Ref（owner 全消失）自动进清理队列——防指针坟场。

## 6. 设计规则

1. Ref 必须挂 owner（人或对象）；无主即清理。
2. 重要外部依赖禁止只用 Ref：被 Loop 依赖的目标必须是 WorkService（Ref=知道，WorkService=管理）。
3. Ref 不得指向文档库内部对象（内部引用用 `system://` URI，Ref 只对外）。
4. 敏感目标（带 token 的 URL）禁止入 Ref——账号与钥匙走 Provider（v0.8，A40），指针只存目标地址。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 指针腐化 | ⚠️ 低 | 链接失效无人管 | TTL+探测+owner 通知；核心规则 2 兜底 |
| Ref 泛滥成杂物堆 | ⚠️ 低 | 什么都建 Ref | 必须挂 purpose 与 owner；Policy Lint 全局 Ref 数量阈值告警 |

**结论：可行，纯簿记对象，无技术风险；风险全在纪律，由规则+Lint 管。**

## 8. 原始设计标注

- 原稿"Ref 属于哪个 System 还是 Global" → `metadata.scope` 二值，就近声明，见 scope.md。

## 9. 待决问题

见 open-questions.md#ref

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
