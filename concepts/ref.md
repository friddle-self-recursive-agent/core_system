# Ref — 声明式逻辑引用（说"要什么"，不写"在哪"）

| 项 | 值 |
|---|---|
| K8s 对照 | Service 名/DNS（逻辑名→由权威方解析地址）；ExternalName 的声明化 |
| 形态 | 对象：`global/refs/<name>.yaml` 或系统目录内 refs/ |
| 作用域 | Global 或 System（"Ref 属于哪个 System 还是 Global"→ 由 Scope 规则裁决） |
| 状态 | 定稿（终态制，rule.md） |

## 1. 定义

Ref 更多是**描述、申明**：声明"我需要什么"——由哪个 system 解析、type 是什么、关键参数（如项目名）。**运行时去相应系统找实例**：真实地址由被指向的系统管理并返回。

典型例：

```
我需要 onedev 源代码
 → Ref 声明：resolve.system = developer-system，type = code，params.project = onedev
 → 运行时向 developer_system 请求解析
 → developer_system 返回真正代码地址（git@…/onedev.git）
```

**用这种方法进行各个系统解耦**：消费方只写逻辑声明；物理映射（真实地址、托管在哪、哪个环境）归 owning system 管理面。换托管、换环境只动 owning system，所有引用方零改动。

## 2. 边界

**是**：逻辑声明（resolver+type+params）+ 生命周期 + 解析结果缓存。

**不是**：
- **不是地址**：地址是解析**结果**（status.lastResolution），不写在 spec 里；
- 不是 WorkService（那是外部系统纳管；Ref 是需求声明）；
- 不是内部 URI（文档库内部引用仍用 `system://`；Ref 面向外部/跨系统资源）；
- 不管地址有效性：**可达性探测与地址管理归 resolver system**（ 的 probe 职责移出）；
- 不复制内容（只声明与解析）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Ref
metadata:
 name: onedev-source
 scope: developer-system # 声明方所在 scope
 ownerRefs: [{kind: Agent, name: ci-repair-agent}] # 谁声明谁负责
spec:
 resolve: # 声明"要什么"
 system: developer-system # 由哪个 system desc 解析（resolver）
 type: code # code | doc | url | resource | service
 params: {project: onedev} # 如项目名
 purpose: "ci 构建取源码"
 ttl: 90d # 声明有效期（可选）
status:
 lastResolution: # 由解析动作回写（缓存）
 at: 2026-11-20T10:00:00Z
 by: developer-system/local-ci
 value: "git@host:onedev/onedev.git"
 cacheTtl: 10m
```

## 4. 运行时解析

```
resolve(ref)
 → 按 resolve.system 路由到该系统（其 Agent/ConnectorOps 提供 resolve 能力）
 → 返回真实地址/实例 → 写 status.lastResolution（缓存 cacheTtl）
 → 缓存命中期内直接用缓存；过期/失效事件后重解析
失败：resolver 不可用 → 用旧缓存降级 + Event(warn)；无缓存 → Event(error) → 声明 owner
```

## 5. 生命周期

声明（谁用谁建，ownerRef 必挂）→ 运行时解析+缓存 → ttl 到期/resolver 变更 → Event 通知 owner → 续期/改声明/放死 → 无主清理（不变）。

## 6. 与其他概念的关系

- **解耦主战场**：ConnectorOps.config 的 endpointRef/项目引用、WorkService 的 endpoint， 起都是逻辑声明（真实地址由 owning system 解析）。
- resolver system 用 WorkService+Ops 管理物理映射（developer_system 管 scm 地址表就是它的 ImplDoc 内容之一）。
- Skill/SessionLog 记录解析结果（审计"当时用的是什么地址"）。

## 7. 设计规则

1. Ref.spec 禁止出现物理地址（http://、git@、oss:// 等只允许出现在解析结果里）——出现即 Lint 警告（解耦从语法上锁死）。
2. resolve.system 必须指向已存在的 ServiceDesc，且该系统声明了对应 type 的解析能力（Scheme 校验）。
3. 解析结果必带 cacheTtl；解析失败必发 Event。
4. 解析链深度 ≤2（A 的 ref 由 B 解析，B 不得再用 ref 递归解析），建仓时检环。
5. owner 必挂；内部文档引用不用 Ref。
- 终态制：本文档只展示最终结果，变更历史只在 annotations.md（[rule.md](../rule.md) R-DOC-1/3）。

## 8. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 多一跳解析的延迟 | ⚠️ 低 | 每次取地址要问 resolver | cacheTtl 缓存 + 失效事件驱动重解析 |
| 循环解析 | ⚠️ 低 | A→B→A | 规则 4 深度限制+检环 |
| resolver 单点 | ⚠️ 中 | developer_system 挂了取不到地址 | 缓存降级 + Event + owning system 自身高可用 |
| 声明与实现漂移 | ⚠️ 低 | params 拼写错解析不到 | 解析失败即 Event；常用 params 建 Lint 词表 |

**结论：可行。等价于把 DNS/服务发现做进文档面，纯增量机制，解耦收益直接。**

## 9. 待决问题

见 open-questions.md#ref

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
