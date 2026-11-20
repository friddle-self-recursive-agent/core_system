# 概念复审（R11）：按你的思路重新梳理 + 不合理概念清单

> 方法：把 A1–A47 的每条裁决当成"宪法判例"，用你贯穿始终的三个标准反向审计现存 25 个概念：
> ① **够不够"绑定/声明"**——概念应该只是说清关系（Provider=绑定、Ref=声明、Role=权限表）；
> ② **有没有被分食**——职责被别的概念拿走了还占着位置的，是空壳；
> ③ **是不是 K8s 移植残留**——"k8s 有所以我们也该有"的不算理由（R4 的 Builtin、R8 的 Policy 都是这个病）。
> 本文件只提案（A48–A52，待裁决），裁决后我再动手改三仓。

## 一、按你的思路重排的概念地图

你的思路收敛后其实是四个世界加一个底座：

```
【意图世界】（全是文档，改文档=改系统）
  ServiceDesc —— 系统声明（Goal/Rule/... DocType 文档集）
  TaskScheme —— 确定性步骤图（意图→Agent→Scheme→代码 的第三层）
  Workflow —— 循环本体（触发规则→事件整理→处理→文档回归；Loop=其实例）
  ConnectorProvider —— 类型绑定（名字→代码/工具/镜像；无前缀=默认 org）
  Ref —— 逻辑声明（要什么；真实地址由 owning system 返回）
  Role/Group/User —— 权限与身份（只绑 role；默认走 root）
  Provider —— 账号包（auth.secret 内化）
  WorkServiceTemplate —— 安装模板
  Skill —— 使用缓存（经验回填）

【执行世界】（dsh 承载，系统本身零概念）
  Agent —— dsh 会话（AUTOLEVEL；按需加载文档；子 agent=机器级进程）
  ConnectorOps —— 工具调用面
  Event —— dsh 队列里的信号（log 式 Level）

【解耦机制】
  Ref 解析（系统间不互相知道地址）
  跨系统提案（A 影响 B = Apply 提案，B 侧裁判）

【底座】
  Core（dsh plugin 实现）+ Scheme（注册表）+ Apply（唯一写路径）

【审计后建议除名/合并】：WorkService、Bind、Revision、Owner、Finalizer、Status（见下）
```

## 二、不合理概念（≥3，给 5 个 + 1 个附带观察）

### ① WorkService —— 空壳化（职责被分食干净了）

**现状**：外部系统在册对象（desc + capabilities + endpoint + auth + status）。

**不合理**：R5/R9 之后它的四要素全被拿走——类型标注→`ConnectorProvider.types`；驱动→`ConnectorOps`；地址→`Ref` 逻辑解析（owning system 管）；账号→`Provider`。剩下的只有"健康 status"，而 status 任何对象都有。它与 ServiceInstance 的边界从 A11 起就靠裁决树硬撑，本质是**同一问题问了两次**："外部系统怎么管"。按 P10（每个概念只有一个存在理由），它已经没有独立的存在理由。

**建议（A48）**：并入统一的 Instance 概念——外部系统就是 `origin: external` 的 ServiceInstance（挂在虚拟 Desc 下）；或更激进：降级为 Ref 解析结果的缓存对象。install 流程的 `register-workservice` 改为注册外部 Instance。`workservice.md` 墓碑。

### ② Bind —— 与 Role 重复（只剩一张二元关系表）

**现状**：A34 重写后，spec 只剩 `role + on`（哪个对象挂哪个 role）。

**不合理**：A34 之后不绑人、A45 之后权限语义归 Role——Bind 的全部内容是一张"对象↔role"关系表，**这正是 Role.spec 该有的字段**（`role.on: [对象]`）。这是你的合并史里漏掉的同类项（Loop→Workflow、Credential→Provider 都是这么并的）。且"Bind"这词的语义已经变过两次（绑人→绑 role→权限插入），名字与内容早脱节了。

**建议（A49）**：并入 Role：`Role.spec.on: [agent/x, systems/y]`；对象侧可选 roles 引用。`bind.md` 墓碑；Notification 的 role-holders 路由改查 Role 持有者（user-system 投影不变）。

### ③ Revision —— 全是 Apply 的实现细节

**现状**：resourceVersion 乐观锁 + 双轨审计 + LLM 语义 diff 触发点。

