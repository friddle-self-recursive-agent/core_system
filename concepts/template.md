# Template — 模具（四层 appliesTo；要求语义，不是实际系统）

| 项 | 值 |
|---|---|
| K8s 对照 | Helm Chart（声明需要什么、怎么装、装完如何纳管） |
| 形态 | 对象（`global/templates/<name>.yaml`），builtin Scheme；一个 kind × 四层 `appliesTo` |
| 作用域 | Global（模板本体）/ 安装实例落为 WorkService / 实例化落为 ServiceInstance / Workspace |
| 状态 | 定稿（终态制，rule.md；**2026-11-26 用户裁决：模板=要求集（Ref 语义）——storage/端点/算力都是"要求"不是实际系统；系统自动判断配置好，没有就一层层询问；四层模具+实例化逐层下探**） |

## 1. 定义

Template 是**模具**：描述"这一层需要什么（要求）、骨架长什么样（mold）、装/建的时候问什么（asks）"。
**核心语义（用户裁决）：模板里的资源全是「要求」，不是实际系统**——

- `storage` 不是 `nfs://nas/services/onedev` 这样的实际地址，而是**要求**：偏好类型（oss/nas/storage 系统自备/任意）、**大概空间**（`~50Gi`）、**速度要求**（hot/warm/cold）；
- `compute`/`ports`/`endpoints` 同理——要求与偏好，不是事实；
- **系统判断给配置好**（resolver）：对照在册的 storage-system / Provider / WorkService 能力自动选型并落配置；**解析不了就一层层询问**（asks，带缺省与示例）。

### 1.1 四层模具（appliesTo）

| 层 | 用户叫法 | 模具回答的问题 |
|---|---|---|
| `workservice` | WorkServiceTemplate | 安装一个**外部系统**要什么（镜像/存储/端口要求）、怎么装、装完如何纳管 |
| `servicedesc` | ServiceTemplate / ServiceDescTemplate | 这个**系统**由哪些系统构成（`systems` 要求清单）、有哪些要求、**哪些 goal** |
| `serviceinstance` | ServiceInstanceTemplate | 这个系统的**一个实例**怎么落地（agentRefs/docs/实例级要求） |
| `workspace` | ServiceWorkSpaceTemplate | 这个系统的**工作空间**怎么组织（project/会话归组/入口） |

四层同一个 kind、同一套要求语义、同一套 resolver→asks 机制；`chain` 字段声明实例化时的下探层序。

### 1.2 实例化询问链（一层层问下去）

```
创建实例
→ ① 确认 Service（「是这个 service 吗？」——对象选择器按 kind/scope 搜索，R-UX-2）
→ ② 读该 ServiceDesc 的 ServiceInstance 模板 → resolver 先试（要求→在册资源自动配置）
     → 解析不了的才出 asks（带缺省/示例；R-UX-1：能推断不问）
→ ③ 扫描相应 ServiceWorkSpace 模板 → 同样 resolver→asks
→ ④ requires 引用的 WorkService 若未装 → 下探 WorkServiceTemplate 安装链（它的 asks 同样 resolver→ask）
→ 每层一张确认卡（自动选型标注「已自动选 X：原因」，用户可改）；全部答完才执行
```

## 2. 边界

**是**：四层模具的声明（要求集 + 骨架 + 询问项 + 下探层序）；workservice 层另带确定性安装步骤。

**不是**：
- 不是实际系统/实际地址（**要求≠事实**：模板出现的一切资源都是待解析的要求，Ref 语义——要什么，不写在哪）；
- 不是 TaskScheme（Template 装的是"系统"；TaskScheme 跑的是"任务"；安装步骤内部可引用 TaskScheme）；
- 不是 WorkService/ServiceDesc/ServiceInstance（模具 vs 成品）；
- 不含业务配置（装完之后怎么用是 ServiceDesc/Connector 的事）。

## 3. 对象结构

