# Apply — 唯一写路径与系统间调用

| 项 | 值 |
|---|---|
| K8s 对照 | kubectl apply / Server-Side Apply（字段归属 ownership） |
| 形态 | Core 暴露的写接口（动词），不是存储对象 |
| 作用域 | 全局 |
| 状态 | 设计稿 v1 |

## 1. 定义

Apply 是**唯一合法的写路径**：人写文档、Agent 回写 Status、系统间调用，全部是对文档的 Apply。没有第二入口（直接改文件、绕过 Core 的 API 调用均违宪，Policy+审计拦截）。

原稿"APPLY 系统之间的调用"落为此义：**系统 A 要影响系统 B，就是 A 对 B 的文档 Apply 一个变更**（例如给 B 的 Rule 提案），B 的 Loop 看到后自行收敛。系统间没有点对点 RPC，只有文档面上的声明交换——这是"文档即协议"的机制基础。

## 2. 边界

**是**：写接口 + 字段级归属 + 冲突策略 + 审计记录。

**不是**：
- 不是 Event（A12：Apply 改状态，Event 只通知；Apply 完成会发 Event，反之不成立）；
- 不是任意补丁：只能 Apply 已注册类型的合法对象；
- 不是 RPC 总线：没有请求-响应语义，收敛是异步的（对方 Loop 何时处理不保证，只保证最终处理）。

## 3. 语义

```
apply(obj, opts)
  opts: {dryRun: bool, force: bool, fieldManager: "agent/ci-repair-agent"}

流程：读当前 → Policy 准入 → 三方合并（base/last/applied，SSA 语义）
     → 乐观锁提交（Revision）→ generation+1（若 spec 变）→ 发 DocApplied Event
冲突：两个 fieldManager 改同一字段且非幂等同值 → 冲突，后写者收 Conflict
     → 协商（人裁/force/改字段归属），默认不 force
```

幂等（P4）：Apply 相同内容为 no-op，不发 Event（防自我唤醒循环：自己 Apply 触发自己的 Loop）。

## 4. 生命周期

无生命周期（接口常在）。语义版本随 Scheme 演进（v1 SSA 子集：整文档归属；v2 字段级归属，见 open-questions）。

## 5. 与其他概念的关系

- Revision 提供乐观锁与历史（审计=git log）。
- Policy 在 Apply 内执行（准入是 Apply 的一环，不是旁挂）。
- Agent 写 Status、Loop 写 DriftReport、人写 Spec、系统间提案：四种写者同一接口、不同 fieldManager 与权限。

## 6. 设计规则

1. 所有写者一视同仁过 Policy；fieldManager 标识写者，责任可追溯到人/Agent。
2. Status 与 Spec 的写入权限分离：Agent 的 fieldManager 默认无 Spec 写权（P6）。
3. dryRun 必须零副作用且返回与真执行一致的 plan。
4. 系统间提案（跨系统 Apply）默认进入对方**待审区**（Proposal 状态），除非 Policy 放行——外部系统的自动合入永远是被授权的例外。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 文件夹后端实现 SSA 困难 | ⚠️ 中 | git 无字段级归属概念 | v1 整文档归属+行级 diff 模拟；v2 再上字段归属（登记 open-questions） |
| 自我唤醒循环 | ⚠️ 中 | Loop 写 Status 又触发自己 | no-op 不发 Event + fieldManager 白名单豁免自身 |
| 跨系统提案积压 | ⚠️ 低 | 待审区无人处理 | 提案 SLA：超时升级 Bind 的人（与 Loop Escalate 同机制） |

**结论：可行。SSA 是 k8s 已趟平的路，v1 用子集。**

## 8. 原始设计标注

- A12：Apply/Event 正交定界。
- 原稿"APPLY 系统之间的调用" → §1 的文档面交换语义。

## 9. 待决问题

见 open-questions.md#apply

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
