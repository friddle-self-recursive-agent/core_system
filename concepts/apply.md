# Apply — 文档面唯一写路径与系统间调用

| 项 | 值 |
|---|---|
| K8s 对照 | kubectl apply（文档级）——**不再对标 SSA 字段归属（ 删除）** |
| 形态 | Core 暴露的写接口（动词），不是存储对象 |
| 作用域 | 全局 |
| 状态 | 定稿（终态制，rule.md） |

## 1. 定义

Apply 是**文档面的唯一写路径**：任何文档更新必须经 Apply——**因为文档做版本管理**。这个"唯一"只作用于**文档面**；**不影响最底层 Agent 干活**——Agent 执行任务走 ConnectorOps（权限校验在 ops），其运转以 PlanDoc/SessionLog 留痕，不逐写审批（ 澄清）。

**编辑与发布分离（草稿缓存）**：文档修改默认由 Agent **代改代审**——改动先落在**草稿缓存**（v1=工作区未提交改动/待审区），不触碰文档面、不发事件；**人确定后调用 apply 命令**，草稿差异经乐观锁落库（Revision+1、git commit）。**apply 必发 DocApplied 事件**——apply 是确认动作，事件是它的回执。Status/记录类（Status 回写/SessionLog/DriftReport）是机器直写（fieldManager 白名单），不经草稿确认；自写不发 DocApplied（防自我唤醒）。

系统间调用仍是文档面语义：系统 A 影响系统 B = A 对 B 的文档 Apply 一个提案，B 的 Workflow 看到后自行收敛。没有点对点 RPC。

## 2. 边界

**是**：文档写接口（含草稿缓存的落库命令）+ 乐观锁（文档级）+ 审计 + 事件产生。

**不是**：
- 不是 Agent 干活的审批关口（/：Agent 干活不受 Apply 约束）；
- 不是字段级合并器（SSA/managedFields 已删，：git 无字段级归属概念，不做；文档 diff 是语义活，交给 LLM）；
- 不是 Event（Apply 改状态，Event 只通知）；
- 不带提案 SLA/超时机器。

## 3. 语义

```
apply(obj, opts)
 opts: {dryRun: bool, force: bool, fieldManager: "agent/ci-repair-agent"}

前置：Agent 代改代审的改动先进草稿缓存（不触碰文档面、不发事件）
流程：取草稿与当前的差异 → 权限系统准入 → 文档级比对（整文档）
 → 无差异：无操作（提示无需 apply，不发事件）
 → 有差异：乐观锁提交（Revision）→ generation+1（若 spec 变）→ DocApplied Event（必发）
冲突：resourceVersion 不符 = Conflict → 后写者重读；
 需要合并时由 LLM 做**语义 diff**（哪里不同、是否冲突、合并提案），人裁兜底
```

## 4. 生命周期

接口常在；语义随 Scheme 演进。**归属粒度=文档级，最小就文档，不到字段**；字段级语义归 Scheme 层表达。

## 5. 与其他概念的关系

- Revision 提供乐观锁与历史（审计=git log + ops DB 双轨）。
- 权限系统 在 Apply 内执行（准入是写路径的一环）。
- 写者四种：人写 Spec、Agent 回写 Status/SessionLog、Workflow 写 DriftReport、跨系统提案（默认进对方待审区，除非 权限系统 放行）。
- Notification：DocApplied/ApprovalNeeded 的告知出口（无 SLA 机器）。

## 6. 设计规则

1. **apply 必发 DocApplied + fieldManager 白名单豁免自身**：apply 落的是草稿与文档面的真实差异，落库即发事件；空草稿=无操作（不落库不发事件）。自身 fieldManager 的回写（如 Workflow 写 Status 触发的 DocApplied）在白名单内豁免——防自我唤醒循环。
2. 任何文档写入必须携带 fieldManager（无主写入拒绝，审计可追溯）。
3. dryRun 必须零副作用且返回与真执行一致的 plan。
4. 跨系统提案默认进对方**待审区**；超时/催办不是本系统机制——Notification 告知即可。
5. Status 与 Spec 的写权限分离不变（P2/P6）。
6. **草稿缓存是编辑的家**：Agent 代改代审的 Spec/意图类改动一律先进草稿，不就地改生效文档（P6 的运行形态）；草稿可查/可弃，apply 后清空；草稿不是文档面（无 Revision/事件，落库那一刻才算数）。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 并发写冲突更粗（文档级） | ⚠️ 低 | 接受：文档粒度本就大，写者少 | 乐观锁+重读；真需并行的内容应拆成多份文档 |
| LLM 语义 diff 幻觉 | ⚠️ 中 | 合并建议可能错 | 事实基础永远是 git 文本 diff；LLM 只做解读与合并提案，落地必须人裁（或 权限系统 高危拦截） |

**结论：可行，且比 更简单（删掉最难啃的 SSA 子集）。**

## 8. 待决问题

见 open-questions.md#apply

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