```yaml
# ① workservice 层（原 WorkServiceTemplate；装外部系统）
apiVersion: core/v1
kind: Template
metadata:
 name: onedev
 scope: global
 labels: {core/template: workservice}
spec:
 appliesTo: workservice
 provides: {capabilities: [scm, ci], category: developer}
 requires:                                # 要求集（Ref 语义；全可被 resolver 解析/降级）
  images:
  - {name: onedev-server, source: "oss://templates/onedev/onedev-server.tar.zst", digest: "sha256:..."}
  storage: {kind: any, size: "~50Gi", speed: warm}   # 类型偏好+大概空间+速度要求——不是实际地址
  ports: [6610]
  compute: {cpu: "~2", mem: "~4Gi"}
  endpoints: {host: {ask: true}}          # 端点=要求（绑定哪里由 resolver/用户定）
 mold: {workservice: "onedev-six-facet"}  # 产出 WorkService 六面体骨架；Ops 由使用方挂载
 install:                                 # 确定性步骤（deploy-system 执行）
 - {action: pull-image, from: images[0], verify: digest}
 - {action: render-config, template: config.tmpl, with: asks}
 - {action: start-service, check: {httpGet: "/api/server-info", timeout: 120s}}
 postInstall:
 - {action: register-workservice, as: workservice/onedev}
 asks:                                    # resolver 解析不了的才问（必带缺省/示例）
 - {field: endpoint.host, question: "服务绑定主机名？", default: "onedev.internal"}
 - {field: auth.provider, kind: provider-ref, question: "管理员账号用哪个 Provider？"}

# ② servicedesc 层（ServiceTemplate/ServiceDescTemplate；有哪些系统/要求/goal）
apiVersion: core/v1
kind: Template
metadata: {name: developer-system, scope: global}
spec:
 appliesTo: servicedesc
 goals: ["scm/ci 服务自托管", "与核心控制台纳管打通"]
 systems: [ref/onedev, ref/prometheus]    # 有哪些系统（WorkService 要求清单，未装则下探①）
 requires: {storage: {kind: system, size: "~20Gi"}}    # 系统级要求（同样要求语义）
 mold: {servicedesc: "goalRef+descRef+docs 结构"}
 asks:
 - {field: repo.visibility, kind: enum, options: [private, internal], default: internal}

# ③ serviceinstance 层 / ④ workspace 层同理（agentRefs/docs 骨架 / project 组织骨架），asks 走同一机制
```

## 4. 生命周期与 resolver

```
模板发现（GitHub org 搜 *-template 仓 → TemplateFound）→ 入库（global/templates/，扫描+digest）
→ 使用：
   workservice 层：呈现 requires（含 resolver 的自动选型预填）→ asks 逐层补 → 人确认 → install → postInstall 纳管
   servicedesc/instance/workspace 层：实例化询问链（§1.2）逐层 resolver→asks→确认卡
→ resolver 规则：
   1) 存储要求解析顺序：storage-system 自备 → 在册 Provider/WorkService 能力匹配（oss/nas/…）→ asks；
   2) size/speed 是偏好——可降级（oss→nas、hot→warm），但**自动选型必须留痕**（「已自动选 X：原因」
      写进确认卡与审计），用户可改；
   3) 任何 asks 未答完不执行（缺省不算"答完"争议项）。
```

## 5. 与其他概念的关系

- **Ref**：requires 是 Ref 哲学的模板化——声明"要什么"（类型/空间/速度偏好），地址由 resolver/owning system 给。
- **Provider / WorkService / storage-system**：resolver 的解析对象（在册能力清单）。
- **ServiceDesc / ServiceInstance / Workspace**：servicedesc/instance/workspace 层模具的成品。
- **deploy-system**：workservice 层 install 段的执行者。
- **Intake（R-UX-1）**：asks 与确认卡走对话式录入引擎（`/v1/intake/*`），控件由 scheme 驱动（R-UX-2）。
- **DocType**：`appliesTo` 模式同源（一个 kind 注册多应用面）。

## 6. 设计规则

1. **要求语义**：requires 里禁止出现实际地址/实际系统名（`nfs://…`/具体主机）——只允许类型偏好+量化要求
   （size/speed/count）+ `ask` 标记；违反=lint 拒绝。镜像 `source` 例外（取货地址要求，resolver 可换源，digest 不变）。
2. **resolver 先于询问**：能从在册资源解析的要求不得抛给用户；自动选型必须留痕（原因+可改）；解析不了才 asks，
   asks 必带缺省与示例（R-UX-1）。
3. **逐层下探（chain）**：实例化按 chain 层序执行，每层一张确认卡；跨层要求（systems 引用未装的 WorkService）
   自动下探该层模板，不重复问已解析项。
4. 模板必须声明 digest（镜像）；asks 非空必须人工确认；无 asks 也要一次显式确认（防误装）。
5. install 步骤全部幂等 + 三段 undo（镜像/配置/服务）。
6. 模板本身来自 GitHub 仓时，克隆件经权限系统扫描（明文密钥模式全库扫描）。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| org 内无模板冷启动 | ⚠️ 低 | 起步没人写模板 | 首批官方模板：onedev、prometheus（既是示例又直接服务 developer-system） |
| resolver 选型失准 | ⚠️ 中 | 偏好解析到不合适资源 | 选型留痕可改 + 降级链显式（oss→nas→system）+ asks 兜底 |
| 逐层询问过繁 | ⚠️ 低 | 层多问多烦 | resolver 先行（能配不问）+ 每问必带缺省 + 已解析项跨层不重问 |
| 恶意模板 | ⚠️ 中 | install 段有任意动作 | digest+人审+权限系统高危动作拦截；模板来源限定本 org |
| kind 更名迁移 | ⚠️ 低 | 原 WorkServiceTemplate 对象 | 存量按 appliesTo: workservice 平移（目录即对象，一次性迁移提交） |

**结论：可行。四层模具一套机制，要求语义与 Ref/Resolver 同构——模板回答"要什么"，系统回答"用哪个"。**

## 8. 待决问题

见 open-questions.md#template

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
