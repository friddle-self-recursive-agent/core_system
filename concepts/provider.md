# Provider — 外部能力账号包

| 项 | 值 |
|---|---|
| K8s 对照 | 无直接对应（组合了 Secret+ConfigMap+Endpoint 的"账号"概念；类比 cloud provider credential profile） |
| 形态 | 对象：`global/providers/<name>.yaml` |
| 作用域 | Global（可被 System/Instance 引用） |
| 状态 | 定稿（终态制，rule.md） |

## 1. 定义

Provider 回答："用谁家的 API、拿什么钥匙、怎么配、走哪个连接"。Agent 理论上要绑定 Provider——提供相应的 API 账号密码或接口（LLM API、IM 通知、云厂商……）。四要素：

- **auth**（属于）：认证方式与归属（scheme + secret）；
- **config**：baseUrl、模型列表、限流等环境参数；
- **connector**：走哪个 ConnectorOps（**可为空**——本地工具/无接口依赖的能力）；
- **secret**：密钥的取值来源与轮换（** 起 Credential 概念删除，：secret 是 Provider 的字段**；明文永不入库——source 只允许 vault/env/keychain 引用式取值）。

## 2. 边界

**是**：账号能力包（auth+config+connector+secret 的聚合声明）。

**不是**：
- 不是 ConnectorProvider（那是驱动**类型**；本概念的 connector 字段引用的是 **ConnectorOps**——名字相近，两物， 备注）；
- 不存在独立凭证对象：钥匙就是 Provider 的 auth.secret 字段；
- 不是 WorkService（WorkService=被管理的外部系统；Provider=访问某能力的账号视角，同一系统可有多份 Provider：只读号/管理员号）；
- 四要素皆可为空（空 Provider=纯本地能力占位，合法）。

## 3. 对象结构

```yaml
apiVersion: core/v1
kind: Provider
metadata:
 name: llm-main
 scope: global
spec:
 kind: llm # llm | im | email | cloud | network | generic（network=网络出口：代理/DNS/域名转发）
 auth:
 scheme: bearer
 secret: {source: "vault:secret/llm-api-key", rotation: 90d} # ：secret 是 Provider 字段，明文不入库
 config:
 baseUrl: https://api.example.com/v1
 models: [main-model, flash-tier]
 rateLimit: {rpm: 60}
 connector: "" # 可为空（直连 HTTP，无 ConnectorOps）
---
apiVersion: core/v1
kind: Provider
metadata:
 name: im-feishu
 scope: global
spec:
 kind: im
 auth: {scheme: oauth2, secret: {source: "keychain:feishu-app"}}
 config: {app: cli_xxx, chatId: oc_xxx}
 connector: ops/http-api # 走通用 http ConnectorOps
---
apiVersion: core/v1
kind: Provider
metadata:
 name: email-notify
 scope: global
spec:
 kind: email # 通知默认通道（Event 默认通知 → 邮件，event.md 规则 7）
 auth: {scheme: plain, secret: {source: "env:QQ_SMTP_AUTH_CODE", rotation: 90d}} # 引用式取值（规则 2）；真实授权码只存部署侧 env（规则 6）
 # 同一取值面的 secret: 来源（默认走 Secret 的部署口径）：auth: {scheme: plain, secret: {source: "secret:email-auth-code", rotation: 90d}}
 # ——secret:<name> 引用部署侧秘密存储（SQLite 0600 独立文件，--secrets-db 装配；值只进不出，查询面零值出）
 config:
  host: "<smtp-host>" # 运行时实例值只存部署侧（规则 6）
  port: 465 # implicit TLS（SSL）
  from: "<发件账号>"
  to: ["<收件人清单>"] # 收件人清单可配置（Provider/WorkService 配置面）
 connector: notify/send-email # 走通知 ConnectorOps（ops=notify/send-email，connector.md；实现=common_connector notify OpsConnector）
---
apiVersion: core/v1
kind: Provider
metadata:
 name: net-egress
 scope: global
spec:
 kind: network # 网络出口：外网代理/DNS/域名转发
 auth: {scheme: none} # 带账号的代理=basic+secret（同样引用式取值）
 config:
 proxy: "http://<代理地址>:<端口>" # 运行时实例值只存部署侧，不入公开仓（规则 6）
 bypass: ["内网网段", "localhost"]
 connector: "" # 本地工具直接消费（git/ssh/工具链读部署侧配置）
```

