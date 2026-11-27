# Open Questions（活问题清单）

> 只列**当前概念体系**下仍未决的问题；已删除/被替换概念的问题不再收录（终态制，rule/rule.md）。已裁决的问题直接进概念文档终态。
> 复审状态（2026-11-22 批复）：Core 部署模式、dispatch 谓词、类型演进、metrics 摘要 workflow、capabilities 词表、Ref 缓存与上限、死信熔断、Apply 文档级粒度、登录 builtin 最小实现（dsh token）、Agent↔Service 协议——均已裁决入文档（concepts 各文件 + instance 仓 runtime/agent-service-protocol.md、runtime/bootstrap.md）。

## core

1. HA/吞吐量模式的**量化切换条件**（对象数/事件吞吐/延迟阈值定在多少）——当前无 HA 要求，不阻塞，真有瓶颈前定出阈值即可。
2. event 过滤与多调用瓶颈出现时的第一个演进动作（过滤下推到 ConnectorOps？分片？）——预案级别即可。

## scheme

1. dispatch 谓词语法细化：exists/notIn 已定必做；前缀/正则的语法与性能边界（是否允许在热路径跑正则）。
2. capabilities 全局词表的首版清单（哪些词进 scheme.yaml 内置集）。

## event

1. **kafka 上不上**：core_event_operator 默认本地队列已定，kafka 作分发通道"两可"——待真实事件量数据再定（与 runtime/event-bus.md N2 阶段对齐）。

## workflow

1. dev-delivery 刹车默认值（cooldown/maxMutations）上线后按实际误报率调优。
2. 第三方导入支持的源格式范围（v1 只做既有 git 服务流水线描述？还是加通用 yaml）。

## agent

1. Agent↔Service 协议字段定稿复核（runtime/agent-service-protocol.md envelope）——实现前过一遍。
2. catalog 摘要的缓存失效粒度（对象级失效 vs 每意图全量重生成）。

## serviceinstance / metrics

1. metrics 默认 workflow 的报告格式与存放位置细化（Memory？DriftReport？独立 report doc）——默认 7 天记录/1 天一次报告已定，格式未定。

## docs operator（core_docs_operator）

1. mongodb/pg 接入的实际时机与判定标准（何时 git 后端真的不够）。

## permission / user-system

1. dsh token 登录的协议细节（token 交换/过期/与飞书 SSO 的关系）——builtin 最小实现已定（直接复用 dsh token），细节随实现定。

## ref

1. 解析缓存 TTL 默认值（cacheTtl 语义已定，数值待真实负载）。

## task-scheme

1. 模板 import 的外部格式清单（既有 CI 描述如何映射到确定性步骤图）——import 机制已定，映射规则待样例驱动。

## business-system

1. 财务流水外部源接入方式（银行/支付流水导入声明与对账口径）——约束层只管"流水必须可溯源"（R-BIZ-2/R-BIZ-4），导入实现属实例层，首实例（业务实例）冷启动时定。
2. R-BIZ-1/4 的 lint checker 落点（core_design `lint/` 还是实例侧投产检查）——投产前定。
3. Template（appliesTo: servicedesc）出业务系统模具（五域骨架模板）的时机——v1 不做，首个实例跑通后评估。

## console（会话/循环可见性）

1. **loop session 与 workflow/run/node 关联缺失**：loop 是 core-headless dsh session，不是 Workflow run；Workflows 页的 core-workflow run 是另一条事件 run，不代表 loop。当前只能从会话侧栏 / `#/chat/core-headless` 的「宿主全部会话」看全文，`#/session/<id>` 只出 Trajectory。下一段方案：Session 元数据带 `workflowRef/runRef/phase/loopSeq/taskRef`，或 `LoopRequested` 路由到 `loop-workflow` run；console 增「当前循环」卡（状态/最后一步/关联 run/会话深链）。
2. **会话深链不自动更新**：点击会话时 URL 不变成 `#/session/<id>`（当前只能手填 ID）；`#/session` 的「切回 Chat 视图」按钮当前禁用。下一段：选择即更新 hash、Chat/Trajectory 双视图可用、行菜单提供「复制会话链接」。

