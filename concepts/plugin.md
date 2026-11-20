# Plugin — dsh 基座与直控通道

| 项 | 值 |
|---|---|
| K8s 对照 | kubelet 插件体系（device plugin / CRI）+ kubectl 插件的合体位置 |
| 形态 | 对象（global/plugins/）+ dsh 进程内插件契约 |
| 作用域 | Global |
| 状态 | 设计稿 v0.2（R1.2.1、R1.5.1） |

## 1. 定义

**基础 agent 是 dsh**：所有 Agent 的运行时基座是 dsh（分布式 shell，已有实现）。Agent 不是独立框架，而是"dsh 进程 + 一组 Plugin"。**root agent 可以直控下面 dsh 的 agent**：root 与子 agent 之间不是消息自治，而是存在一条直控通道（root 可以直接下发、中断、查询子 agent 的任务）——这条通道本身也是一个 Plugin（control plugin）。总控界面同样是 Plugin（console plugin，见 instance 仓 runtime/console-ui.md）。

Plugin 契约（所有插件实现同一接口）：

```
init(config) -> void
onEvent(evt) -> actions[]        # 事件响应（可返回待执行动作）
dispatch(task) -> result         # 接任务（直控通道调用点）
report() -> status               # 状态上报（供 Status/观测面）
shutdown() -> void               # 优雅退出
```

## 2. 边界

**是**：dsh 进程内的能力扩展机制；Agent 运行时=dsh+插件集。

**不是**：
- 不是 Connector（Connector 对接外部系统；Plugin 扩展 agent 自身：控制、界面、本地执行、上报）；
- 不是独立进程编排（插件跑在 dsh 进程内，无自己的生命周期）；
- 不做业务判断（判断仍属于 Agent 读文档；Plugin 是手，不是脑）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Plugin
metadata:
  name: console
  scope: global
spec:
  host: dsh                # 宿主运行时（v1 只有 dsh）
  version: v0.1
  provides: [ui-console, resource-tree, info-stream]
  grants:                  # 插件权限（P7 的一部分）
    read: [{scope: "*"}]   # console 只读全库（展示用）
    write: []
  entry: src/console       # 代码位置（workservice 仓）
```

首批插件：`control`（root 直控通道）、`console`（总控界面）、`exec-local`（本地命令执行，deploy/developer 共用）、`reporter`（Status/Event 上报）。

## 4. 与其他概念的关系

- Agent.spec 的 connectors 引用 Connector（对外）；Agent 运行时加载 Plugin（对内）。权限面=P7 并集（两者都计入）。
- root 直控：control plugin 维护 root↔sub 的派发/中断/查询原语；Loop 引擎的 Dispatch 最终落到 control plugin。
- console plugin 消费 Scheme 全量类型表渲染资源树（功能设计 R1.5.1）。

## 5. 设计规则

1. 插件无自主意图：不读 Goal、不发起修复；只响应（onEvent/dispatch）。
2. 插件权限最小声明（grants 白名单），console 类插件默认只读。
3. control 通道单向（root→sub）；sub 之间不互控。
4. 插件代码入 workservice 仓（内置）或 Connector 仓（外部贡献），注册即 Scheme 项。

## 6. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| dsh 生态绑定 | ⚠️ 中 | Agent 层与 dsh 强耦合 | host 字段抽象运行时；契约五方法与 dsh 无关，未来可换宿主 |
| 插件崩溃连坐 | ⚠️ 低 | 同进程插件互相拖垮 | v1 接受（dsh 单进程简单性优先）；崩溃=HeartbeatLost→root 重启 |
| 直控通道滥用 | ⚠️ 中 | 绕过 Loop 直接操子 agent | control 原语全部过审计（ops DB）；Policy 拦截高危直控 |

**结论：可行。dsh 已有实现（用户既有资产），契约五方法是薄抽象。**

## 7. 原始设计标注

- A21（见 annotations.md）：R1.2.1 的落地。

## 8. 待决问题

见 open-questions.md#plugin

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
