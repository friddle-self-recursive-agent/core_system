# UserSystem — 用户系统（builtin=单用户+token 授权；ldap/sso 演进带完整用户结构与缓存）

| 项 | 值 |
|---|---|
| K8s 对照 | 无直接对应（k8s 不管人）；类比 cloud IAM 的用户目录，但刻意从简 |
| 形态 | builtin 服务（systems/builtin/user-system/）+ Kind `User`（global/users/<name>.yaml） |
| 作用域 | Builtin（服务）/ Global（User 对象） |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. 定义（2026-11-27 用户裁决）

**这次 builtin 就一个用户。授权方式就是现在的 token 授权。这就是 builtin。**

- **builtin v0 = 单用户 + token 授权**：`builtin-user` 一个内置 User 对象（不可删），认证/授权=现有 token 机制（gate/dsh token，现状即声明，不重造不换协议）。零外部依赖、零用户管理界面负担。
- **默认 agent 节点 bind 都 bind 内置的这个用户**：一切默认 agent（root agent/子 agent/workflow 派发的 headless agent）执行主体身份=`builtin-user`（Agent.spec.subject 缺省绑定，agent.md）；权限面仍按 P7 role 并集走，主体身份只是「以谁的名义」。
- **完整用户结构是 ldap/sso 的事**：多用户、组织/组结构、用户缓存（user cache）等**后面实现 ldap/sso 的时候才有**——builtin 阶段刻意不存在，不预埋半成品。
- **一键安装向导**：界面（控制台）可以 **use-session 一键安装**——一个安装向导会话一路询问具体配置或安装选择，一路下来把用户体系搭建完成（§6 方案）。

## 2. 边界

**是**：内置单用户（身份锚）+ token 授权声明 + role 持有关系目录（ldap/sso 阶段启用）+ 一键安装向导（搭建面）。

**不是**：
- 不是多用户管理系统（builtin 阶段就一个用户；完整用户结构=ldap/sso 阶段）；
- 不是认证协议实现（v0 只用现有 token 授权；OIDC/LDAP 协议属 ldap/sso 演进）；
- 不是 Role 挂载（Role.on 是对象↔role；本系统是人↔role 的目录侧）；
- 不是 Provider（Provider=外部账号/钥匙包，机器侧）；
- 不管权限语义（权限仍是 P7 并集 + 权限系统）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: User
metadata:
 name: builtin-user
 scope: global
spec:
 display: 内置用户
 auth:
  mode: token # v0 唯一授权方式=现有 token 授权（gate/dsh token 机制，声明引用现状，不新造协议）
 contact: {} # ldap/sso 阶段才启用完整 contact 解析
 roles: [role/global/admin] # 单用户缺省持管理员 role（role/global/admin 不可删，Scheme builtinSet 同款防锁死）
status:
 lastSeen: 2026-11-27T09:00:00Z # console 登录/操作时间（审计）
