# Revision — 版本、并发与审计

| 项 | 值 |
|---|---|
| K8s 对照 | resourceVersion（乐观锁）/ managedFields（字段归属）/ audit log |
| 形态 | metadata.resourceVersion + managedFields + git 历史（天然审计） |
| 作用域 | 跟随宿主 |
| 状态 | 设计稿 v1 |

## 1. 定义

多写者（人、多个 Agent、跨系统提案）同时存在，必须有：**乐观并发**（防丢更新）、**字段归属**（谁拥有哪个字段的写权）、**全程审计**（谁在何时改了什么、为什么）。Revision 三合一（A8：原稿无并发控制）。

## 2. 边界

**是**：写路径的并发正确性 + 变更历史。

**不是**：
- 不是 generation（generation 只数 Spec 语义变更；resourceVersion 数每次写入，含 Status）；
- 不是备份/容灾（那是 git 远端与 Rule 里的备份策略）；
-不是发布版本（系统的"版本"是 WorkService/Instance 的业务语义）。

## 3. 机制

```
resourceVersion：Core 每次成功写入自增；Apply 提交必须带回读到的版本，
                版本不符 = Conflict（后写者重读-重算-重试，SSA 标准流程）。
managedFields： {fieldManager: "agent/ci-repair", fields: ["status.*"]}
               字段归属冲突时按 Apply §3 冲突策略协商。
审计：         git 提交即审计（fieldManager 进 commit message 约定字段），
               Policy 判定记录（含 deny 理由）同样落审计。
```

## 4. 生命周期

随对象首次创建建立，随每次 Apply 演进；对象真删后历史仍在 git（可考古不可复活）。

## 5. 与其他概念的关系

- Apply 的第三步（乐观锁提交）由它承担。
- 审计供观测面"谁改了什么"查询；Conflict 率是系统健康指标（Agent 间互踩的信号）。
- Status 与 Spec 的写权分离（P2/P6）由 managedFields 承载。

## 6. 设计规则

1. 任何写入必须携带 fieldManager，无主写入拒绝。
2. Conflict 重试上限与 Loop.backoff 共享预算（防活锁）。
3. commit message 结构化：`<fieldManager> <action> <reason-ref>`，reason-ref 指向 DriftReport/Event/工单——**每次变更可追溯到起因**。
4. 历史不可改写：库层面禁止 force-push/rebase 已合入历史（git 服务端钩子强制）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| git 做乐观锁粒度粗 | ⚠️ 中 | 文件级而非字段级 | v1 接受：Core 单写者队列串行化 + managedFields 逻辑归属；真字段锁列 v2 |
| 大库性能 | ⚠️ 低 | git 万级文件尚可 | 文档库刻意轻量（数据不进来，A17）；超限时 Repository 接口换后端 |
| Agent 活锁 | ⚠️ 低 | 两 Agent 反复互踩 | Conflict 率观测 + 规则 2 预算 + 升级 |

**结论：可行。v1 用"串行队列+逻辑归属"换取 90% 的 SSA 收益。**

## 8. 原始设计标注

- A8：本概念为原稿缺失项。

## 9. 待决问题

见 open-questions.md#revision

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