## task-scheduler（多任务并发）

1. 并发上限默认值（maxConcurrent=4/perService=2/perRepo=1）与调参口径——上线后按资源/冲突率实测。
2. Task DAG 与调度器落点（cored 组件 vs workflow vs plugin），任务状态持久化/租约回收。
3. spawn 桥的会话关联：Task.status.agentSession 回填、会话完成/失败回调、单飞与 pending。
4. worktree/分支与合并队列实现（developer-system）；同 repo 放宽 perRepo 的安全条件。
5. 任务 `touches` 写集声明质量与冲突误判——漏声明会导致并发互踩。

## attention（关注报告）

1. attention 条数上限（默认 7）与严重度权重、「忽略/这也要看」反馈的调参口径——上线后按误报率与使用率定。
2. 报告缓存粒度（viewer 指纹 vs 角色集指纹）与 TTL 默认值（暂定 5m）。
3. clear 区窗口（只列本窗口 or 最近 N 次检查）——先按本窗口，实测后定。

## cli

1. 多 profile 同机的 cored 地址文件命名（当前仅 core-system 写 `~/.dsh/cored.addr`；接入/core-headless 是否需要独立文件待定）。
2. CLI 审批动作（approve/reject）与会话发送命令的落点/权限口径——v1 只读账面，动作命令下一段。
3. CLI `watch`（事件订阅流）是否复用 dsh 会话流/SSE，还是轮询 `/v1/events?since=`。

## rule-verification（规则验证）

1. `connectops-code-audit` 实现范围/语言与首批 checker（R-ENG-1 代码语言、R-PUB-1 脱敏、R-DOC-6 侧车等）；仓库落 deploy-system `connectops-code-audit`，build 生效后接 Verify。
2. `ruleChecks` 首批条目与 ruleId 注册；现有 shell lint（personal-info/metadatainfo）是保留独立 checker 还是统一收编为 code-audit op。
3. agent verdict 的结构化 schema（`pass|fail|unverified`+证据 ref+hash+理由）与落点（VerifyDoc / DriftReport / Event）。
4. Verify 节点如何取得 diff/base（git ref/工作树）与增量审核边界（全仓 vs base..ref）。

## storage（文档库 sqlite / git 导出）

1. 定时导出 git + push 的实现落点（`corectl export` / 独立 exporter / 部署 cron/systemd timer）与规则（频率/分支/远端/失败告警）——下一段。
2. sqlite 逐次正文历史 `doc_history` 表与 `GET /v1/rev-content` 读面——下一段；当前 sqlite 后端 503 诚实降级，不得用周期 git 快照冒充。
3. 多 cored 共库写竞争（core-system/第二实例 若同 sqlite）——迁移期第二实例暂显式 git，后续定单写者/写面归属。
4. 跨进程 sqlite 变更通知：`Watch` 当前为进程内写直通知，多 cored 共享 docs DB 时权限热装载/缓存不跨进程；下一段用 DB 轮询代际或事件总线补齐。

## 横切

1. 文档量与 ops DB 规模增长后的对账/归档节奏。
2. LLM 网关单点依赖的兜底（多 provider 路由已有，故障演练未做）。
3. **公开仓 git 历史泄露处置**（2026-11-22 发现，规范见 rule/rule_pub.md R-PUB）：core_system_instance 历史含内网 IP/内网域名（提交 18d738f、f8c3758 等），core_design 历史含个人模型选型名；工作树均已脱敏（R-PUB-1，lint/personal-info.sh 守护）。待裁决：① git filter-repo 重写两仓历史 + force push；② 不动历史（IP 为 RFC1918 内网段，换地址即失效；选型名非凭据）。若选①，此后建议给各仓加 CI lint（R-TYPE：R-PUB-1 已是 lint 型）。
