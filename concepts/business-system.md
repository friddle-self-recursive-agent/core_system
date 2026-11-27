# BusinessSystem — 企业业务系统（common-bussiness-system，独立 system）

| 项 | 值 |
|---|---|
| K8s 对照 | 独立部署的应用控制面实例：与 kube-system 的关系是"同机制、不同系统"（不是其子目录/子层） |
| 形态 | **独立 system**：自有仓 `friddle-self-recursive-agent/common_bussiness_system`、独立运行（不与 core 的 Go 二进制打包）、由 deploy-system 按标准导入格式管理 |
| 作用域 | 商业系统抽象层 + 业务管理层（导入并管理其他业务系统） |
| 权威文档 | **本仓（core_design）只留概念页；设计权威=common_bussiness_system 仓**（requirements/knowledge/rules/workflows/specs 全套在该仓演进） |
| 状态 | 定稿（终态制，rule/rule.md；**2026-11-27 用户裁决：business-system 不是 core_system 里的一个"层"，是已经独立的 system，不在 core_system 里面**；旧"约束层/实例继承"框架作废） |

## 1. 定义

common-bussiness-system 是一个**独立的业务 system**——与 sre_system、codie-bi 同一地位：不在 core_system 项目里、不随 core 的 Go 二进制打包、单独运行、由 deploy-system 管理、以标准导入格式接入。

它承担**双角色**：

1. **商业系统的抽象层**：承载基础商业需求、商业知识、业务设计规则与规范、默认 workflow 描述——"放很多业务系统设计规则、知识、规范"的家（R-BIZ 族规则的知识源）。
2. **业务管理层**：**导入其他系统、管理其他系统**——按标准导入格式把业务系统（如 codie-bi、未来的 sre_system）接入业务控制台统一管理；core_system 也可以被导入，但角色不同（机制底座 vs 业务管理，本质是**业务视角的管理**，不是机制托管）。

与两个控制台的关系：

```
core-system（机制底座，独立 system）      系统控制台=它的操作视角（机制/对象/流程运行）
common-bussiness-system（独立 system）    业务控制台=它的操作视角（对话/Welcome[业务事件·审批·描述]/Workflow，业务视角）
  ├─ 导入并管理：codie-bi、sre_system、…（标准导入格式）
  ├─ 可导入：core_system（角色不同——业务管理视角，非机制托管）
  └─ 权限缺省：高（导入/管理动作默认人审档，见该仓 specs/permissions.md）
```

**业务控制台的对话、审批、workflow 都基于这个系统**——业务视角的会话、核心业务事件、审批与业务层 workflow 以 common-bussiness-system 为承载（机制上复用 core-system 的 Apply/Workflow/Permission/Event，P10 复用不改造）。

## 2. 边界

**是**：独立 system；商业抽象层（需求/知识/规则/默认 workflow 描述）；业务管理层（标准导入+管理其他系统）。

**不是**：
- 不是 core_system 的内嵌层/子项目/约束包（旧"约束层被实例继承"框架已废）；
- 不是新控制面机制（Apply/Workflow/Permission/Event 全复用）；
- 不承载业务实例的高频流水账本（R-BIZ-2 不变：账本归业务系统自有代码）。

## 3. 标准导入格式（权威见该仓 specs/system-import.md）

被管理的业务系统以标准格式导入：**manifest（声明 docs/工作流描述/自定义页面/用户系统绑定/权限要求）+ 文档与描述本体**。导入=把这些文档和描述接入业务控制台（设计文档面 + 默认 workflow 描述），不是把代码塞进 core：

- **docs**：基础商业需求、知识、规则、默认 workflow 描述（导入即接入设计文档面）；
- **pages**：部分系统可像插件一样自带页面、自己控制（如未来 sre_system 可被发现并有自定义界面导入，specs/plugin-pages.md）；
- **user-system binding**：系统可自己绑定用户系统（规范见该仓 specs/user-system-binding.md）；
- **deploy**：非 core 打包的独立运行面由 deploy-system 管理（该仓 impl/README 声明运行形态）；
- **permissions**：缺省高权限档（导入/绑定/页面挂载默认人审）。