```yaml
apiVersion: core/v1
kind: Provider
metadata:
 name: browser-headless
 scope: global
spec:
 kind: generic # 本地工具型能力（无外部账号）
 auth: {scheme: none}
 config:
  tool: chromium-headless # 实现=无头浏览器（验收截图/页面渲染）
  args: ["--headless=new", "--screenshot", "<out.png>", "--window-size=1440,900"]
  timeout: 60s
 connector: "" # 本地工具直连（需要经 ConnectorOps 时改填 skill/browser
 secret: {}
```

## 4. 生命周期

登记（人审——Provider 是钥匙集合的索引，高危）→ 被 Agent/Notification 引用 → 密钥轮换=更新 secret source（vault 侧轮换；Provider 对象不变，rotation 超期降权）→ 注销（确认无引用后删）。

## 5. 与其他概念的关系

- Agent.spec.providers 引用（Agent 的能力账号面；权限并集的一部分，P7）。
- Notification 的 channel 走 Provider（im/email/webhook 各配其 Provider）。
- 网络出口类（kind: network）被 git/ssh/工具链的外网访问消费：部署侧读其 config 组装代理/路由；声明面只是接口契约，真实地址在运行时实例（规则 6）。

## 6. 设计规则

1. Provider 变更走人审（它是"谁拿钥匙"的答案）。
2. secret 只允许引用式取值（secret:/env:/vault:/keychain:），出现明文=权限系统 拒绝+全库扫描告警（原 Credential 扫描规则并入）。`secret:<name>` 引用部署侧秘密存储（SQLite 独立文件 0600，--secrets-db 装配——凭据真实值的权威运行时面，scheme.yaml runtime.storage.secrets）：真实值只落该库，任何查询/导出面只出名称零值出（运行时态不导出）。
3. connector 为空时，Agent 直连须在 config 声明目标域（审计可查出口）。
4. 一个 Provider 一个用途；多环境=多 Provider（llm-main / llm-backup）。
5. 原 Credential 的轮换/吊销规则并入本概念：rotation 必填（无轮换告警，超期降权）；吊销=删 Provider（Finalizer 清 granted 使用方）。
6. **声明面与运行时面分离**：公开仓只存声明面（类别/接口/secret 引用/占位符）；Provider 运行时实例的真实地址、账号、密码只存部署侧（机器本地配置/ops DB/gitignored 台账，凭据值走部署侧秘密存储 `secret:<name>`——规则 2），**绝不提交公开仓**（rule.md R-PUB-1/2）。运行时实例≠声明对象：一台部署一份实例配置，多环境多实例，声明面唯一。
7. **通知类 Provider 的 secret 引用面即实现契约**：kind=email/im 类 Provider 的通道实现挂靠 ConnectorOps（connector 字段）→ 运行时经 connectors 包 **OpsConnector 五方法**（工具调用域：Type/Version/Ops/Invoke/Probe，R-ENG-3 契约层）出站——声明面只写引用式 secret 与占位符 config，授权码真实值永不入任何仓（R-PUB-1 凭据红线）。
8. **能力→Provider→Skill 缓存**：可复用的工具能力（验收截图/浏览器渲染/检索等）以 Provider 登记（本地工具 kind: generic，connector 可空）；首次成功调用后沉淀为 **Skill**（运行时 agent-session §4：注入提示+成功调用示例），workflow 验收节点由 agent 直接调用该 skill（不即兴写命令）；Provider 契约变更/版本升级 → 对应 Skill 默认作废（Skill 是缓存不是真相）。
- 终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule.md)）。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 密钥信息集中后成为高价值目标 | ⚠️ 中 | Provider 是钥匙集合的索引 | 明文扫描全库（原 credential 规则并入）；Provider 变更人审；source 只允许引用式取值 |
| Provider 泛滥 | ⚠️ 低 | 每个外部账号一个 | 命名规范 `<kind>-<用途>`；无引用 Provider 告警 |
| 运行时实例误入公开仓 | ⚠️ 中 | 真实代理地址/账号随声明面泄露 | 规则 6 声明/运行时分离 + R-PUB-1 lint（IP/真实路径扫描）+ secret 引用式取值 |

**结论：可行。纯簿记聚合，风险由边界规则压住。**

## 8. 待决问题

见 open-questions.md#provider

## 9. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
