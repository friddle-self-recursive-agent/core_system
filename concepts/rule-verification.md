# RuleVerification — 规则验证（code→scheme→ConnectorOps；agent→丢规则给 agent）

| 项 | 值 |
|---|---|
| K8s 对照 | admission/policy audit（代码级 gate）+ 语义评审（agent） |
| 形态 | Rule 条目验证元数据 + Scheme `ruleChecks` 注册表 + ConnectorOps 实现 / Agent verdict |
| 作用域 | Global（Builtin 规则）/ System（系统规则） |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. 定义

每条 Rule 除了"约束什么"，还必须说明**怎么验证**。验证模式三选一：

| 模式 | 适用 | 执行 | 失败语义 |
|---|---|---|---|
| `code` | 代码/结构可机械判定的规则 | **Rule → Scheme `ruleChecks` → `connectops-code-audit` ConnectorOps** 执行 checker | 结构化 findings；`error` 阻断 Verify/Deploy，`warn` 进 Report/Drift |
| `agent` | 需要语义判断、无法正则/结构化的规则 | 把规则原文（ref+hash）+ diff/上下文**丢给 agent 验证**，返回 verdict + 证据 | verdict=`fail` 阻断/升级；`unverified` 显式不通过，不冒充 |
| `human` | 高危/主观/需人裁的规则（缺省） | 人审 / ApprovalNeeded | 人未批不通过 |

一句话：**代码规则不要靠人肉盯，走 scheme 注册 + ConnectorOps 审核；agent 规则就直接丢给 agent 验证。**

## 2. 边界

**是**：规则验证方式的声明、注册、执行与判据；规则→注册表→实现的追溯链。

**不是**：
- 不是新写路径（审核只读，不改代码/文档）；
- 不是自动修复（findings 只报告，修复仍走提案/Apply）；
- 不是审批替代（`code`/`agent` 验证通过≠批准；高危仍走 Human/Gate）；
- 不是把所有规则都代码化（语义规则明确归 `agent`/`human`）。

## 3. 结构

### 3.1 Rule 条目元数据

```yaml
# Rule 文档中的条目（示意；正文仍是规则本体）
- id: R-ENG-1
  mode: code                 # code|agent|human（缺省 human）
  checker: connectorOps/code-audit#check   # code 模式必填：ConnectorOps 引用 + op
  targets: [go, ts]          # 可选：检查目标（语言/路径/仓库）
  severity: error            # error=阻断；warn=报告
  params: {maxFileLines: 1000}  # 可选：checker 参数（声明面）
- id: R-UX-3
  mode: agent                # 语义规则：丢给 agent 验证
  agent: service-agent       # 可选：指定验证 agent；缺省=负责该系统的 agent
  severity: error
```

### 3.2 Scheme 注册表（rule → scheme）

`core/scheme.yaml` 增加 `runtime.ruleChecks`（机读注册表；与 Rule 条目同 ruleId 双向追溯）：

```yaml
runtime:
  ruleChecks:
    - {ruleId: R-ENG-1, mode: code, checker: "connectorOps/code-audit#check", targets: [go, ts], severity: error}
    - {ruleId: R-UX-3, mode: agent, agent: service-agent, severity: error}
```

- 注册表是"规则→实现"的唯一机读映射；Rule 文档的元数据与注册表不一致=drift（checker 报）。
- `mode: code` 但注册表缺行/checker 不在册=**未生效**（不是"跳过"）；Verify 必须显式报 `unbound`。
- `mode: agent` 不注册 checker；把规则原文与上下文交给 agent。

### 3.3 ConnectorOps：`connectops-code-audit`

代码级审核的**新实现**（R-ENG-3：代码归 deploy-system 的 `connectops-code-audit` 仓；声明→代码→build 生效→运行时，每次变更必提交）：

```yaml
# WorkService（描述面）
apiVersion: core/v1
kind: WorkService
metadata: {name: code-audit, scope: global}
spec:
  category: tool
  connector:
    types: [local]
    impl: {kind: source, ref: ref/connectops-code-audit}
    scheme:
      ops: [check, verify]
      params: {timeout: 10m, concurrency: 4}   # 实现侧默认；可被 ConnectorOps config 覆写
  tools:
    - {name: check,  description: "按 ruleChecks 审核代码/仓库，返回 findings"}
    - {name: verify, description: "审核并汇总为 VerifyDoc 片段（check+summary）"}
---
# ConnectorOps（挂载面；dev-delivery 的 Verify 节点使用）
apiVersion: core/v1
kind: ConnectorOps
metadata: {name: code-audit, scope: builtin-developer-system}
spec:
  workservice: code-audit
  workflow: dev-delivery
  ops: [check, verify]
```

**`check` 契约**：

```
输入：{repo, ref, base?, rules?: [ruleId], targets?: [go,ts,...]}
输出：{
  findings: [{ruleId, mode:"code", file, line?, severity, message, evidence:{ref,hash}, checker}],
  summary: {checked, failed, warned, unbound},
  digest
}
```

