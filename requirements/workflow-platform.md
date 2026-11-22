# 原始要求存档：workflow 平台化与 console 树（2026-11-22 第四批）

> 编号 R15-x。本批确定：console 第一层树形态、Agent 层智能表述、任务模板库操作集、workflow 平台化与全局去 loop 概念。

## R15.1 console 第一层 = Service 视角树

- 第一层用 Global/ServiceDesc → ServiceInstance → WorkService/Agent 一层层树的方式展示资源；**必须是树**。
- 渲染数据全部来自 Scheme + ops DB（无独立前端状态）。

## R15.2 Agent 层智能表述（更正）

- 四层执行图 Agent 层原文"dsh 基座上的 LLM agent"表述过窄：**agent 不一定是 dsh**；只是 LLM agent 才是"智能"的点，才有 binding 询问。智能属于 LLM agent 这个本质，与载体无关。

## R15.3 任务模板库操作集

- builtin 任务模板库（global/templates/task/，参数化）除引用外，还要 **import 与 delete**。
- 任务库 builtin 有内部模板（固定起源），自己可以调整这个模板——以 Scheme 方式描述，**其中包含提示词**。
- **import 导入现有系统**非常重要（把存量编排纳入模板库）。

## R15.4 Workflow 平台化

- **去掉 loop 概念**：全局改为 workflow（Loop 不再保留为口语）。
- workflow **可执行、可编辑**：可以展示现在的工作流（画图展示、查看事件、提交流转）；不同系统挂钩不同工作流；workflow 除工作流还有**数据流**。
- workflow 有默认文档：研发系统→修改发布→自动验证。入口 event（错误日志、新需求等）触发这个**全自动 workflow**；用完整 workflow 描述，每一步可以调整。
- workflow 在 global 里；**第三方也可以编辑** workflow（编辑/管理/导入/设置怎么触发）。
- 有专门用 agent **apply workflow**：流程用代码实现，也调用研发系统，也用自定义 connector，写代码做每层调用（闭环；也要监控能不能正常跑——就是 core_system 的 workflow 内置干的）。可以开启/disable。

## R15.5 落点

- 概念：concepts/workflow.md（平台化重写）、concepts/task-scheme.md（模板库操作集）、concepts/permission.md 等。
- 运行时：instance 仓 runtime/workflow-runtime.md（引擎管线+编辑+展示+数据流+落地 agent）、runtime/console-ui.md（第一层树）、runtime/execution-model.md（Agent 层更正）、runtime/bootstrap.md（自 loop/ 迁入）。
- 历史（annotations / concept-review / requirements 存档）不改写——它们是记录本身。
