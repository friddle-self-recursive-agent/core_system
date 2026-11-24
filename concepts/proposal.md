# Proposal — 需求提案（console 提需求 → 审批 → 派工的一等对象）

| 项 | 值 |
|---|---|
| K8s 对照 | Issue/Enhancement 提案（人发起的意图对象，走评审流）——"需求先成为对象再成为工作"的答案 |
| 形态 | 对象（`global/proposals/<name>.yaml | systems/<s>/proposals/<name>.yaml`），builtin Scheme 之一 |
| 作用域 | Global 或 System |
| 状态 | 定稿（终态制，rule.md） |

## 1. 定义

Proposal 把"用户提的一个需求"变成**一等文档对象**：标题/目标/验收标准/影响面/优先级/提出人六要素入库，
走审批（高危人审、低危可自动），批准后派单 `apply-workflow` agent 落地为文档草稿（docsRoot 对象）或
部署侧任务文件，产物落盘后状态回写 `landed`。提交入口=console「需求提案」屏（像在对话里提要求一样提交），
写路径唯一入口=apply 管线（concepts/apply.md）——提案不是旁路通道，是过同一三步闸门的普通对象。

```
console「需求提案」提交（表单 → 草稿 → fromDraft Apply）
  → Proposal 对象在库（status=submitted）
  → 审批分流（priority × 部署侧分流配置）：高危=人审（ApprovalNeeded 自产→审批屏/通知）；低危可自动（auto-approve）
  → 批准（fromDraft Apply fieldManager=console:approve → status=approved）
      → apply-workflow agent 派单受理投影（GET /v1/agents/dispatches——受理≠拉起）
  → 产出：文档草稿（docsRoot 对象）或部署侧任务文件（产物指针=spec.landing）
  → 状态回写 landed（真实落盘=apply-workflow agent 真实拉起段，declared-deferred）
```

## 2. 边界

**是**：需求的一等对象化（意图层的结构化载体）；审批链的复用方（ApprovalNeeded/ApprovalGranted/
ApprovalRejected 事件族 + approval_log 判定账 + `console:approve`/`console:reject` 约定串）；
派单面的第二来源（flowbind 派单投影 `kind=proposal` 行——v0.50 workflow 骨架派单之外的新触发源）。

**不是**：
- 不是 Workflow（Workflow=对账节拍/相位机，由事件触发循环；Proposal=一次需求的静态载体，
  由人提交、走审批——Proposal 批准后**派单给 agent**，不把自己变成 Workflow 对象）；
- 不是 TaskScheme（TaskScheme=确定性步骤执行图；Proposal 无步骤图，批准后的步骤规划是
  apply-workflow agent 的活——Proposal 只带目标与验收标准，不带 how）；
- 不是 Goal 的替代（Goal 挂在 ServiceDesc 之下描述系统目标；Proposal 是需求进入系统的入口
  动作——落地时的验收标准词汇与 Goal.acceptance 同源，落点不同）；
- 不自动执行代码（红线：Proposal 状态机本身不 enable 任何 workflow、不触发任何代码执行——
  批准只产派单**受理投影**，真实拉起=dsh 会话挂载，declared-deferred）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Proposal
metadata:
  name: add-dark-mode
  scope: global
spec:
  title: 编辑器深色模式
  summary: 对象编辑器提供深色主题，降低夜间巡检时的视觉疲劳
  acceptance:                       # 可验证条目（Verify 相位逐条复测）
    - 主题切换即时生效且刷新后保持
    - 对比度满足 WCAG AA
  impact: core_system_dsh_plugin console 编辑器屏（纯前端改动，无写路径变更）
  priority: low                     # low|normal|high|critical——审批分流判定输入
  proposer: console-operator        # 主体标识（审计回链 apply_log.subject）
  status: submitted                 # draft|submitted|approved|rejected|landed（闭合集）
  landing: {target: doc}            # 产物指针：doc=docsRoot 对象草稿 | task=部署侧任务文件