**不合理**：你 R3 的原话是"文档更新必须 Apply，**因为文档做版本管理**"——版本管理本来就是 Apply 定义的一部分，不是并列概念。Revision 的三块内容没有一块能脱离 Apply 独立存在（锁在提交流程里、审计在双写里、diff 在冲突处理里）。它是 A8 时期"K8s 有 resourceVersion 所以我们也建个概念"的移植残留，正是你后来批 Builtin（R4）、批 Policy（R8）的同一种病。

**建议（A50）**：并入 Apply（apply.md 增"版本与审计"一节，规则原文照搬）；`revision.md` 墓碑。纯文档合并，零机制变化。

### ④ Owner + Finalizer —— K8s 移植味最重的一对

**现状**：Owner=ownerRef（级联+责任上溯）；Finalizer=两阶段删除协议。

**不合理**：
- Owner 的"责任上溯"职责已被 A35 取代（默认走到 root agent）；剩下的级联删除，在"**目录即对象**"的存储模型下天然存在——删 `systems/x/` 目录就是删它的一切，ownerRef 只在跨目录引用时才必要，而跨目录引用本来就该走 Ref/提案。
- Finalizer 的"清外部副作用"本质是**一次删除 Workflow**（清理步骤→真删），不是一个协议概念。用 builtin `delete-flow`（core-loop 的兄弟）表达与整个体系更一致；副作用自动登记表保留，作为 delete-flow 的输入。

**建议（A51）**：Owner 并入 Scope（目录归属=级联语义）；Finalizer 降级为 builtin Workflow `delete-flow` 的机制细节。两个墓碑。

### ⑤ Status —— 过度形式化的"概念"

**现状**：独立概念文档定义 conditions/observedGeneration/drift 结构。

**不合理**：它没有对象、没有 Kind、没有生命周期——**只是字段约定**。按你"描述即声明、机制最少"的思路，它是 Scheme/doctypes 里的结构规范，不配与 Agent/Workflow 平起平坐。留着它会诱导后续往"Status 子系统"方向膨胀（v0.2 的我正是这么干的：reason 枚举注册制、防抖窗口……全是为概念而概念）。

**建议（A52）**：降级为 Scheme 的结构约定（内容并入 scheme/doctypes，文档保留为约定参考），概念表除名。

### 附带观察（不计入，供参考）：Event

Event 的**队列实现已经是 dsh 的**（A42），概念剩下的只有"类型注册 + Level + 路由约定"。按 Plugin 的判例（A43："dsh 承载的不算我们的概念"），Event 也可以降级为 Scheme 里的 eventType 注册约定。但 Event 的 Level/去重语义直接影响 Workflow 触发，保留为概念文档也有辩护空间。倾向：**暂留**，等 dsh 侧实现定型再裁。

## 三、清账后的概念表（若 A48–A52 全部采纳）

现存 25 → **19 个**：意图世界 9（ServiceDesc/TaskScheme/Workflow/ConnectorProvider/Ref/Role/Group/User/Provider/WorkServiceTemplate/Skill 中去掉被并的）+ 执行世界 3（Agent/ConnectorOps/Event）+ 底座 3（Core/Scheme/Apply）+ 保留约定 4（Scope/Doctype/Notification/Permission 说明合并进 Role 后权限系统文档保留为机制说明）。

墓碑家族将达 9 个：Loop、Plugin、Policy、Selector、**WorkService、Bind、Revision、Owner、Finalizer**（+Status 降级、Credential 已删）。这个墓碑比例本身就是设计演进的健康证据——每次都朝"更少、更绑定、更声明"收敛。

## 四、裁决区

| ID | 提案 | 采纳/驳回 | 备注 |
|---|---|---|---|
| A48 | WorkService 并入外部 Instance / Ref 解析缓存 | 待裁决 | 二选一：external-Instance（稳）或 Ref 缓存（激进） |
| A49 | Bind 并入 Role（role.on） | 待裁决 | |
| A50 | Revision 并入 Apply | 待裁决 | 零机制变化 |
| A51 | Owner 并入 Scope；Finalizer 降级为 delete-flow Workflow | 待裁决 | |
| A52 | Status 降级为 Scheme 结构约定 | 待裁决 | |
