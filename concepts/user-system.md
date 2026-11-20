# UserSystem — 用户系统（builtin 默认，未来评估 IdP 接入）

| 项 | 值 |
|---|---|
| K8s 对照 | 无直接对应（k8s 不管人）；类比 cloud IAM 的用户目录，但刻意从简 |
| 形态 | builtin 服务（systems/builtin/user-system/）+ Kind `User`（global/users/<name>.yaml） |
| 作用域 | Builtin（服务）/ Global（User 对象） |
| 状态 | 设计稿 v0.4（R3 新增，A34） |

## 1. 定义

用户系统回答"人是谁、怎么联系、持有哪些 role"。**默认 builtin**：本地用户表（User 对象集合），零外部依赖。**未来可行性**：评估 authentic/authentik（IdP）能否接入——若接入，IdP 作为 WorkService 纳管，本地用户表变为投影（权威转移，见可行性）。

## 2. 边界

**是**：人的目录 + role 持有关系 + 通知通道信息。

**不是**：
- 不是 Bind（Bind 是对象↔role；用户系统是人↔role）；
- 不是 Provider（Provider=外部账号/钥匙包，机器侧；用户系统=人）；
- 不做认证协议实现（builtin 只是一张表；真需要 SSO/OIDC 是未来 IdP 接入的事）；
- 不管权限语义（权限仍是 P7 并集 + Policy）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: User
metadata:
  name: u-zhang
  scope: global
spec:
  display: 张三
  contact:                          # Notification 通道解析用
    im: {provider: provider/im-feishu, userId: "zhang"}
    email: zhang@example.com
  roles:                            # 持有的 role（=Bind 引用）
    - bind/ci-approver-bind
    - bind/oncall-devtools
status:
  lastSeen: 2026-11-20T09:00:00Z    # console 登录/操作时间（审计）
```

## 4. 生命周期

builtin 起步（Igniter 装载首批用户——至少一个管理员）→ 增删走 Apply+人审（人的变更永远是敏感项）→ 未来切 IdP：User 变投影（spec 由 IdP 同步，本地只读）。

## 5. 与其他概念的关系

- Bind.status.holders 由本系统回写（投影）。
- Notification 的 route 按 role 解析到人时查本系统 contact。
- Policy 的"人审"类动作（ApprovalNeeded）最终送达具体人也要经过本系统。
- 未来 IdP 接入形态：WorkService(authentik) + ConnectorProvider(oidc/ldap) + Provider(账号包)——全部复用现有概念，不新增机制。

## 6. 设计规则

1. builtin 用户表最小字段（display/contact/roles）；不加组织架构等重字段。
2. 用户增删改走人审；root 管理员至少一人（防止全锁死）。
3. contact 只存引用/地址，不存 IM 凭证（凭证在 Provider/Credential）。
4. IdP 接入前，本系统是权威；接入后 spec 标 `syncedFrom: workservice/authentik`，本地写只读。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| authentic/authentik 接入 | ⚠️ 待评估 | R3 原文"未来做可行性的时候看看能不能接入" | 初判可行：OIDC/LDAP 是标准协议，WorkService+ConnectorProvider 形态天然适配；评估清单见 instance 仓 feasibility §13 |
| builtin 表与 Bind 漂移 | ⚠️ 低 | role 引用悬空 | 对账探针（悬空引用=drift） |
| 单管理员锁死 | ⚠️ 低 | 唯一管理员离开 | 规则 2：至少一人；Igniter 级恢复路径（bootstrap 重建） |

**结论：可行。builtin 是一张表，零技术风险；IdP 接入是纯增量（复用 WorkService/Connector 机制）。**

## 8. 原始设计标注

- A34（R3）：新增概念；默认 builtin；authentic（疑为 authentik）接入列入未来可行性。

## 9. 待决问题

见 open-questions.md#user-system

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
