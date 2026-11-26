# CLI — 命令行（桌面同源控制面：读面 / Apply / Event 触发自循环）

| 项 | 值 |
|---|---|
| K8s 对照 | kubectl（同一 apiserver 的终端投影） |
| 形态 | 二进制 `corectl`（core_system_workservice `cmd/corectl`；control-plane client） |
| 作用域 | 与查看者相同：读面走 cored 现有读面；写面走请求级主体权限 |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. 定义

CLI 是 console/桌面功能的**同源投影**：桌面能看的、能提交的，命令行都能做；两者共用同一控制面、同一权限 / Apply / Event 链。CLI 不引入第二套 API、不直连 DB、不复制状态。

**自循环的点火也是系统事件**：`corectl loop` 发布 `LoopRequested`，经事件路由与唤醒桥由宿主拉起 core-headless 会话；外部 `ignite-loop.sh` 只作临时传输，桥验收后退役（R-UX-8）。

## 2. 边界

**是**：读面命令（report/status/get/workflows/runs/events/approvals/inbox/wakes/dispatches/sessions/proposals）、写面命令（apply/event publish/tick/loop）、自动化入口（`--json` + exit code）。

**不是**：

- 不是聊天 UI：会话/对话仍回 console（dsh 宿主）；CLI v1 只读会话状态与打印入口；
- 不是新写路径：写命令只走 `POST /v1/apply` 与 `POST /v1/events`，与桌面同一条权限/准入/事件链；
- 不是绕过审批：批准/驳回仍是既有审批动作（v1 只读账面，动作命令下一段）；
- 不是直接操作运行时：不杀进程、不改文件、不拼 shell 命令；
- 不是密钥出口：不打印 secret 值（`/v1/secrets` 只出名称）。

## 3. 命令与桌面对照

| 桌面（console） | CLI | 底层 |
|---|---|---|
| 关注报告 | `corectl report` | scheme + objects + workflows + runs + inbox + events 聚合 |
| 系统树/详情 | `corectl get ServiceDesc` / `get ServiceInstance` | `GET /v1/objects/{kind}` |
| 文档查看 | `corectl get <kind> <name>` / `cat <kind> <name>` | `GET /v1/objects/{kind}/{name}` |
| Workflows | `corectl workflows` / `runs` | `GET /v1/workflows` / `/v1/workflows/runs` |
| 事件 | `corectl events` / `event publish` | `GET /v1/events` / `POST /v1/events` |
| 审批/收件箱 | `corectl approvals` / `inbox` | `GET /v1/approvals` / `/v1/inbox` |
| 连接 | `corectl get WorkService|ConnectorOps|Provider` | `GET /v1/objects/{kind}` |
| 会话 | `corectl sessions` / `wakes` | `GET /v1/sessions` / `/v1/agents/wakes` |
| 文档编辑（Apply） | `corectl apply -f <file> [--dry-run]` | `POST /v1/apply`（唯一写入口） |
| 自循环点火 | `corectl loop` | `POST /v1/events` type=`LoopRequested` |

- 全局：`--server`（缺省 `CORED_ADDR` → `~/.dsh/cored.addr`）、`--subject`、`--role/--group`、`--json`、`--timeout`。
- 写命令主体缺省 `console-operator` + `role/global/admin`（部署侧可覆写）；与桌面 `config.applySubject` 同口径。

## 4. 事件触发自循环（不是外面点火）

```
corectl loop
  → POST /v1/events {type: LoopRequested, dedupKey: <loop>:<round>}
  → eventbus（同一条主干：去重/派发/event_log 零旁路）
  → dispatch 表 {on: LoopRequested, dispatch: root-agent}
  → TriggerHub → WakeLog（唤醒投影 /v1/agents/wakes）
  → WakeNotifier（CORE_SYSTEM_WAKE_ADDR 显式开启）
  → POST 宿主 plugin /wake/spawn（固定载荷，不执行命令）
  → 宿主校验 type=LoopRequested ∧ agent=root → 单飞 pgrep
  → 执行部署侧 config.loopCommand / CORE_SYSTEM_LOOP_CMD（固定命令）
  → core-headless loop 会话启动（loop-next.md + 运行护栏）
```

失败语义（全部显式，不冒充成功）：

| 情形 | 行为 |
|---|---|
| 未配 `CORE_SYSTEM_WAKE_ADDR` | cored 只落唤醒投影，零出站（纯投影部署不翻转） |
| 未配 loop 命令 | 宿主 503；事件仍受理在账；日志明确 |
| 已有 loop 在跑 | 宿主 200 `already-running` + **pending 持久化**（同因合并，0600）；循环退出后定时重试自动拉起，事件不丢 |
| 宿主不可达/拉起失败 | cored stderr 注记；事件仍受理；下一事件重试 |
| cored 不可达 | CLI 非 0 退出 + HTTP 错误，不伪造回执 |

`corectl tick` 发布 `ReconcileTick`，触发 core-workflow 对账 run，**不**拉起 loop 会话；两者语义分立。