## 4. 五域模型（业务知识摘要，全文在该仓 docs/rules.md）

企业运行状态的切法不变：**对象→流→控制→观测→循环**；StateModel/Finance 两个 DocType + R-BIZ-1..7 规则族是这套知识的第一批落点（闭合集状态、账实分离、钱动必审、流必声明、无指标不上线、事务可回退、循环对账）。机制承载全部复用 core-system（P10），细节与演进**只在 common_bussiness_system 仓维护**。

## 5. 生命周期

```
独立仓定稿（需求/知识/规则/默认 workflow 描述 + 导入规范族）
→ 自身以标准格式接入业务控制台（dogfood：第一个被导入的系统的就是它自己，service.yaml 即样板）
→ 导入其他系统（codie-bi 等；sre_system 未来带自定义页面接入）
→ 业务控制台承载业务视角运行（对话/Welcome/Workflow；审批走 core-system 机制、高权限缺省）
```

## 6. 与其他概念的关系

- **core-system**：机制底座（复用不改造）；也可被本系统导入管理（角色不同）；
- **两个控制台**：系统控制台=core_system 视角；业务控制台=common-bussiness-system 视角（默认入口=业务工作台）；
- **R-BIZ 规则族**：权威文本迁至该仓 docs/rules.md（core_design 旧 systems/common-business-system/ 声明面随迁移退役，迁移前以该仓为准）；
- **deploy-system**：独立运行面的部署与管理方；
- **sybran-business-system**：同样是独立业务系统，与本系统是"被导入/管理"关系（不再称"实例继承"）。

## 7. 设计规则

1. **独立 system**：自有仓、独立运行、deploy-system 管理；任何"放回 core_system 项目里"的设计即违宪。
2. **导入即文档接入**：标准导入格式的本质是把被导入系统的 docs/工作流描述/页面声明/绑定声明接入业务控制台；零代码打包进 core。
3. **高权限缺省**：导入、绑定、页面挂载、workflow 变更默认人审档；配置可分级，不可缺省放宽。
4. **业务视角管理**：对 core_system 的导入是业务管理视角（机制底座照常自转），不是机制接管。
5. **页面自控**：插件式自定义页面由被导入系统自己控制（发现+导入+挂载有规范），业务控制台不代写页面逻辑。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。

## 8. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 与旧"约束层"框架的记忆/引用漂移 | ⚠️ 中 | core_design 旧 systems/common-business-system/ 声明面与 R-BIZ 引用尚在 | 概念页已声明权威迁移；声明面目录随导入规范落地后退役（git 历史留档） |
| 双控制台心智混淆 | ⚠️ 低 | 系统视角 vs 业务视角边界 | 默认入口=业务工作台；两台各自语义在侧栏/文档同词形呈现 |
| 导入格式过度设计 | ⚠️ 中 | manifest 面铺太大拖慢接入 | v1 只收 docs/workflows/pages/binding/permissions 五段；codie-bi 真实导入当验收样例 |
| 插件式页面安全 | ⚠️ 高 | 自带页面=第三方 UI 注入面 | 页面发现+挂载默认人审；页面自控但权限域独立（specs/plugin-pages.md） |
| 高权限缺省摩擦 | ⚠️ 低 | 每步人审降低流畅度 | 分级配置保留（strict-default，可按系统/动作放宽），缺省不放宽 |

**结论：可行。本质是"把既有机制的另一个使用视角"独立成一个 system：机制零新增，新增面=导入规范族+一个独立仓；真实风险在导入格式与页面安全，以 v1 五段 manifest+人审缺省压住。**

## 9. 待决问题

见 [open-questions.md](../open-questions.md#business-system)；新增：systems/common-business-system/ 声明面迁移时点、codie-bi 导入首窗范围。

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
