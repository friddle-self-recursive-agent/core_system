# ServiceDesc — 系统声明

| 项 | 值 |
|---|---|
| K8s 对照 | Deployment / 自定义资源的 **Spec 部分** |
| 形态 | 一个目录（systems/<name>/）= 一个 ServiceDesc；v1 无系统时，文件夹即存储 |
| 作用域 | Global（每个系统平级） |
| 状态 | 定稿（终态制，rule.md） |

## 1. 定义

ServiceDesc 是"一个系统应该长成什么样"的全部意图：一组按 DocType 注册的文档 + 一份元数据。**改 ServiceDesc 就是改系统**——这是本设计"文档即控制面"的直接体现。

它只回答 **What / Why / 约束**，绝不回答 How（How 在 Instance 的实现侧 Docs）。

## 2. 边界

**是**：意图的集合体。包含：Goal（必须）、Desc（必须）、Rule、WorkflowDesign、Metrics、DataDesign、DataMetrics、Auth、DeployDesign、CodeDesign（均可选/默认，见 doctypes）。

**不是**：
- 不含 Status（P2：现实回写在 Instance）；
- 不含实现说明（"我用 gitlab CI 实现了它" 属于 Instance 侧 ImplDoc）；
- 不含外部系统本体（gitlab 是 WorkService，Desc 里只有对它的引用）；
- 不是文件夹里随便加文件：未注册 DocType 的文档 权限系统 拒收（Scheme 闸门）。

## 3. 对象结构

```yaml
# systems/developer-system/system.yaml
apiVersion: core/v1
kind: ServiceDesc
metadata:
 name: developer-system
 scope: global
 labels: {domain: devtools}
 finalizers: [core/wipe-workservice-side-effects]
spec:
 goalRef: goal.md # 必须
 descRef: desc.md # 必须
 docs: # 其余按 DocType 注册表
 - rule/workflow-rule.md
 - metrics.md
 - data-design.md
 workserviceRefs: # 依赖的外部系统（Ref/WorkService 引用）
 - workservice/gitlab
 - workservice/jenkins
 instances: # 期望的实例清单（像 replicas）
 - name: ci
 agentRefs: [agent/ci-repair-agent]
status: {} # 空。Desc 无 Status，Status 长在 Instance
```

## 4. 生命周期

```
创建（Apply，权限系统 校验必须文档齐全）→ Active
 ↑ 改文档 → generation+1 → 触发所属 Loop reconcile（level-triggered）
删除请求 → 执行外部清理（WorkService.tools 成对 cleanup op）→ 真删（删目录即级联，含全部 Instance）
```

版本与代数：每次 spec 侧变更 `metadata.generation` +1，Instance 的 `status.observedGeneration` 追赶它——收敛进度一眼可见。

## 5. 与其他概念的关系

- 是 ServiceInstance 的 owner（级联创建/删除）。
- 通过 workserviceRefs 声明对外部的依赖；实际驱动靠 Connector。
- 它的文档集是 Agent 的**主要上下文来源**（docs权限系统.read 授权）。

## 6. 设计规则

1. Goal/Desc 缺失的 ServiceDesc 不予创建（DocType 强制级）。
2. Desc 内禁止出现具体厂商/实例名（"用 gitlab"是 WorkService 层的事；Desc 说"需要代码托管能力"）——**能力声明，不绑实现**。验收：文档里出现 `gitlab.com/...` 之类即 权限系统 警告。
3. 文档间引用用相对路径或 `system://<name>/<doc>` URI，不用裸文件路径（为将来换存储留缝）。
4. 一个系统一个目录，目录名=对象名（instance 仓 layout.md）。
- 终态制：本文档只展示最终结果，变更历史只在 annotations.md（[rule.md](../rule.md) R-DOC-1/3）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 自然语言 Goal 不可判定 | ⚠️ 中 | "系统要好用"没法验收 | Goal 模板强制含可验证的验收条款（verify 段）；Verifying 阶段以此为判据 |
| 文档互相矛盾 | ⚠️ 中 | Rule 与 WorkflowDesign 冲突 | 权限系统 的 Lint 级校验（交叉引用检查）+ Loop 分析阶段显式报告矛盾 |
| 能力抽象过度 | ⚠️ 低 | "不绑实现"抽象到没人懂 | v1 允许注释性提及实现，仅规范性字段禁止 |

**结论：可行。核心风险是自然语言的可判定性，用模板+验证段压住。**

## 8. 待决问题

见 open-questions.md#servicedesc

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
