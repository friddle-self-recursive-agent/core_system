# Core — 控制面

| 项 | 值 |
|---|---|
| K8s 对照 | kube-apiserver + etcd + controller-manager（合并为一个小进程） |
| 形态 | **默认由 dsh plugin 承载**：core plugin 于 dsh 宿主内提供控制面；P9 例外清单不变 |
| 作用域 | Builtin |
| 状态 | 定稿（终态制，rule.md） |

## 1. 定义

Core 是控制面运行时：它读文档面、跑 Workflow 引擎、分发 Event、执行 Apply 写路径。它**自己不定义任何意图**——其行为由 core.desc 等 Builtin 文档声明（自描述，见 instance 仓 runtime/bootstrap.md）。

**承载形态**：默认用 **dsh plugin 承接 Core**——Apply/Event 分发/Workflow 引擎/Scheme/权限系统 打包为 dsh 宿主里的 `core` 插件，不再另立独立服务形态；**单独的 Core 界面暂缓**——界面就是 console plugin，后面做通畅了再单独做 Core 界面。

职责五件套：

1. **存储**：封装文档库（v1 = git 仓库目录），提供带乐观锁的读写接口（见 Revision）。
2. **校验**：所有写入按 Scheme 注册的类型 + 权限系统准入校验。
3. **分发**：Event 的产生、去重、路由（按 Selector 派发给 Workflow/Agent）。
4. **调度**：Workflow 引擎——把"该收敛了"变成对具体 Agent 的任务派发（含 backoff）。
5. **观测汇聚**：接收 DriftReport / MetricsInfo 注册表，供观测面查询。

## 2. 边界

**是**：一个进程、一组接口。文档库里没有"Core 对象"，只有 Core 的自描述文档。

**不是**：
- 不是存储本身（存储是 git/目录/未来 DB，Core 只是封装）；
- 不是 Scheme（Scheme 是注册表**数据**，Core 是读它的**进程**）；
- 不是 Builtin（Builtin 是 scope **标记**，Core 是被标记的对象之一）；
- 不执行任务（执行是 Agent）；不连外部系统（连接是 ConnectorOps）；不自带独立界面（界面=console plugin）；
- 不做业务判断（判断是 Agent 读文档后做的）。

## 3. 自描述结构

```yaml
# core/core.desc.yaml（Builtin scope，强制人审）
apiVersion: core/v1
kind: ServiceDesc
metadata:
 name: core
 scope: builtin
 labels: { tier: control-plane }
spec:
 goal: "维持文档面与控制面自身的一致、可用、可审计"
 docs: # 引用 core/ 目录下的 Builtin 文档
 - rule: core.rule.md # 如：所有写入必须留审计记录
 - auth: core.auth.md # 谁能改 Builtin
 workflows: # Core 自身也受 Workflow 管
 - ref: workflow/core-self-check
status: # 由 builtinRoot Agent 回写
 conditions:
 - {type: Available, status: "True"}
 - {type: SelfConsistent, status: "True"} # Scheme 与文档库实际内容一致
 observedGeneration: 3
```

## 4. 生命周期

启动（bootstrap 点火 → 起 dsh 宿主 → 载入 core plugin）→ 加载 Scheme → 校验文档库自洽 → 启动 Workflow 引擎 → 常驻（驻于 dsh 宿主内）。升级 = Apply 新的 core.desc + builtinRoot 滚动重启自身（类似 k8s self-hosting）。Core 崩溃 → builtinRoot 拉起；builtinRoot 崩溃 → 看门狗（进程级，文档外最后一道，见 bootstrap）。

## 5. 与其他概念的关系

- 依赖 Scheme（启动时加载）、权限系统（写入时调用）、Revision（写入时比较）。
- 被 builtinRoot Agent 管理（唯一的上级是点火器）。
- 对 Agent：Core 是任务派发者；对 Event：是总线；对 Apply：是唯一入口。

## 6. 设计规则

1. Core 进程内**禁止**出现任何具体系统的业务逻辑；出现即违宪（P10）。
2. Core 所有接口必须可 dry-run（预演不改状态）。
3. Core 无状态化优先：状态全在文档面，Core 重启不丢脑。
4. 文档库写入必须串行化（单写者队列），读并发不限。
- 终态制：本文档只展示最终结果，变更历史只在 annotations.md（[rule.md](../rule.md) R-DOC-1/3）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| git 目录无事务/watch | ⚠️ 中 | 并发写、变更通知都要自己做 | 单写者队列 + 轮询 diff/git hook 模拟 watch；Repository 接口留换 DB 的缝 |
| Core 自管自举 | ⚠️ 中 | 升级自己时最容易锁死 | 双分区法：新 Core 就绪前旧 Core 不退场；回滚 = reset 到上一代 core.desc |
| 单点 | ⚠️ 低（v1） | v1 单实例可接受 | 接口幂等化，未来可多实例+选主 |

**结论：可行，条件是接受"git 后端 + 串行写"的 v1 约束。**

## 8. 待决问题

见 open-questions.md#core

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
