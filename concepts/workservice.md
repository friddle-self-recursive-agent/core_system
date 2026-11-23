# WorkService — 外部系统的完整管理描述（六面体）

| 项 | 值 |
|---|---|
| K8s 对照 | Node + 其上的 exporter/工具面（一个对象管全一个外部节点） |
| 形态 | workservices/<name>/workservice.yaml（六面体 spec） |
| 作用域 | Global |
| 状态 | 定稿（终态制，rule.md） |

## 1. 层级判例

```
System = deploy_system（ServiceDesc）
实例 = sybran 开发实例（ServiceInstance）
WorkService = jenkins / onedev / bug-management 系统
```

即：deploy_system 声明意图 → sybran 实例落地 → 依赖 jenkins/onedev/bug-management 三个 WorkService。WorkService 不限于 devops——**任何被纳管的外部系统**（含代码仓库，含 bug-management 这类业务系统）都是。

## 2. 定义（六个面）

WorkService 是对一个外部系统的**完整管理描述**，一个对象六个面：

| 面 | 内容 | 吸收自 |
|---|---|---|
| **connector 连接** | 类型标注 types、实现绑定 impl（tool/image/source+Ref）、download、使用 schema、usage | **原 ConnectorProvider 整体并入** |
| **observation 观测** | 这个服务怎么被观测：指标点、日志位、告警面（意图描述，数据本体在 MetricsInfo） | 新增 |
| **data 数据** | 它管理什么数据、数据在哪、怎么取（供 Ref 解析与 DataMetrics 用） | 新增 |
| **flows 流程** | 它的业务流程描述（jenkins 的 pipeline 阶段、bug 系统的状态机…） | 新增 |
| **runtime 运行状态观测** | 健康/版本/可达的探针定义（→ status conditions） | 原 status 职责正式化 |
| **tools 工具与调用描述** | 提供哪些工具、怎么调用：ops 集、参数、llmPrompt 注入说明 | 原 ConnectorOps 的描述层 |

## 3. 边界

**是**：外部系统的六面体管理描述。独立工具（dsh/http/gitfs）以 `category: tool` 的 WorkService 注册——本机工具也是一种"服务"。

**不是**：
- 不是 ServiceInstance（判例已定：Instance 是本系统 Desc 的落地；WorkService 是外部系统本体描述）；
- 不是只有连接（ 复审的"空壳"判断错误——它应该更大而不是更小， 驳回）；
- 不存数据本体（data 面只描述在哪/怎么取）；
- 不做业务判断（判断仍属 Agent）。

## 4. 对象结构

```yaml
apiVersion: core/v1
kind: WorkService
metadata:
 name: onedev
 scope: global
 labels: {category: developer} # tool 型：category: tool
spec:
 connector: # 连接面（原 ConnectorProvider）
 types: [scm, ci]
 impl: {kind: source, ref: ref/workservice-repo}
 download: "git://…/sybran_usage_connector/connectors/onedev" # 用法型驱动：部署侧仓（rule.md R-ENG-3）
 scheme: {ops: [checkout, build-status, gate-status, verify, watch]}
 usage: "REST+git 双通道…"
 llmPrompt: "你可用 onedev 工具…"
 observation: # 观测面
 metrics: [{name: pickup_p95, query: "..."}, {name: runners, query: "..."}]
 logs: {ref: ref/onedev-logs}
 data: # 数据面
 entities: [{name: project, store: ref/onedev-db, access: via-connector}]
 flows: # 流程面
 - {name: build-flow, stages: [checkout, build, gate, report]}
 runtime: # 运行状态观测面
 probes: [{httpGet: /api/server-info, period: 1m}, {version: "16..18"}]
 tools: # 工具与调用描述面
 - {op: checkout, params: {ref: string}, idempotent: true}
 - {op: build-status, params: {commit, result}, idempotent: true}
status:
 conditions: [Reachable, VersionSupported] # runtime 面探针回写
```

## 5. 生命周期

在册（Apply）→ runtime 面探针持续回写 status → 观测/流程/工具描述变更=意图变更（走 Apply，触发相关 Workflow 对账）→ 注销（**副作用清理是它的 tools/flows 职责之一**： 后无系统级 Finalizer，删一个 WorkService 前由其工具清单里声明的清理流程执行）。

## 6. 与其他概念的关系

- **ConnectorOps**（concepts/connector.md）：挂载使用面——其 provider 字段 起指向 **WorkService**（连接面）；工具描述来自 tools 面。
- Ref 解析：data 面是"code/资源在哪"的权威来源之一（如 onedev 源码地址=developer_system+onedev WorkService data 面）。
- Observation/Metrics：观测面的 query 定义 → MetricsInfo 采集。
- 层级判例成为 architecture 边界树 Q2 的标准答案。

## 7. 设计规则

1. 六面皆可为空（tool 型常只有 connector+tools）；但 connector.types 与 tools 至少一面非空（否则无从纳管）。
2. llmPrompt/download 在连接面必填（沿 规则）。
3. 观测/数据/流程是**意图描述**——把抓取数据写进来即违反 Q1（数据进 MetricsInfo）。
4. 命名解析（无前缀=默认 org）规则随连接面迁入，作用于 impl/download 引用。
5. **capabilities 词表归 Scheme 管**：global 一套内置词表（scheme.yaml 维护）；非 global 的系统域自加自管（服务前缀命名，如 `<system>:<capability>`）——防"按能力引用"退化成"按名字引用"。
6. **外部系统所有权冲突不裁决**：同一外部系统被两个系统纳管/同时操作闹崩，不在本系统职责内（各自 connector 自行幂等防护）。
5. 删除清理职责显式写在 tools/flows 里（代替 Finalizer）：有外部创建动作的 tools 必须成对声明清理 op（Lint）。
7. **驱动代码分仓**（rule.md R-ENG-3）：workservice 仓 connectors/ 只放 builtin 驱动（gitfs/dsh）；用法型驱动（onedev/nas/oss 等，换部署即换）在部署侧独立仓（如 sybran_usage_connector），impl/download 指向实际所在仓，依赖方向恒为用法仓→workservice。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule.md)）。

## 8. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 六面体写成大部头 | ⚠️ 中 | 每个外部系统文档变厚 | 面可空+模板生成（install 模板直接产出六面体骨架）；大部头恰恰是"纳管完整"的证据 |
| tool 型 WorkService 泛滥 | ⚠️ 低 | 什么小工具都注册 | category: tool 走轻量模板（两面即可） |
| 删除清理不写导致残留 | ⚠️ 中 | 无 Finalizer 后靠显式声明 | 规则 5 强制成对声明+Lint |

**结论：可行。六面体让 WorkService 成为"外部系统的一切皆文档"的落点，与 ServiceDesc（内部系统的一切皆文档）对偶。**

## 9. 待决问题

见 open-questions.md#workservice

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
