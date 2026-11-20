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