```

## 4. 状态机与审批链

- **状态闭合集**：`draft|submitted|approved|rejected|landed`。`draft`=本地草稿未入册（不入库，
  只在草稿缓存）；`submitted`=已提交待审；`approved`/`rejected`=判定终态（可审计）；`landed`=产物
  已落盘回写。迁移纪律=写面主体（checker 只校验枚举闭合集不校验迁移序——console 屏只出合法动作
  按钮，越序直写=普通 apply 行为，审计账可查）；机械迁移序收紧=checker 后续段余量。
- **审批分流（低危/高危可配）**：部署侧配置 `--proposal-auto-approve=<priority csv>`（如 `low`）。
  命中清单的 priority 提交即自动批准（引擎自写 `fieldManager=proposal:auto`，approval_log 落
  granted 行 judgedBy=引擎主体）；未命中（缺省=全部）走人审：引擎自产 `ApprovalNeeded`
  （involved=Proposal/<scope>/<name>，dedupKey=`proposal:<obj>`，source=core——event.md 规则 14），
  审批屏待审区与通知链（route `notification/*`）随行。
- **批准/驳回动作复用审批链**：批准=草稿（status=approved）→ `fromDraft` Apply
  `fieldManager=console:approve`（approval_log granted 行 + `ApprovalGranted` 事件，source=human——
  判定是人做出的）；驳回=草稿（status=rejected）→ `fromDraft` Apply `fieldManager=console:reject`
  （approval_log rejected 行 + `ApprovalRejected` 事件）。判定落账与事件同拍（apply_log 承落库流水、
  approval_log 承判定、事件族承通知——三账同源可回指）。

## 4.5 录入方式：对话优先（2026-11-24 用户裁决）

Proposal 的录入**默认是对话**，不是表单（表单仅作降级/精修）。用户原话：「改成对话。完整询问方式填完 scheme 的东西或者自动补充。然后对话完成后。提交节点让 LLM 自动生成相应的格式。然后确认后自动补全。」

流程：
1. **完整询问**：录入 agent 按 spec 字段逐项询问（标题/目标/验收标准/影响面/优先级/产物落点/提出人），每项给默认值与示例；能从上下文推断的**自动补充**（如提出人=当前主体、优先级缺省 low、产物落点缺省 doc）；
2. **自由描述**：用户也可以只写一段话，由录入 agent 抽取/补全字段；
3. **字段进度可见**：对话侧实时显示「已填/待补」字段卡片，可随时手改；
4. **提交节点 LLM 生成格式**：字段齐后，由 LLM 依 Proposal spec 生成对象（YAML/结构化 JSON），先过 R-PUB lint + spec 准入 dry-run；不通过→指出具体字段让用户补；
5. **确认后自动补全**：用户确认预览（diff）后一键提交（草稿→Apply；高危→ApprovalNeeded），系统自动补缺省字段（proposer/timestamps/status）；
6. **降级**：LLM 不可用或用户选择「直接填表」→ 回退现有表单；两者产同一 Proposal 对象（无双源）。

规则：对话不改变对象语义——LLM 只是录入辅助，**入库前必须经同一准入与权限链**；对话内容不落公共库（R-PUB）。

## 5. 设计规则

1. **写路径唯一**：提案入册/状态迁移只走 apply 管线（三步闸门全量继承：scheme 准入=枚举闭合集、
   权限准入、乐观锁落库）——无旁路写入端点。
2. **派单=受理投影**：status=approved 落库即一条 `apply-workflow` 锚派单受理投影（flowbind 派单面
   复用，载荷带 proposal 名/目标/验收标准/priority/proposer，eventId=DocApplied 回执同源可回指）；
   **受理≠拉起**（诚实投影与 wake 面同口径）；rejected 不派单。
3. **审批分流可配不可关严**：缺省（未配置）=全人审——自动批准是显式开启的部署决策（宁慢勿越）；
   分流配置经 stderr 装配锚在册可查。
4. **产物指针声明式**：`spec.landing.target` ∈ `doc|task`——批准后执行体的落点声明；产物真实落盘
   =apply-workflow agent 真实拉起段（declared-deferred），落盘后状态回写 `landed`（该回写动作亦走
   apply 管线，写主体=执行体）。本轮（v0.51）打通到派单受理+产物指针，不冒充产物已在。
5. **R-PUB 纪律随行**：提案正文属公开仓内容（docsRoot git 权威）——标题/目标/验收禁真实 IP/凭据/
   内网信息；secret 只引用式（provider.md 规则 2 前缀集合）。

## 6. 与其他概念的关系

- **Workflow**：Proposal 批准后派单 `apply-workflow` agent（builtin 专用 agent，workflow.md §1.2）——
  该 agent 的实现产物（ConnectorOps 实现/文档变更）可能新建 Workflow 对象，但 Proposal 本体与
  Workflow 无对象级引用（派单投影行只带锚名）。
- **TaskScheme**：四层执行的第三层；Proposal 不声明步骤（见 §2 边界）。
- **apply.md**：Proposal 全生命周期写动作（提交/批准/驳回/landed 回写）都是普通 apply——幂等/
  乐观锁/审计语义零特例。
- **event.md**：规则 14（引擎内部源第五段=Proposal 分流 ApprovalNeeded 自产）+ 审批信号族的
  非 Workflow involved 用法（不命中 run 域=既有行为面不变）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 提案风暴（人人可提） | ⚠️ 中 | 无门槛提交造成审批积压 | 优先级分流+dedup 窗口；landed/rejected 终态归档可对账；审批屏积压数可见 |
| born-approved 绕审 | ⚠️ 低 | 直写 status=approved 跳过人审 | 派单受理 autoLevel=ask（真实拉起仍要批）；写主体/fieldManager 审计全留痕；机械迁移序收紧=余量 |
| 产物指针冒充 | ⚠️ 低 | landing 声明被误读为产物已在 | 详情屏产物区=指针+缺席如实标注（诚实投影红线） |
| 自动批准越权 | ⚠️ 中 | 低危判定失准 | 分流清单=部署显式配置（缺省全人审）；引擎自写 fieldManager=proposal:auto 可审计可回滚 |

**结论：可行。需求先成为对象再成为工作——审批与派单全程可审计，执行面零即兴。**

## 8. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
