# 原始要求存档：背景（2026-11-20）

> 本文件是用户原稿的存档整理，作为 core_system 的立库依据。修改走 Apply；语义变更视为需求变更。
> 编号 R0-x 供 Goal/Rule 引用。

## R0.1 想做的

用 k8s 的逻辑，靠 loop 拉齐意图和现实。把声明做成一份**管理文档**，让它当整个项目的控制面。不是写完扔一边的设计稿，是运行时真正依据的那份。

## R0.2 文档同时管三样

1. **项目本身**：意图和约束都落在文档里，改文档就是改这个项目应该长成什么样。
2. **数据流**：数据从哪到哪、在什么权限下流动，写进文档而不是散在各处代码里——写出来才能被审、被约束。
3. **Agent**：Agent 对着文档跑，文档告诉每个 agent 要收敛到的意图和能碰的边界。管 agent 不靠盯着它，靠改它绑定的这份文档。

## R0.3 loop 做的核心是压缩

把现实压回文档，把散落各处的上下文压进文档。把"反复黏贴上下文"从根上换掉——上下文不活在聊天记录、代码和人脑子里，而活在文档里被持续压着。把全行业当手艺在做的 context engineering，变成系统去守的一条约束。

## R0.4 远景：文档即协议

每个系统的意图、约束、数据流都落在同一种文档面上，系统之间拿各自的文档去对齐，不靠人接线。文档本身成为协议。

## R0.5 顺着 AI 走

堆 agent、画 workflow、靠护栏和人审兜底，本质是补模型的不足；模型一强，这些补丁就多余。声明式相反：意图和约束不动，模型越强，loop 收敛越快越省，自治空间越大，要手写的命令式脚手架越少。AI 越强，这套机制只会越通畅。

## R0.6 赌注

把 k8s 的逻辑搬过来：不靠把单个 agent 做得更强，而是赢在它上面那层——声明期望，再用一个 loop 不停把现实拉齐到期望。云原生的人做了部署那半，对意图 reconcile 的那半还空着。这层最终会以一份文档的形式长出来。

## R0.7 核心是 K8s 的概念模式来管理文档

基础概念（原稿清单，展开见 concepts/）：

1. Agent —— 干活的，跑任务
2. ServiceDesc —— 系统描述
3. ServiceInstance —— 系统实例
4. Core —— 核心系统
   ---- global ----
5. Connector —— 用代码做胶水，连接现有系统和 workload
6. Ref —— 第三方链接，临时指针概念
7. Builtin —— 内部基础系统配置标记
8. Scheme —— 描述
9. Event —— 事件
10. APPLY —— 系统之间的调用

ServiceDesc 下面核心是文档（无系统时按文件夹保存）：Goal(必须)/Desc(必须)/Rule/WorkflowDesign/Metrics/Auth/DataDesign/DataMetrics/DeployDesign/CodeDesign。Builtin 有默认/强制/可选文档类型。

Agent 下有：Connector（type→对应代码，如 DSH）、Ref、BIND、ParentAgent/SubAgent、builtinRoot。

ServiceInstance 下有：Agent、DOCS（怎么实现 ServiceDesc、怎么约束保障）、MetricsInfo（收集系统，不是文档）。

WorkService（实际跑的系统，如 developer_system 下的 gitlab/jenkins）：Desc + Connector。

Loop：系统自动 event → event loop（查看 dsh）→ service agent 处理（可配置 bind 人）→ 按 docs 分析 → plan → 执行修复 → 验证通过 → 更新系统 status → agent 处理 → 汇总 → 观测。

要求：目录结构管理这些文档；标准软件思维扩展；概念边界不冲突；每概念 ≥3 个问题放另一文档；补齐没有的概念；基本按 K8s 概念边界和习惯命名；每个概念考虑可行性。
