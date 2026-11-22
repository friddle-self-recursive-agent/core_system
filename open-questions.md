# Open Questions（活问题清单）

> 只列**当前概念体系**下仍未决的问题；已删除/被替换概念的问题不再收录（终态制，rule.md）。已裁决的问题直接进概念文档终态。
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

## 横切

1. 文档量与 ops DB 规模增长后的对账/归档节奏。
2. LLM 网关单点依赖的兜底（多 provider 路由已有，故障演练未做）。
