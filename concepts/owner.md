# Owner — 归属引用与级联

| 项 | 值 |
|---|---|
| K8s 对照 | OwnerReference + GC 级联删除 |
| 形态 | metadata.ownerRefs 列表（单主，v1 不做多主） |
| 作用域 | 跟随宿主 |
| 状态 | 设计稿 v1 |

## 1. 定义

ownerRef 声明"我因谁而存在"。被拥有者随拥有者级联生死。本系统的归属树：

```
builtinRoot
 ├── Agent 树（Parent/Sub 即 owner 链）
 ├── system/core（Core 自描述）
 └── ServiceDesc ──┬── ServiceInstance ──┬── ImplDoc / VerifyDoc / DriftReport
                   ├── Loop                     └── 运行任务记录
                   └── 系统 scoped Ref
WorkService ── WorkService scoped Ref / 绑定的 Credential 引用记录
```

## 2. 边界

**是**：生命周期归属（GC 依据）+ 责任上溯（出事找 owner 链顶端的 Bind 人）。

**不是**：
- 不是权限继承（子对象权限仍按 P7 独立计算；owner 不自动授予写权）；
- 不是引用（Ref/agentRefs 是"用"，ownerRef 是"属"；用不级联，属才级联）；
- 不是 Scope（Scope 是住哪，Owner 是谁的；Agent 住 Global 但属 builtinRoot）。

## 3. 结构

```yaml
metadata:
  ownerRefs:
    - {kind: ServiceDesc, name: developer-system}   # 单主
```

## 4. 生命周期（GC 规则）

owner 被删除 → 级联删除全部被拥有者（各先走自己的 Finalizer 清外部副作用）→ 被拥有者先于 owner 死亡是合法的（孤卵不孤主）。孤儿检测：有 ownerRef 但 owner 不存在 → 告警 Event，不自动删（防误删重建窗口期误判；由 Loop 核实后清）。

## 5. 与其他概念的关系

- Finalizer 挂在级联删除的每一跳上（删系统=清 gitlab 上所有注册物）。
- Agent 的 Parent/Sub 用 owner 表达，权限继承方向相反：权限从根向下裁剪（agent.md），生命从根向下级联（本概念）。
- Bind 的责任上溯沿 owner 链找到最终 owner。

## 6. 设计规则

1. 单主（v1）；确实双主的需求改为"一主一引用+显式 Finalizer"。
2. 环禁止（A 的 owner 是 B、B 的 owner 是A）——Policy 校验。
3. ownerRef 指向的对象必须存在或正在创建中（同一 Apply 批次允许）。
4. 级联删除必须可预演：`apply --dry-run` 输出完整删除树供人审。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 重建窗口误判孤儿 | ⚠️ 低 | owner 删了又马上重建同名 | 规则 4 孤儿只告警不删 |
| 级联风暴 | ⚠️ 低 | 大系统删除触发大量外部清理 | Finalizer 分批 + maxMutations 刹车同样适用于删除 |

**结论：可行。k8s 成熟机制，简化为单主。**

## 8. 原始设计标注

- 原稿 ParentAgent/SubAgent → 用 owner 链表达生命归属、用权限裁剪表达控制归属，两义分开。

## 9. 待决问题

见 open-questions.md#owner

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
