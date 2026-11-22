# WorkServiceTemplate — 安装模板（builtin Scheme）

| 项 | 值 |
|---|---|
| K8s 对照 | Helm Chart（声明需要什么资源、如何落成 WorkService） |
| 形态 | 对象（global/templates/<name>.yaml），builtin Scheme |
| 作用域 | Global（模板本体）/ 安装实例落为 WorkService |
| 状态 | 定稿（终态制，rule.md） |

## 1. 定义

WorkServiceTemplate 描述"安装一个外部系统需要什么、怎么装、装完如何纳管"。install 流程：

```
install service
→ 连 GitHub org (https://github.com/friddle-self-recursive-agent) 搜 *-template 仓
→ 读 template 仓描述（README/template.yaml）
→ 定位 WorkServiceTemplate 对象（Scheme 级，本类型）
→ 呈现 spec.asks（需要用户确认/提供的项：endpoint、凭证引用、资源确认）
→ 用户确认（ApprovalNeeded → Bind 人）
→ builtin-deploy-system 执行 install 段（拉镜像→渲染配置→起服务→postInstall 纳管）
→ 装完自动登记 WorkService 对象 + 注入 finalizer
```

## 2. 边界

**是**：外部系统安装的声明（资源需求镜像文件地址等）+ 安装步骤 + 安装时询问项。

**不是**：
- 不是 TaskScheme（Template 装的是"外部系统"；TaskScheme 跑的是"任务"；安装步骤内部可引用 TaskScheme）；
- 不是 WorkService（Template 是模具，WorkService 是成品）；
- 不含业务配置（装完之后系统怎么用它是 ServiceDesc/Connector 的事）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: WorkServiceTemplate
metadata:
 name: onedev
 scope: global
 labels: {core/template: workservice}
spec:
 provides: {capabilities: [scm, ci], category: developer}
 resources: # R1.4"描述需要资源（镜像文件地址）"
 images:
 - {name: onedev-server, source: "oss://templates/onedev/onedev-server.tar.zst", digest: "sha256:..."}
 storage: {nas: "nfs://nas/services/onedev", oss: "oss://services/onedev"}
 ports: [6610]
 min: {cpu: "2", mem: 4Gi}
 workservice: {template: onedev-six-facet} # ：产出 WorkService 六面体骨架；Ops 由使用方挂载
 install: # 确定性步骤（deploy-system 执行）
 - {action: pull-image, from: images[0], verify: digest}
 - {action: render-config, template: config.tmpl, with: asks}
 - {action: start-service, check: {httpGet: "/api/server-info", timeout: 120s}}
 postInstall:
 - {action: register-workservice, as: workservice/onedev} # 六面体骨架
 # ：无 Finalizer——外部清理职责写入产出物的 tools/flows（成对清理 op，Lint）
 asks: # 安装时必须询问的项
 - {field: endpoint.host, question: "服务绑定主机名？"}
 - {field: auth.provider, kind: provider-ref, question: "管理员账号用哪个 Provider？"}
```

## 4. 与其他概念的关系

- builtin-deploy-system 是执行者（其 Goal.– 即本流程的验收）。
- 镜像地址默认指 storage-system 的 OSS 层；digest 校验防模板被篡改。
- 模板发现用 GitHub org 搜索（Ref 指向 org；搜索结果建 TemplateFound Event）。

## 5. 设计规则

1. 模板必须声明 digest（无 digest 拒绝安装——供应链底线）。
2. asks 非空必须走人工确认；无 asks 也要一次显式确认（防误装）。
3. install 步骤全部幂等 + 三段 undo（镜像/配置/服务）。
4. 模板本身来自 GitHub 仓时，克隆件经权限系统扫描（明文密钥模式全库扫描规则）。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule.md)）。

## 6. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| org 内无模板冷启动 | ⚠️ 低 | 起步没人写模板 | 首批官方模板：onedev、prometheus（既是示例又直接服务 developer-system） |
| 镜像体积与 OSS 依赖 | ⚠️ 低 | 无 OSS 时装不了 | resources.storage 可降级 nas/local（模板声明备选源） |
| 恶意模板 | ⚠️ 中 | install 段有任意动作 | digest+人审+权限系统 高危动作拦截；模板来源限定本 org |

**结论：可行。等价于面向"外部系统"的 Helm，安装执行复用 deploy-system+dsh。**

## 7. 待决问题

见 open-questions.md#template

## 8. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
