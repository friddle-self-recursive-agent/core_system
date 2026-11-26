# Proposal — 需求提案（多主体提需求 → 审批双路 → 派工的一等对象）

| 项 | 值 |
|---|---|
| K8s 对照 | Issue/Enhancement 提案（任意主体发起的意图对象，走评审流）——"需求先成为对象再成为工作"的答案 |
| 形态 | 对象（`global/proposals/<name>.yaml | systems/<s>/proposals/<name>.yaml`），builtin Scheme 之一 |
| 作用域 | Global 或 System |
| 状态 | 定稿（终态制，rule.md；2026-11-26 用户裁决：提案人=一切主体、审批双路缺省、agent 全自动链、提案×上下文对照、派工含文档更新） |

## 1. 定义

Proposal 把"任何一个主体提的一个需求"变成**一等文档对象**：标题/目标/验收标准/影响面/优先级/提出人六要素入库，
走审批（**双路缺省**：界面人审 或 自动批准，按 priority 分流配置），批准后派单 `apply-workflow` agent 落地为文档草稿（docsRoot 对象）或
部署侧任务文件，产物落盘后状态回写 `landed`。**提交入口不限于 console**：console「需求提案」屏（对话式）、
agent 节点（workflow 内自动提交）、API/CLI——一切主体都可提需求、提更新；**写路径唯一入口=apply 管线**
（concepts/apply.md）——提案不是旁路通道，是过同一三步闸门的普通对象，入口多样、闸门唯一。

```
<any 主体> 提需求/提更新（console 对话 / agent 节点 / API / CLI → 草稿 → fromDraft Apply）
  → Proposal 对象在库（status=submitted；origin 记入口）
  → 提案×上下文对照（context 装配四族检索）：冲突/需补充 → 在对话与审批面明确展示
  → 审批双路（priority × 部署侧分流配置）：人审（ApprovalNeeded 自产→审批屏/通知）或 自动批准（auto-approve）
      ——autoLevel=all 的 agent 提案人可全自动走完含 approve 的整条链（同准入链，全留痕）
  → 批准（fromDraft Apply fieldManager=console:approve / proposal:auto → status=approved）
      → apply-workflow agent 派单受理投影（GET /v1/agents/dispatches——受理≠拉起；载荷含 docsUpdate 义务）
  → 产出：文档草稿（docsRoot 对象）或部署侧任务文件（产物指针=spec.landing）+ **受影响现有文档随行更新**
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
  proposer: console-operator        # 主体标识：人 / agent / 自动化节点（审计回链 apply_log.subject）
  origin: console                   # 提交入口：console|agent|api|cli（缺省由提交面回填，纯审计不参与判定）
  status: submitted                 # draft|submitted|approved|rejected|landed（闭合集）
  landing: {target: doc, docsUpdate: true}   # 产物指针：doc=docsRoot 对象草稿 | task=部署侧任务文件；docsUpdate=派工须同步更新受影响现有文档（缺省 true）
```

## 4. 状态机与审批链

- **状态闭合集**：`draft|submitted|approved|rejected|landed`。`draft`=本地草稿未入册（不入库，
  只在草稿缓存）；`submitted`=已提交待审；`approved`/`rejected`=判定终态（可审计）；`landed`=产物
  已落盘回写。迁移纪律=写面主体（checker 只校验枚举闭合集不校验迁移序——console 屏只出合法动作
  按钮，越序直写=普通 apply 行为，审计账可查）；机械迁移序收紧=checker 后续段余量。
- **审批双路缺省（2026-11-26 用户裁决）**：界面人审 与 自动批准 是**缺省并存的两条路**（"在界面上或者自动审批——默认都是这样的"）；分流配置只决定哪些优先级走自动。部署侧配置 `--proposal-auto-approve=<priority csv>`（如 `low`）。
  命中清单的 priority 提交即自动批准（引擎自写 `fieldManager=proposal:auto`，approval_log 落
  granted 行 judgedBy=引擎主体）；未命中（缺省=全部）走人审：引擎自产 `ApprovalNeeded`
  （involved=Proposal/<scope>/<name>，dedupKey=`proposal:<obj>`，source=core——event.md 规则 14），
  审批屏待审区与通知链（route `notification/*`）随行。