**会话结束也是 CLI 提交**：loop 会话不得自行 `setsid` 点火下一轮；结束前用 `corectl loop` 提交下一轮（`ignite-loop.sh` 护栏 6）。若提交时本轮仍在收尾，宿主返回 `already-running` 并落 pending，退出后自动拉起——循环的每一轮都由事件链驱动。

## 5. 生命周期

提交（CLI/任何主体）→ event_log 归档 → dispatch 判定 → 唤醒投影 → 宿主桥拉起/单飞 → loop 会话执行 → SessionClosed / 下一轮事件 → 循环。事件可丢可重；循环正确性不依赖单条事件（P3 level-triggered），下一次 `LoopRequested` 或巡检事件会再次拉起。

## 6. 与其他概念的关系

- **Apply**：`corectl apply` 是 Apply 的终端入口；dry-run/权限/乐观锁/事件与桌面一致。
- **Event**：`LoopRequested` 是注册事件类型；发布走既有发布面（source 服务侧恒 human）。
- **Workflow**：`ReconcileTick` 触发 core-workflow；`tick` 不越权造 run。
- **Agent**：唤醒投影锚 root；宿主桥只拉起部署侧配置的 loop 命令，不发明 agent。
- **Console**：同一读面/写面；CLI 是桌面之外的第二入口，不是第二真相。
- **Permission**：请求级主体同一判定；无 role=拒绝，无旁路。
- **Context**：loop 会话开局仍按 R-CTX-8 装配四族上下文。

## 7. 设计规则

1. **同源**：每个命令必须映射既有读面或写面；CLI 无独立状态、无第二套 API/DB。
2. **写面唯一**：写命令只走 `POST /v1/apply` 与 `POST /v1/events`（secrets 走既有门控面）；禁止直连 DB/文件/进程。
3. **主体一致**：请求级主体与桌面同口径；缺省 admin 仅部署侧便利，可覆写为受限 role。
4. **事件点火**：自循环唯一触发=`LoopRequested` 事件；外部 ignite 脚本在桥验收后退役，不得与事件点火并行。
5. **单飞与去重**：同一 host/profile 已有 loop 会话=不重复拉起，但事件**挂起 pending**（持久化、同因合并），循环退出后自动拉起；事件 dedupKey 由调用方提供（缺省 CLI 时间戳）。
6. **命令固定**：宿主执行的 loop 命令是部署侧配置项；事件载荷只进日志，不参与命令构造（零注入面）。
7. **地址发现**：宿主就绪写 `~/.dsh/cored.addr`（0600）；CLI 读取优先级 `--server` > `CORED_ADDR` > 文件；地址属部署侧，不入公开仓。
8. **显式降级**：cored 不可达、桥缺席、命令未配、单飞命中——都必须有明确输出/状态码，不静默、不伪造成功。
9. **可审计**：事件回执 eventId/dedupKey、CLI 主体、宿主 spawned/already-running 日志三处可对账；`--json` 供自动化。
10. **不扩权**：v1 不提供审批动作/会话发送命令；下一段落地时仍走既有门控，不开旁路。

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

## 8. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| cored 随机端口导致 CLI 不可用 | ⚠️中 | 每次重启端口变化 | 宿主就绪写 `~/.dsh/cored.addr`；CLI 缺省读取；`--server` 可覆写 |
| 重复拉起循环 | ❗高 | 事件重放/多主体同时提交→多个 loop 会话抢写 | 宿主 `pgrep -f` 单飞 + `already-running`；事件 dedupKey；不重复 spawn |
| 命令注入 | ❗高 | 事件载荷进入 shell | 宿主只 spawn 固定配置命令，参数空数组，`shell=false`；载荷只进日志 |
| 权限旁路 | ❗高 | CLI 默认 admin 被滥用 | 与桌面同一主体判定；部署侧可覆写受限 role；公开文档只写机制 |
| 桥不可用/宿主重启 | ⚠️中 | 事件受理但 loop 不拉起 | 显式 503/日志；下一事件重试；外部 ignite 保留到桥验收（过渡期） |
| 事件丢失/乱序 | ⚠️低 | 单条 LoopRequested 丢失 | level-triggered：下一事件/巡检事件再触发；不依赖单条 |
| CLI 与桌面双源 | ⚠️低 | CLI 自行拼状态 | 全部读 cored 现有端点；无本地状态；`--json` 原样透出 |
| 地址文件被其他 profile 覆盖 | ⚠️低 | 多 profile 同机写同一文件 | 仅 core-system 配 `coredAddrFile`；其他 profile 不写；文件 0600 |

**结论：可行。CLI 是既有控制面的薄客户端；事件点火复用既有事件总线/路由/唤醒面，新增的只有宿主唤醒桥与部署侧 loop 命令配置，零新写路径、零新权限模型。**

## 9. 待决问题

见 [open-questions.md#cli](../open-questions.md)（多 profile 地址文件命名、审批/会话命令、CLI watch 三项）。

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
