# 总体架构与概念地图

## 1. 四层一面

见 [README.md](README.md) §2 架构图。分层职责：

| 层 | 组成 | 只负责 | 绝不负责 |
|---|---|---|---|
| 文档面 | ServiceDesc / ServiceInstance / 各对象声明 | 存意图与约束 | 执行任何动作 |
| 控制面 | Core 进程（Apply / Workflow 引擎 / Event 分发 / Scheme / 权限系统） | 存取校验文档、调度收敛 | 干活（干活是 Agent 的事） |
| 执行面 | Agent / Connector / WorkService | 收敛意图、驱动外部系统 | 定义意图 |
| 观测面 | Event 汇聚 / MetricsInfo / DriftReport | 让人看得见 | 反过来直接改状态 |

## 2. 概念关系图

```
                    ┌────────── Core（控制面进程，Builtin scope 自描述）──────────┐
                    │  Scheme ── Apply ── 权限系统 ── Workflow引擎 ── Event分发          │
                    └───────┬───────────────────────────────────┬────────────────┘
                            │ 管理                                │ 分发
              ┌─────────────▼──────────┐            ┌───────────▼─────────────┐
              │ builtinRoot Agent       │            │ Event（触发信号）        │
              └─────────────┬──────────┘            └───────────▲─────────────┘
                            │ 拉起/管理                            │ 产生
              ┌─────────────▼────────────────────────────────────┴──────────────┐
              │ Agent（Global，含 SubAgent 树；Bind → 人）                        │
              └──────┬──────────────────────────────────────────────┬────────────┘
                     │ 收敛（ownerRef）                              │ 驱动
        ┌────────────▼────────────┐                      ┌──────────▼──────────┐
        │ ServiceDesc（系统声明）   │   实例化             │ Connector（胶水代码）│
        │  Goal Desc Rule ...docs │──────────────┐       └──────────┬──────────┘
        └────────────▲───────────┘              │                  │ 调用
                     │ ownerRef                  │       ┌──────────▼──────────┐
        ┌────────────┴─────────────┐            └──────►│ WorkService（外部系统）│
        │ ServiceInstance（现实化）  │                    │ gitlab / jenkins ... │
        │  Agent引用 + 实现Docs      │──── MetricsInfo ──►└──────────────────────┘
        │  + MetricsInfo + Status   │──── Ref（临时指针，指向不在册资源）
        └───────────────────────────┘
```

## 3. 边界决策树

拿到任何东西，按顺序问四个问题，答案唯一决定它归哪个概念：

```
Q1 它是"意图/描述"还是"现实/数据"？
    意图 ──────────────► 走文档对象（继续 Q2）
    现实/数据 ─────────► MetricsInfo / Event / Status（不是文档对象）

Q2 它是本系统内的还是外部第三方的？
    本系统意图 ────────► ServiceDesc 下的文档（继续 Q3 定类型）
    外部系统且常驻管理 ► WorkService（六面体：连接/观测/数据/流程/运行状态/工具，A53）
    外部资源仅临时指路 ► Ref（逻辑声明，A46）

Q3 声明侧还是实现侧？
    "应该是什么" ──────► ServiceDesc/docs（Goal/Rule/...）
    "我怎么实现/怎么保障► ServiceInstance/docs（实现Docs + 验证Docs）

Q4 它是类型还是实例？
    类型定义 ──────────► Scheme / DocType（注册表）
    具体一份 ──────────► 对应 Kind 的对象
```

典型判例：

- "系统必须每天备份" → Q1 意图 → Q2 内 → Q3 声明侧 → Rule 文档。
- "昨天备份实际耗时 40min" → Q1 现实 → MetricsInfo，不是文档。
- "用 gitlab 做代码托管" → 外部常驻 → WorkService(gitlab) + Connector(gitlab driver)。
- "这篇第三方教程先记个链接" → Ref（临时，带 TTL）。
- "Prometheus 抓取配置" → 意图，但属于实现层 → Instance 侧实现 Docs；Prometheus 本体是 WorkService。

## 4. K8s 对照总表

| 本系统 | K8s | 差异要点 |
|---|---|---|
| 文档面（文件夹+git） | etcd | 无事务无 watch，由 Core 封装补齐（可行性⚠️见 instance 仓 feasibility.md） |
| Core 进程 | kube-apiserver + controller-manager | 合并为一个小进程，v1 不拆 |
| Scheme | scheme + CRD 机制 | 同时注册对象类型与文档类型 |
| ServiceDesc | Deployment（Spec 部分） | Spec 是一组异构文档而非单 yaml |
| ServiceInstance | Pod | 含实现侧 Docs 与 MetricsInfo |
| Agent | Pod 内执行体 + controller 意识 | Agent 是全局对象，Instance 引用而非内嵌（A3） |
| WorkService | Node / External Provider | 声明"外部有能力的东西" |
| WorkService（六面体）/ConnectorOps | Node+exporter / 已装工具入口 | v0.13：Provider 并入 WorkService 连接面；层级判例 deploy_system→sybran 实例→jenkins/onedev/bugmgmt（A53） |
| Ref | ObjectReference/ExternalName | 增加 TTL/owner，明确"临时"语义 |
| Event | Event + watch | 只触发不修改，消费按 P3 |
| Apply | kubectl apply / SSA | 同时是系统间调用的唯一形态 |
| Workflow | Controller/Reconciler | 一等对象，可配置触发源与升级策略 |
| 权限系统 | Admission Webhook | 文档即权限，准入必选 |
| ~~Finalizer~~ | ~~Finalizer~~ | 已删除（A51）：清理=WorkService tools/flows 成对声明 |
| Bind | RBAC Binding + scheduler binding | 人也是一等被绑定对象 |
| Builtin | kube-system（仅"自带"类比） | v0.5：仅起源标记，无强制要求（A37） |

## 5. 命名规范

沿用 K8s 习惯：

1. **Kind** 用大驼峰单数：`Agent`、`ServiceDesc`、`ServiceInstance`。
2. 对象 name 用小写中划线：`ci-repair-agent`、`developer-system`。
3. apiVersion 统一 `core/v1`，文档类型注册在 `doc.core/v1`（见 DocType）。
4. 布尔字段用正面语义（`readOnly` 而非 `noWrite`）；时间用 RFC3339；时长用 `30s/5m` 字符串。
5. 保留字：`metadata`（name/labels/annotations/ownerRefs/finalizers/resourceVersion）、`spec`、`status`，任何文档类型不得挪用。

## 6. 反模式清单（看到即判"不合设计"）

- 在 Workflow 里写 if-else 分支脚本 → 那是 workflow 引擎，本系统只声明意图（原稿"Workflow Design"文档是**给人看的功能流设计**，不是可执行编排，见 doctypes）。
- Agent 绕过 Apply 直接改文件 → 破坏 P4/P7。
- Status 由人手写 → 破坏 P2。
- 把抓取到的监控数据写成 .md 文档 → 破坏 Q1（现实不是文档），应进 MetricsInfo。
- 为一个外部系统写第二套 Connector 而不注册类型 → 破坏 Scheme 唯一注册。
