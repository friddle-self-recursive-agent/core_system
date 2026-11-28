# ServiceDesc — 系统声明

| 项 | 值 |
|---|---|
| K8s 对照 | Deployment / 自定义资源的 **Spec 部分** |
| 形态 | 一个目录（systems/<name>/）= 一个 ServiceDesc；v1 无系统时，文件夹即存储 |
| 作用域 | Global（每个系统平级） |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. 定义

ServiceDesc 是"一个系统应该长成什么样"的全部意图：一组按 DocType 注册的文档 + 一份元数据。**改 ServiceDesc 就是改系统**——这是本设计"文档即控制面"的直接体现。

它只回答 **What / Why / 约束**，绝不回答 How（How 在 Instance 的实现侧 Docs）。

## 2. 边界

**是**：意图的集合体。包含：Goal（必须）、Desc（必须）、Rule、WorkflowDesign、Metrics、DataDesign、DataMetrics、Auth、DeployDesign、CodeDesign（均可选/默认，见 doctypes）。

**不是**：
- 不含 Status（P2：现实回写在 Instance）；
- 不含实现说明（"我用 gitlab CI 实现了它" 属于 Instance 侧 ImplDoc）；
- **紧急情况不打折**：需要紧急变更时，**ServiceInstance 与代码一起更新**（意图与实现同批落地）——不存在"能力声明不绑实现所以紧急只改一半"；声明与实现的一致性由 Workflow 对账追平；
- 不含外部系统本体（gitlab 是 WorkService，Desc 里只有对它的引用）；
- 不是文件夹里随便加文件：未注册 DocType 的文档 权限系统 拒收（Scheme 闸门）；
- 不含管理分组结构：`service_group` 是 metadata 上的**纯分类属性**（管理与分类、展示按组展开），不是新 Kind、不构成层级、不改变系统的平级结构（见 §3.1）。

## 3. 对象结构

```yaml
# systems/developer-system/system.yaml
apiVersion: core/v1
kind: ServiceDesc
 metadata:
 name: developer-system
 scope: global
 labels: {domain: devtools}
 serviceGroup: devtools # service_group：管理分类属性（纯展示分组，见 §3.1）
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

### 3.1 service_group（服务分组）

service_group 是 ServiceDesc `metadata.serviceGroup` 上的一个**纯管理分类属性**：给平级的系统贴一个组名，唯一用途是**管理与分类、展示面按组展开折叠**（控制台系统列表、跨系统对账视图等按组聚合展示）。

| 项 | 值 |
|---|---|
| 形态 | metadata 属性（字符串组名），**不是新 Kind、不是对象** |
| 结构影响 | 零。系统仍然全局平级；组是展示层的虚分组，不进 spec、不进存储结构 |
| 缺省 | 未设置=「未分组」桶（展示面归拢，不隐身） |
| 唯一性 | 组名自由字符串，多系统可同组；v1 不注册词表（需要收口时再挂 tagType 词表） |
| 生命周期 | 改组=改 metadata 属性，非 spec 变更：不触发 `generation+1`、不触发 reconcile、无任何级联 |

**边界**：组不嵌套组（一层）；组不参与调度/权限/触发等任何运行语义——任何实现面不得读该字段做路由或过滤决策；系统间引用（workserviceRefs/instances）与组无关，跨组引用合法。与 `metadata.labels` 的分工：labels 是通用打标（多值、检索），service_group 是单一展示分组（单值、组展开），语义上不混用。

## 4. 生命周期

```
创建（Apply，权限系统 校验必须文档齐全）→ Active
 ↑ 改文档 → generation+1 → 触发所属 Workflow reconcile（level-triggered）
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
5. **设计文档与实现文档的 1:N `[metadata 关联]` 追踪（R-DOC-9）**：`ServiceDesc` 下的 1 篇设计文档（`Goal`、`Desc`、`Rule`、`CodeDesign`、`DataDesign`、`WorkflowDesign` 等）在现实中往往对应 **N 篇** `ServiceInstance` 侧的实现文档（`ImplDoc`）或验证文档（`VerifyDoc`）（跨多实例或同一实例内跨多模块/多代码仓）。系统通过文档 frontmatter `metadata.trace` 与侧车 `<doc>.md.metadatainfo` 的 `trace` 字段建立**双向 1:N 可追踪关联**：
   - **设计文档侧（1 侧）**：可声明 `trace.requires: [ImplDoc, VerifyDoc]`（要求必须有下游实现/验证覆盖），由 `DocIndex` 自动反向聚合填充（原定时导出器联动已随 2026-11-28 R-DOC-7 修订退役——导出=release 节点执行面） `trace.implemented_by: [{doc, instance, sections?, designRev, status: synced|stale}]` 与 `trace.verified_by: [...]`（1 对 N 映射表）；
   - **过期与孤儿检测**：当 1 侧设计文档更新（`resourceVersion` / `blobSha` 推进）时，沿 `trace.implemented_by` 关联的全部 N 篇 `ImplDoc` / `VerifyDoc` 自动标为 `stale`（并在全局相关性 `Relevance(DesignDoc, ImplDoc)` 中赋予结构耦合先验满分 `100`），驱动 Workflow 对账产出 `DriftReport`；无任何 `ImplDoc` 关联的设计条款将被检出为「孤儿设计（Orphaned Design）」。
6. **service_group 只做管理与分类展示（§3.1）**：组是平级系统的虚分组，缺省「未分组」；改组不动 spec/`generation`、不触发 reconcile；实现面禁止读该字段做调度/权限/路由决策。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 自然语言 Goal 不可判定 | ⚠️ 中 | "系统要好用"没法验收 | Goal 模板强制含可验证的验收条款（verify 段）；Verifying 阶段以此为判据 |
| 文档互相矛盾 | ⚠️ 中 | Rule 与 WorkflowDesign 冲突 | 权限系统 的 Lint 级校验（交叉引用检查）+ Workflow 分析阶段显式报告矛盾 |
| 能力抽象过度 | ⚠️ 低 | "不绑实现"抽象到没人懂 | v1 允许注释性提及实现，仅规范性字段禁止 |
| service_group 被误当层级/结构 | ⚠️ 低 | 组被当成组织结构，进而想挂权限/调度语义 | 概念层锁死「纯属性+仅展示」+设计规则 6 禁实现面读它做路由；真要层级时另立概念评审 |

**结论：可行。核心风险是自然语言的可判定性，用模板+验证段压住。**

## 8. 待决问题

见 open-questions.md#servicedesc

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
