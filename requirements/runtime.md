# 原始要求存档：运行时要求（2026-11-20 第二批）

> 编号 R1-x。本批确定三仓结构与运行时骨架，是 v0.2 设计的直接依据。

## R1.1 三仓结构（Desc / Instance / WorkService 自我示范）

- 根项目改名 **core_system**，本身做成一个符合描述的 SystemDesc；放"具体的要求"部分。
- 第一个 builtin service 是 **SelfRecursiveCore**。按这个描述开发系统、按这个描述进行 Loop。
- 新建 **friddle-self-recursive-agent/core_system_instance**：放具体实现形式，大部分设计放这里。
- 新建 **friddle-self-recursive-agent/core_system_workservice**：放具体核心代码。

## R1.2 运行时规则

1. 基础 agent 是 **dsh**；root agent 可以直控下面 dsh 的 agent；用 **Plugin** 实现这套。
2. **ServiceDesc 默认是文档**。
3. ServiceInstance 有 DOCS 文档对应 ServiceDesc（描述怎么对应）；但具体执行时可以自定义 **Scheme**，然后基础调度常见任务（可配置）。默认层级是 **用户意图 → Agent → Scheme → 代码** 四层。因为长时间运行系统肯定不能依赖 Agent 自定义（即兴）。

## R1.3 内部基础系统（builtin，代码和 connector 内置）

- **builtin_developer_system**：默认就是本地 build。
- **builtin_deploy_system**：内置就是当前机器。
- **builtin_storage_system**：文档默认存本地服务（本地文件夹 git）。

## R1.4 install service 流程

install service → 到 https://github.com/friddle-self-recursive-agent 找 **template** → template 中找到后看描述 → 继续找 **WorkServiceTemplate** → 询问（用户）并安装。

**WorkServiceTemplate**（Scheme 级别）描述需要资源（如镜像文件地址）。Scheme 由设计方定义；WorkServiceTemplate 是 builtin 的 Scheme。

## R1.5 功能设计

1. dsh 之后有**总控 Plugin 界面**：所有资源类型在界面上要能一个个点进去；所有资源相关的都要能点进去；**以资源为视角是第一层**。
2. 第二层是**信息流视角**（监控、状态、数据事件）。
4. 默认用 **git 管理文档**，**数据库管理文档 ops 的历史操作日志**。

## R1.6 首个设计对象

- 做 **developer_system 的设计**（不是实现）：如何利用现有 **onedev**、如何开发、如何满足开始的循环。
- storage_system 有 **nas 和 oss**。
- 以上同时也是**可行性报告**；可行性报告放到 instance 仓里。

## R1.7 补充概念

（原稿留空——由设计方补齐：见 concepts/plugin.md、concepts/task-scheme.md、concepts/template.md，及 annotations.md A18–A24。）

---

# 原始要求存档：服务控制台与跨 agent（2026-11-20 第三批）

> 编号 R2-x。本批来自 MVP 开发会话，Desc 侧只存需求；实现设计进 instance 仓（acceptance/console/console-ui.md、runtime/cross-agent.md、mvp/）。

## R2.1 builtin 语义澄清

builtin 的含义就是**最基础的循环调用代码**。例如使用 agent dsh，就必然需要内置调用 dsh 的基础代码。这些基础内置项未来可以被复杂的真实系统**取代**（可安装）。→ 已按终态制并入 concepts/builtin.md（A55）。

## R2.2 跨 agent 调用

- 研究深层 agent 跨 agent 调用（deepseek-agent 跨 agent 调用），看有没有现成机制；基于 dsh 插件看能不能做。
- 结论落 instance 仓（研究：dsh `ctx.agents` 注册表 + typert 远程通道）。

## R2.3 控制台服务关注区（默认工作区）

- 默认工作区改为**服务关注区**：一层层点进去，打开相应服务。
- 服务详情页可见：**文档 / 资源 / 状态 / agent 状态 / 跨系统申请 / 事件**。
- 详情页每一项都能用**该 service 的 agent** 开一个对话 session（直接跳转到对应 service 相应的 agent），能看到相应 session、直接对话。
- 若插件机制做不到这些定制 → **fork dsh**，做一个完整 plan 实现这批定制功能。

## R2.4 数据库初始化

实现时记住 ops 数据库的初始化（幂等脚本、随代码走；见 rule/rule_eng.md R-ENG-2）。

## R2.5 默认代码语言

默认 **Go / TS** 写代码（控制面服务用 Go，dsh 插件/前端用 TS）。写入规则（rule/rule_eng.md R-ENG-1）。

---

# 原始要求存档：workflow 规则化与定时驱动（2026-11-20 第四批）

> 编号 R3-x。

## R3.1 系统文档作为默认 skill 喂给 agent

root agent 调用时，在某项任务里把**系统本身作为默认 skill** 喂给 agent：agent 调用相应命令来获得文档和文档信息；并监控 agent 跑通。→ concepts/agent.md「默认 Skill」、concepts/builtin.md。

## R3.2 workflow = 一条规则（可配置）

- workflow 可以**开启/关闭**（spec.enabled）。
- 可以配置**涉及哪些 service、怎么涉及**（spec.services）。
- 配置**相应 LLM 是什么**——在 workflow 配置中配置（spec.llm）。
- 开始设计的 workflow 用 LLM 描述，并可用相应**图展示** workflow 流程（规则 7：spec→LLM 白话描述+mermaid 图，按需生成不入库）。
→ concepts/workflow.md、core/scheme.yaml Workflow kind。

## R3.3 核心定时驱动与上游汇聚

理论上应有一个**核心定时驱动**：system 的 agent 定期处理 event、处理报告，转给上游 global（event/报告在 builtin 走本地）；上游拿到后做 loop 做分析。→ concepts/workflow.md 设计规则 6；实现见 instance 仓 loop/loop.md。

## R3.4 git 预装假设

默认假设 **git 是机器已经安装了的**（文档存储=本地文件夹 git 的前提）。→ core/scheme.yaml runtime.storage。