- 只读、幂等；不写代码、不提交、不 Apply。
- 逐 ruleId 执行 scheme `ruleChecks` 的 checker；未注册/未实现=`unbound` finding（severity=error），不得静默跳过。
- findings 进 VerifyDoc / DriftReport / Report；`error` 阻断 Deploy；`warn` 记录并进报告。
- checker 可以是内置语言检查、shell lint 的封装或外部工具；**统一从 ConnectorOps 入口调用**，Agent 不直接跑散装命令。

## 4. 生命周期

1. Rule 条目声明 `mode/checker/agent/severity` → 与 scheme `ruleChecks` 对齐（Apply 时 lint）。
2. 开发流程 Execute 产出代码/diff 后进入 **Verify**：
   - `code` 规则 → `connectops-code-audit#check`（或 `verify`）；
   - `agent` 规则 → 组装规则 ref+hash + diff/上下文，丢给指定 agent / service agent；
   - `human` 规则 → ApprovalNeeded / Gate。
3. Verdict 汇总：全通过 → VerifyDoc / Status 追平；失败 → Report（`error` 阻断 Deploy，`warn` 记录）；agent `unverified` 按失败处理。
4. 修复 → 重新 Verify；审计留痕=apply_log/VerifyDoc/Event。

## 5. 与其他概念的关系

- **Rule / R-TYPE**：Rule 提供约束与验证元数据；R-TYPE 定义 type/checker；本文定义验证模式与执行面。
- **Scheme**：`ruleChecks` 是规则→checker 的机读注册表；scheme 是单一真相。
- **ConnectorOps / WorkService**：`code-audit` 是代码级审核的挂载实现（R-ENG-3 生命周期）。
- **Workflow（dev-delivery）**：Verify 节点是执行点；缺 checker/agent=unbound，不通过。
- **Agent**：`agent` 模式把规则丢给 agent；verdict 是证据，不是 Apply 权。
- **Report/DriftReport/ApprovalNeeded**：findings/verdict 的归档与升级出口。

## 6. 设计规则

1. **每条规则必须有验证模式**：`code|agent|human`；缺省 `human`（policy），不允许"无验证"的规则生效。
2. **代码规则三段链**：Rule 条目 → Scheme `ruleChecks` → `connectops-code-audit`；三段 ruleId 双向可追。
3. **code 规则无 checker=未生效**：Verify 报 `unbound`（error），不得跳过/默认通过。
4. **agent 规则就是丢给 agent**：规则原文（ref+hash）+ diff/上下文交给 agent；verdict 必须带证据；`unverified` 不算通过。
5. **审核只读**：`code-audit` 不修改代码/不提交/不 Apply；修复走提案/Apply。
6. **验证≠批准**：`code`/`agent` 通过不替代 Human/Gate 审批；高危规则仍走审批。
7. **Verify 节点必备**：dev-delivery 等代码开发流程的 Verify 必须跑 code 审核 + agent 规则验证；缺失=流程缺陷。
8. **失败显式**：checker 未注册/超时/崩溃、agent 不可用、verdict 不确定——全部显式失败/降级，不静默通过。
9. **可复现**：checker 版本/ruleChecks 版本/agent 模型与提示版本随 findings/verdict 记录；同输入同结果（agent 文本可异，结论须可解释）。
10. **安全**：`code-audit` 只读仓库/工作树，不接触 secret 值；输出不含明文凭据（R-PUB）。

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| code checker 覆盖不全 | ⚠️中 | 规则语义超出机械判定 | 明确 mode=code 的边界；判不准的归 agent/human；unbound 显式 |
| ruleChecks 与 Rule 文档漂移 | ⚠️中 | 改了规则没改注册表 | ruleId 双向追溯 + Apply lint + Verify 对账 |
| checker 性能/超时 | ⚠️中 | 全仓审核慢 | 增量（ref/base diff）+ 并发上限 + 超时显式失败 |
| agent verdict 不稳定 | ⚠️中 | 自由文本/误判 | 结构化 verdict + 证据 ref+hash + unverified 不通过 + 人审兜底 |
| 审核面变写面 | ❗高 | checker 顺手改代码 | 只读契约/沙箱/无 secret；修复走 Apply |
| Verify 被绕过 | ❗高 | 直接 Deploy | dev-delivery 相位序列强制 Execute→Verify→Deploy；缺 Verify=unbound/失败 |
| 新 ConnectorOps 落地成本 | ⚠️低 | 多一个实现仓 | 薄实现：执行注册表 checker + 汇总；复用现有 lint/语言工具 |

**结论：可行。code 规则经 scheme 注册由 ConnectorOps 统一审核，agent 规则直接丢给 agent；Verify 节点把两类验证变成硬 gate，零新写路径。**

## 8. 待决问题

见 [open-questions.md#rule-verification](../open-questions.md)（`connectops-code-audit` 实现范围、ruleChecks 首批条目、agent verdict schema）。

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