- **agent 全自动链（autoLevel=all）**：agent 节点作为提案人时，`autoLevel=all` 的 agent 可**完全自动走完整条流程含 approve**——提交→上下文对照→自动批准→派单受理→（真实拉起同受 autoLevel 管辖）→apply；全程同一准入链零旁路，approval_log/apply_log 以 `agent/<name>` 主体全留痕。`autoLevel=ask` 的 agent 提案仍自产 ApprovalNeeded 走人审。
- **批准/驳回动作复用审批链**：批准=草稿（status=approved）→ `fromDraft` Apply
  `fieldManager=console:approve`（approval_log granted 行 + `ApprovalGranted` 事件，source=human——
  判定是人做出的）；驳回=草稿（status=rejected）→ `fromDraft` Apply `fieldManager=console:reject`
  （approval_log rejected 行 + `ApprovalRejected` 事件）。判定落账与事件同拍（apply_log 承落库流水、
  approval_log 承判定、事件族承通知——三账同源可回指）。

## 4.5 录入方式：对话优先（2026-11-24 用户裁决；通用规则见 rule.md R-UX-1）

Proposal 的录入**默认是对话**（session 对话），不是表单（表单仅降级/精修）。固定顺序：

1. **自由描述 + 自动上下文**：用户可一段话描述；系统自动获得当前系统/对象/权限/历史对象等上下文并预填；
2. **自动补充**：能推断的直接填（提出人=当前主体、优先级缺省 low、产物落点缺省 doc、scope 按当前系统）；
3. **缺少询问**：只问 spec 中**不明确/缺失/冲突**的字段，每次带默认值与示例；用户跳过则用默认；
4. **提交节点 LLM 生成格式**：字段齐 → LLM 依 spec 生成 Proposal 对象 → R-PUB lint + spec 准入 dry-run → 不通过**指出具体字段**并回对话补；
5. **确认后自动补全**：用户看 diff 确认 → Apply（status=submitted；高危→ApprovalNeeded）；系统补 proposer/status/timestamps 等缺省；
6. **降级**：LLM 不可用或用户显式选择 → 回退表单；两条路产同一 Proposal 对象（无双源）。

规则：对话不改变对象语义——LLM 只是录入辅助，**入库前必须经同一准入与权限链**；对话原文不落公共库（R-PUB）。

### 4.6 提案×上下文对照（2026-11-26 用户裁决；机制见 concepts/context.md）

提案在提交节点与审批面**走同一套上下文装配**（tag 核心四族检索，同 0.9 复用规则，不重复装配）：

1. **装配时机**：提交节点（4.5 步骤 4 之后）对提案摘要跑 `context.pack`（query=标题+目标+影响面，tags 取提案 tags）；
2. **产出对照**：`contextCheck = {conflicts: [{ref+hash, why}], supplements: [{ref+hash, why}, …]}`——conflicts=与现有文档**冲突**的结论（含 ref+hash 可展开），supplements=需要**补充/更新**的现有文档清单；
3. **对话明确展示**：对照结果在 Proposal Chat 以卡片明确列出（冲突点逐条带引用），不静默、不折叠进"其他"；
4. **审批面同屏**：审批屏（人审）与自动批准的判定依据都携带该对照——auto 判定记录引用的对照摘要；
5. **定位**：对照是**辅助判定信息**，不改变准入判定本身（准入仍=scheme+权限+lint）；判定人对冲突点的取舍留在 approval_log。