```

Scheme 侧（core/scheme.yaml）：`User.builtinSet: [builtin-user]`（不可删）；`spec.auth.mode: token`（ldap/sso 阶段扩展 `idp` 取值）。多用户/Group/组织结构对象在 builtin 阶段**休眠不预埋**——ldap/sso 落地轮才启用。

## 4. 生命周期

builtin v0：Igniter 装载 `builtin-user`（一个用户，至少持 admin role）→ token 授权（现状机制）→ 增删改不开放（就一个用户，无增删面）。ldap/sso 演进：一键安装向导（§6）→ 完整用户结构落库 → 用户缓存生效 → 后续人的变更走 Apply+人审。

## 5. 与其他概念的关系

- **Agent（agent.md §3 spec.subject）**：默认 agent 节点 bind=`builtin-user`；显式 subject 可覆写（ldap/sso 阶段才有真实意义）。
- **Role.status.holders**：由本系统回写（投影）；builtin 阶段 holders 恒为 `[builtin-user]`。
- **Notification route**：role 解析到人经本系统 contact——builtin 阶段恒解析到内置用户。
- **Interface（interface.md）**：`user-directory/v1` 契约归本 builtin 系统所有；ldap-user-system 等外部 provider 用 ops 实现接入（`impl: ops`）。
- **Template resolver（workflow.md §9b）**：一键安装向导的询问阶梯机制来源（默认/安装/导入）。

## 6. 一键安装向导（use-session 一键安装用户体系）——需求方案（2026-11-27 需求要求）

**需求原话要点**：「界面可以 use-session 一键安装。然后一路询问具体配置或者安装一路下来能把用户体系搭建了。」

### 6.1 交互形态

控制台用户体系入口提供一个**一键安装**按钮 → 点击即创建一个 **use-session**（对话会话，挂人）+ 装配安装 Template（`user-system-install`）的 default-task run → agent 作为向导主持人**一路询问**具体配置或安装选择（每步带缺省值，可一路回车）→ 每步答案即时 apply 落地 → 全部步骤完成=用户体系 InSync。

```
控制台 [#/users 一键安装] 按钮
  └─→ 创建 use-session（对话会话挂人）+ user-system-install Template run
        ├─ 问 1 模式选择：builtin 单用户（默认，一路回车即此）｜LDAP｜SSO（Template resolver asks 三选，R-UX-1）
        ├─ 问 2（builtin 分支）确认内置用户与 token 授权 → apply User(builtin-user) → 完成
        ├─ 问 2（ldap 分支）host/bindDN/bind 密码/baseDn（密码走 secret 引用式提问，永不落明文）
        │     └─ apply Provider(ldap-user-system)+ConnectorOps(connectops-ldap)+User 投影开关
        │     └─ connectops-ldap 缺失/骨架态 → 一键「拉出代码开发」（connector.md 规则 6 同款）交 developer-system
        ├─ 问 2（sso 分支）IdP 地址/clientId/clientSecret → apply WorkService(idp)+Provider
        ├─ 问 3 缓存策略（ldap/sso 分支）：TTL/失效事件绑定（user cache 配置）
        └─ 收尾：InSync 回写 + 向导会话归档（SessionLog）
```

### 6.2 权威声明对象

Template `user-system-install`（appliesTo: system/user-system）权威 YAML 存 `core_system_instance/examples/templates/user-system-install.yaml`——纯声明（asks 阶梯+缺省值+apply 清单），无 builtin 代码；解释器按 Template resolver（R-UX-1：resolver 解析不了的才问，必带缺省/示例）驱动 use-session 会话执行。

### 6.3 前端判据（验收面见 instance 仓 acceptance/console/console-ui.md §19.9）

- 一键按钮存在且一次点击=一个 use-session（不是表单屏——以人为本对话式，与首页 chat 模式同形）；
- 每个询问必带缺省值，「一路回车」能走完 builtin 分支；
- 密码类问题只显示引用名不回显明文；
- 每步 apply 后对象即时可见（#/tags / 对象详情可跳）；
- 向导中断可续（Session 持久化，重进接着问）。

## 7. 设计规则

1. **builtin=单用户+token 授权**（2026-11-27 用户裁决）：`builtin-user` 一个内置用户、`auth.mode: token` 引用现状机制；不开放用户增删改面。
2. **默认 agent 节点 bind 内置用户**（agent.md spec.subject 缺省=`builtin-user`）；显式覆写保留，ldap/sso 阶段才产生真实意义。
3. **完整用户结构不预埋**：多用户/组织/组结构/用户缓存都是 ldap/sso 落地轮的内容；builtin 阶段 Group/多 User 对象休眠。
4. **一键安装=use-session 对话向导**：不另造表单安装器；机制=Template resolver asks（逐层询问+缺省）+ doc apply 管线 + Provider secret 引用，全部复用现有概念零新增机制。
5. **密码/凭据零明文**：向导收集的凭据一律 secret 引用式落 Provider（R-PUB-1/运行时配置与真实值分离）。
6. **contact 只存引用/地址，不存 IM 凭证**（凭证在 Provider.auth.secret）。
7. **切 IdP 后权威转移**：User spec 标 `syncedFrom: workservice/<idp>`，本地写只读；用户缓存（TTL/失效事件）随该阶段声明。

## 8. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 单用户 token 授权够不够 | ⚠️ 低 | core 自用+初期对外 | 现状已在 CT116 活体运行（gate token）；ldap/sso 是纯增量演进 |
| 一键安装向导做不做得出来 | ⚠️ 低 | 「use-session 一路询问」无先例？ | 有：Template resolver asks（R-UX-1）+ use-session 对话基建（首页 chat 同款）+ doc apply 管线全部现成；新增面仅一个 Template 声明+前端一个按钮 |
| 向导问到凭据泄露 | ⚠️ 中 | 对话里贴明文 | 规则 5：问题只收引用名/部署侧落 secret；会话日志脱敏（SessionLog 同款纪律） |
| builtin 与 ldap 双权威打架 | ⚠️ 低 | 内置用户 vs IdP 投影 | 规则 7：切 IdP 后本地只读+`syncedFrom` 标注；`user-directory/v1` 契约双实现并存（interface.md 规则 4） |
| 用户缓存一致性 | ⚠️ 低（延后） | ldap/sso 阶段才有 | 缓存策略（TTL/失效事件）在该落地轮随 Interface 契约版本一并声明 |

**结论：可行。builtin 阶段比现设计更简（就一个用户+现有 token）；一键安装向导是纯声明+前端小改，机制全部复用现有概念（Template asks/use-session/doc apply），无新增机制。**

## 9. 待决问题

见 open-questions.md#user-system

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
