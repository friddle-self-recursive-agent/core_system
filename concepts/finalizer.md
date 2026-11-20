# Finalizer — 两阶段删除

| 项 | 值 |
|---|---|
| K8s 对照 | Finalizer（metadata.finalizers） |
| 形态 | metadata.finalizers 列表 + 删除状态机 |
| 作用域 | 跟随宿主 |
| 状态 | 设计稿 v1 |

## 1. 定义

删除一个文档对象时，它在外部世界留下的东西（gitlab 上的 webhook、jenkins 上的 job、prometheus 里的告警规则）必须先被清掉。Finalizer 是这个"先扫尾、后真删"的两阶段协议（A7：原稿没有删除语义）。

```
阶段一：收到删除请求 → 对象进入 Deleting（打墓碑标记，不再对外服务）
阶段二：各 finalizer 对应的清理器（owner 的 Agent 经 Connector）执行 undo
        → 逐个摘除 finalizer 名 → 全空 → 真删（git rm）
超时/失败 → Escalate 到 Bind 的人，绝不带finalizer静默消失
```

## 2. 边界

**是**：删除协议 + 外部副作用的登记表。

**不是**：
- 不是回收站（没有"恢复"语义；要恢复走 git 历史 + 重建）；
- 不是备份策略（备份是 Rule/DeployDesign 里声明的系统能力）；
- 不是权限（能删=Policy 管，删得干净=Finalizer 管）。

## 3. 结构

```yaml
metadata:
  finalizers:
    - core/wipe-workservice-side-effects   # 命名：<注册者>/<语义>
    - core/revoke-provider-auth      # v0.8：原 revoke-credentials 更名（A40）
status:
  deletion: {startedAt: ..., phase: Cleaning|Blocked, perFinalizer: [...]}
```

## 4. 生命周期

对象创建带 finalizer（DocType/系统模板可默认注入）→ 常态不可见 → 删除请求激活 → 清扫 → 摘完真删。

## 5. 与其他概念的关系

- 清理动作用 Owner 链找到责任 Agent，经 Connector.undo 执行——所以 **Finalizer 的可行性依赖 Connector 的 undo 契约**（connector.md §3）。
- 级联删除（owner.md）每一跳各自走 Finalizer。
- builtinRoot 无 finalizer 也不可删（更严：Policy 硬禁，连删除请求都拒绝）。

## 6. 设计规则

1. 凡创建过外部副作用的对象，创建路径必须同时注入对应 finalizer（Connector.apply 里有创建动作即自动登记——**副作用登记自动化**，不靠人记得）。
2. finalizer 摘除动作本身经 Apply（审计可见）。
3. 清理卡死 24h → Escalate；带 finalizer 的墓碑对象在观测面常亮（它们是"删不干净"的欠债）。
4. dry-run 删除必须输出将执行的清理清单。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 外部副作用漏登记 | ⚠️ 中 | Connector 代码忘了登记 | 规则 1 自动化登记（apply 产生外部创建即注入）；审计对账"外部资源清单 vs finalizer"双向核对（driftScan 的一项） |
| 墓碑堆积 | ⚠️ 低 | 删不干净的东西越积越多 | 观测面欠债指标 + 定期人工清理会 |
| undo 做不到的外部系统 | ⚠️ 中 | 部分 API 不可编程删除 | `undoUnsupported` 类型 Policy 强制人参与清理 |

**结论：可行。关键依赖规则 1 的自动登记 + 双向对账，把"人记得"变成"系统记得"。**

## 8. 原始设计标注

- A7：本概念整体为原稿缺失项的补充。

## 9. 待决问题

见 open-questions.md#finalizer

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