**派工含文档更新（同裁决）**：批准派单的载荷带 **`docsUpdate` 义务（缺省 true）**——执行体完成实现后**必须随行更新受影响的现有文档**（终态制：文档=唯一权威，改动不回写文档=验收不过）；supplements 清单随载荷下发作为"该更新哪些"的起点；landed 回写前文档更新必须完成（或显式 declared-deferred 并说明理由）。

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
6. **多主体入口（2026-11-26 用户裁决）**：提案人不限于 console——人经界面/对话、agent 节点、API/CLI 都可提需求提更新；
   console 只是入口之一（`origin` 记入口纯审计）；入口多样、**闸门唯一**（全部走同一 apply 管线与审批链）。
7. **agent 全自动有界**：autoLevel=all 的 agent 可自动走完整链含 approve，但只在**其权限域内**（role 并集）——
   越权对象照样被权限准入拒绝；全程 fieldManager/主体留痕可回滚；autoLevel≠all 一律人审。
8. **提案×上下文对照必跑且可见**：提交节点跑 context 装配产 conflicts/supplements（ref+hash 可展开），
   对话卡片明确展示；装配失败降级 `degraded:true` 可见（不阻断提交、不静默）。
9. **派工必须回写文档**：docsUpdate 缺省 true——执行体不更新受影响现有文档=不得 landed（deferred 须显式声明）；
   supplements 清单随派单载荷下发。

## 6. 与其他概念的关系

- **Workflow**：Proposal 批准后派单 `apply-workflow` agent（builtin 专用 agent，workflow.md §1.2）——
  该 agent 的实现产物（ConnectorOps 实现/文档变更）可能新建 Workflow 对象，但 Proposal 本体与
  Workflow 无对象级引用（派单投影行只带锚名）。
- **TaskScheme**：四层执行的第三层；Proposal 不声明步骤（见 §2 边界）。
- **apply.md**：Proposal 全生命周期写动作（提交/批准/驳回/landed 回写）都是普通 apply——幂等/
  乐观锁/审计语义零特例。
- **event.md**：规则 14（引擎内部源第五段=Proposal 分流 ApprovalNeeded 自产）+ 审批信号族的
  非 Workflow involved 用法（不命中 run 域=既有行为面不变）。
- **Context（concepts/context.md）**：提案是上下文装配的一等消费方——提交节点跑 `context.pack` 产
  conflicts/supplements 对照（4.6），对话与审批面明确展示；提案本体也带 `conventions.tags` 入同一 tag 池。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 提案风暴（人人可提） | ⚠️ 中 | 无门槛提交造成审批积压 | 优先级分流+dedup 窗口；landed/rejected 终态归档可对账；审批屏积压数可见 |
| born-approved 绕审 | ⚠️ 低 | 直写 status=approved 跳过人审 | 派单受理 autoLevel=ask（真实拉起仍要批）；写主体/fieldManager 审计全留痕；机械迁移序收紧=余量 |
| 产物指针冒充 | ⚠️ 低 | landing 声明被误读为产物已在 | 详情屏产物区=指针+缺席如实标注（诚实投影红线） |
| 自动批准越权 | ⚠️ 中 | 低危判定失准 | 分流清单=部署显式配置（缺省全人审）；引擎自写 fieldManager=proposal:auto 可审计可回滚 |
| agent 全自动自批失控 | ⚠️ 中 | autoLevel=all 的 agent 自提自批形成循环 | 权限域硬边界（越权照样拒）+ 全留痕可回滚 + 提案×上下文对照随行 + 审批屏对 agent 提案标注来源可筛选 |
| 上下文对照误报 | ⚠️ 低 | 冲突判定失准误导审批 | 对照=辅助信息不改变准入判定；引用可展开复核；命中统计反馈迭代 |
| 派工文档更新拖欠 | ⚠️ 中 | 实现完成但文档没回写 | docsUpdate 缺省 true + landed 回写前置检查 + supplements 清单随载荷 + declared-deferred 显式出口 |

**结论：可行。需求先成为对象再成为工作——多主体入口、审批双路、上下文对照、文档回写全程可审计，执行面零即兴。**

## 8. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
