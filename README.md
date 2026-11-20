# core_system — 根 ServiceDesc（SystemDesc）

> 本仓库不是一个"放设计稿的地方"。**本仓库本身就是一份 ServiceDesc**：core_system 的意图、约束、数据流的唯一权威声明。改这里=改系统（经 Apply + 权限系统）。
> 用户术语 SystemDesc = 本根对象（A18 待裁决是否全局改名）。

## 三仓即三概念（自我示范）

| 仓库 | 对应概念 | 放什么 |
|---|---|---|
| **core_system**（本仓） | ServiceDesc | 声明：requirements 存档、Goal/Desc、概念定义（Scheme 层）、builtin 服务声明、A-清单裁决台账 |
| [core_system_instance](https://github.com/friddle-self-recursive-agent/core_system_instance) | ServiceInstance | 实现形式：ImplDoc/VerifyDoc、运行时设计（四层执行、dsh 插件、总控界面、ops 日志）、Loop 管线与 bootstrap、developer_system(onedev)/storage(nas+oss)/deploy 设计、可行性报告 |
| [core_system_workservice](https://github.com/friddle-self-recursive-agent/core_system_workservice) | 代码 | Igniter、Core 进程、dsh 插件宿主、内置 Connector（builtin 系统=代码+connector 内置，R1.3） |

第一个 builtin service 是 **SelfRecursiveCore**（systems/builtin/self-recursive-core/）。按本描述开发、按本描述 Loop（R1.1）。

## 目录

```
core_system/
├── system.yaml / goal.md / desc.md      # 根 ServiceDesc 对象（含 acceptance 验收条款）
├── requirements/                        # 原始要求存档（R0 背景 / R1 运行时）
├── principles.md                        # 10 条设计原则（冲突裁决依据）
├── architecture.md                      # 四层一面 / 边界决策树 / K8s 对照
├── concepts/                            # 概念定义（终态制，rule.md；历史见 annotations.md）
├── doctypes/README.md                   # 文档类型注册表（含 Builtin 三档）
├── core/scheme.yaml                     # 首版 Scheme：类型注册 + 事件路由 + 运行时基座
├── systems/builtin/                     # 自举最小集四个 builtin service 声明
│   ├── self-recursive-core/             # 控制面本体
│   ├── developer-system/                # onedev + 本地 build（R1.6）
│   ├── deploy-system/                   # 当前机器 + install 流程执行者（R1.4）
│   └── storage-system/                  # 本地 git + NAS + OSS（R1.6）
├── annotations.md                       # A1–A24 裁决台账（在此直接标注裁决）
└── open-questions.md                    # 每概念 ≥3 问（含 v0.2 新概念）
```

## 阅读/审阅顺序

1. [requirements/runtime.md](requirements/runtime.md)（R1：三仓结构、运行时规则、builtin 系统、install 流程、功能设计）
2. [goal.md](goal.md)（验收条款 A1–A6）→ [principles.md](principles.md) → [architecture.md](architecture.md)
3. [concepts/](concepts/)（新读者从 README 索引入）
4. 实现与可行性 → instance 仓

## 审阅方式

在 [annotations.md](annotations.md) A-清单改"状态"列（采纳/驳回/存疑），或在各概念文档末尾"审阅标注区"追加行。设计方不逐条来问。

## Loop

管线状态机、自举顺序、developer_system 如何满足循环：全部在 instance 仓（loop/、impl/）。本仓只声明"必须有 Workflow、Workflow 的契约是什么"（concepts/workflow.md）。
