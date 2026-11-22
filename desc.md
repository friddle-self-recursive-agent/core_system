---
name: desc
docType: Desc
scope: core_system
ownerRefs: [{kind: ServiceDesc, name: core_system}]
---
# Desc — core_system 是什么

## overview

core_system 是自递归（self-recursive）控制面的根声明：一套用文档声明意图、用 Workflow 拉齐现实的机制（概念全集见 concepts/）。它管理的第一个对象是它自己——本仓的三仓拆分就是 Desc/Instance/WorkService 三个概念的第一次落地：

| 仓 | 对应概念 | 内容 |
|---|---|---|
| core_system（本仓） | ServiceDesc | 根声明：requirements 存档、Goal/Rule、概念定义（Scheme 层）、builtin 服务声明、A-清单裁决台账 |
| core_system_instance | ServiceInstance | 实现形式：ImplDoc（怎么实现/怎么保障）、运行时设计（四层执行模型、dsh 插件、总控界面、ops 日志）、Workflow 管线与 bootstrap、developer_system(onedev)/storage(nas+oss)/deploy 设计、可行性报告 |
| core_system_workservice | 代码 | 核心代码：Igniter、Core 进程、dsh 插件宿主、内置 Connector |

## boundaries（是什么/不是什么）

**是**：
- 声明的唯一权威源（Spec 在这里，Status 在 instance 仓）；
- 概念（Scheme）的定义处：26 个概念、文档类型、WorkServiceTemplate/TaskScheme 等 builtin Scheme；
- 裁决台账：annotations.md 的 A-清单跟踪每条对原稿的异议。

**不是**：
- 不含实现细节（怎么点火、界面长什么样 → instance 仓）；
- 不含代码（→ workservice 仓）；
- 不是只读归档：改这里就是改系统（经 Apply + 权限系统）。

## 自举最小集（builtinServices）

| 服务 | 默认实现 | 职责 |
|---|---|---|
| self-recursive-core | 核心进程（workservice 仓） | 控制面：Apply/Event/Workflow 引擎/Scheme/权限系统（R1.1） |
| builtin-developer-system | 本地 build + onedev | 开发流水线（R1.3, R1.6） |
| builtin-deploy-system | 当前机器 | 安装执行器：WorkServiceTemplate 的落地者（R1.3, R1.4） |
| builtin-storage-system | 本地文件夹 git + NAS + OSS | 文档存储与备份、镜像/产物对象存储（R1.3, R1.6） |
