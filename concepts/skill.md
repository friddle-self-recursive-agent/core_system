# Skill — 工具使用的缓存（会话层经验）

| 项 | 值 |
|---|---|
| K8s 对照 | 无对应（镜像 layer cache 的类比：用过就留，下次直接用） |
| 形态 | 缓存对象：Instance/Agent 会话层（systems/<s>/instances/<i>/skills/<name>.yaml） |
| 作用域 | Instance（高频可提升为 Global） |
| 状态 | 设计稿 v0.6（R5 新增，A38："工具使用地方可以用这个缓存成为 skill"） |

## 1. 定义

Ops 在某处被成功使用后，**使用方式可缓存为 Skill**：一份"这个工具在这里怎么用"的实战经验（注入提示+调用示例），供后续会话按需加载——Agent 不必每次重学工具用法。

来源有三：
1. **Provider.llmPrompt**（出厂说明书，静态）；
2. **实战调用模式**（SessionLog 里的成功调用：参数、顺序、坑位）→ 自动/半自动沉淀；
3. **人写**（Runbook 精华片段提升）。

## 2. 边界

**是**：工具使用的缓存（prompt+示例+适用条件）。

**不是**：
- 不是 TaskScheme（Skill 是"怎么用好工具"的经验；TaskScheme 是确定性步骤图）；
- 不是文档面的意图（Skill 是缓存，可随时重建/丢弃；丢弃损失的是效率不是正确性）；
- 不是 Plugin（不扩展 dsh；只是给会话注入的文本）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Skill
metadata:
  name: onedev-build-report
  scope: builtin-developer-system/local-ci
spec:
  sourceOps: ops/onedev-ci          # 来源工具
  when: {task: build-and-verify}    # 适用条件（任务/场景）
  prompt: |                         # 注入提示（派生自 provider.llmPrompt + 实战修正）
    回写构建状态用 build-status 而非直接 REST；失败重试前先 gate-status 读现状…
  examples:                         # 成功调用示例（脱敏）
    - {op: checkout, args: {ref: main}, outcome: ok}
  origin: {sessionRef: session-2026…, cachedAt: 2026-11-20}
  cache权限系统: {ttl: 30d, invalidateOn: {providerVersionChange: true}}
```

## 4. 生命周期

使用处缓存（Session 成功调用后沉淀）→ 会话按需加载（与文档按需加载同机制，docs权限系统.onDemand）→ 高频 Skill 提升为 Global（多人/多实例复用）或反哺回 Provider.usage/llmPrompt → 过期/失效（TTL、provider 版本变更、示例失败率升高）自动丢弃。

## 5. 与其他概念的关系

- 上游：ConnectorOps（来源工具）、Provider.llmPrompt（出厂底稿）、SessionLog（实战记录）。
- 消费：Agent 会话按需注入（与 L0 最低必载同级的是"任务相关 Skill 集"）。
- console：Skill 可视（哪些工具用得熟、缓存了多少经验）——资源树一类节点。

## 6. 设计规则

1. Skill 是缓存不是真相：任何 Skill 与 Provider 契约冲突时，以契约为准并使 Skill 失效。
2. 沉淀自动、提升人工（提升到 Global 走 Apply+人审）。
3. 示例必须脱敏（凭证模式扫描同规则）。
4. invalidateOn.providerVersionChange 默认 true（工具变了经验作废）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 错误经验被缓存放大 | ⚠️ 中 | 一次侥幸成功沉淀成坏 Skill | 示例失败率监控；与契约冲突即失效；TTL 兜底 |
| 缓存膨胀 | ⚠️ 低 | Skill 越攒越多 | 按引用热度淘汰（LRU）+ TTL |

**结论：可行。本质是 prompt/示例缓存，纯增量机制，风险由"缓存非真相"原则框住。**

## 8. 原始设计标注

- A38（R5）：新增概念（工具使用处缓存为 skill）。

## 9. 待决问题

见 open-questions.md#skill

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
