# Connector — ConnectorOps / ConnectorProvider（v0.6 简化）

| 项 | 值 |
|---|---|
| K8s 对照 | Provider≈容器镜像引用（名字解析+下载地）；Ops≈已装好的命令行入口 |
| 形态 | `ConnectorProvider`（绑定声明，Global）+ `ConnectorOps`（工具调用面，Global/System/Instance） |
| 状态 | 设计稿 v0.6（R5 修正：生命周期大幅简化、命名解析、llmPrompt/download，A38） |

## 1. 定义

- **ConnectorProvider**：**就是用来绑定**的声明——把一个"类型名"绑到具体实现上。实现三形态：
  - `tool`：外部直接工具（现成命令/服务，拿来即用）；
  - `image`：镜像（下载即跑）；
  - `source`：源代码（**自己代码仓库管理的用 Ref 指代码地址，统一管理起来**）。

  **命名解析**（A38）：
  - **不带前缀** = 默认 org：`friddle-self-recursive-agent/`——我们自己有一套默认 Provider，代码与安装在该 org 下生成（workservice 仓 connectors/ 或 org 下独立仓+install 流程）；
  - **带前缀** = 按 GitHub 找完整配置：`acme/foo-driver` → `github.com/acme/foo-driver`（取 provider yaml、代码与安装说明）。

- **ConnectorOps**：**直接就是工具调用方式/提供的功能**——引用一个 Provider，配好环境（endpoint/凭证），暴露 op 集。Agent 调 ops = 调工具。**没有复杂生命周期**（v0.3 的探活/漂移/finalizer 机器删除：那些若需要，由所在系统的 Loop 顺带做，不是 Ops 概念的职责）。

## 2. 边界

**Provider 是**：类型名→实现的绑定 + 使用说明书（scheme/usage/llmPrompt/download）。
**Ops 是**：工具调用面（provider + 环境 + op 子集）。
**都不是**：外部系统本体（WorkService）、Plugin（扩展 dsh 自身）、业务判断者。
**Skill**（新概念，concepts/skill.md）：ops 的使用处缓存成的可复用经验，属 Agent 会话层，不属 Connector。

## 3. 对象结构

```yaml
# 类型层：global/connectors/<name>/provider.yaml
apiVersion: core/v1
kind: ConnectorProvider
metadata:
  name: onedev-driver            # 无前缀 ⇒ 默认 org（friddle-self-recursive-agent）
  # name: acme/foo-driver        # 带前缀 ⇒ github.com/acme/foo-driver 完整配置
  scope: global
spec:
  types: [scm, ci]               # 类型标注
  impl:
    kind: source                 # tool | image | source（三形态）
    ref: ref/core-system-workservice-repo   # source 形态：Ref 指代码地址（自己仓统一管理）
  download: "git://…/connectors/onedev"     # 工具下载地方（image:// git:// pkg:// 皆可）
  scheme:                        # 使用方式 schema（参数/返回，机器读）
    ops: [checkout, build-status, gate-status, verify, watch]
    params: {endpointRef: ref, credentialRef: credential}
  usage: |                       # 使用方式（人读）
    onedev REST + git 双通道；watch 用 webhook，抖动降级轮询…
  llmPrompt: |                   # LLM 注入提示：Agent 会话使用本工具时注入
    你可用 onedev-driver 管理 onedev：checkout(ref) 拉取代码；
    build-status(commit,result) 回写构建结果。token 从 credential 解析，禁止写死。
---
# 使用层：工具调用面
apiVersion: core/v1
kind: ConnectorOps
metadata:
  name: onedev-ci
  scope: builtin-developer-system/local-ci
spec:
  provider: onedev-driver        # 绑定（经命名解析）
  config: {endpointRef: ref/onedev-endpoint}
  credentials: [credential/onedev-robot]
  ops: [checkout, build-status, gate-status, verify]   # 提供的功能
```

## 4. 生命周期（极简）

- **Provider**：声明（Apply）→ 被引用 → 不用了就删。（v0.3 的"版本并存/兼容期/废弃探针"删除——需要锁版本就在 Ops 引用时写 `provider@v1.2`。）
- **Ops**：绑定（引用 Provider+配环境）→ 使用 → 删除。（探活/漂移/finalizer 不是本概念职责。）

## 5. 与其他概念的关系

- Agent 默认挂 Ops（工具面）；**使用要权限**（P7 并集+Policy 不变）。
- Provider 的 llmPrompt + Skill 缓存共同构成 Agent 的工具使用上下文（会话按需注入）。
- Ops 仍可绑 Workflow（缺省 default-task）——相位约束，不是生命周期机器。
- 默认 org 的 Provider 集 = 我们自带的基础工具箱（onedev/gitfs/nas/oss/dsh…），代码与安装在 org 仓生成。

## 6. 设计规则

1. 无前缀名必须能在默认 org 解析到；解析不到报错（不静默回退）。
2. 带前缀名按 GitHub 拉取完整配置后走 Policy 扫描（同 install 流程的安全规则）。
3. impl 三形态必择一；source 形态必带 Ref（统一管理）。
4. llmPrompt 必填（哪怕一句话）——它是 Agent 会话注入的工具说明书；download 必填。
5. Ops 就是调用面：不为它设探活/漂移/finalizer 概念级机制。

## 7. 可行性分析

| 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|
| 外部 org 配置质量不可控 | ⚠️ 中 | 带前缀拉来的 provider 可能有坑 | Policy 扫描+digest+高危人审（复用 install 规则） |
| llmPrompt 写得差→Agent 用错工具 | ⚠️ 低 | 说明书质量问题 | Skill 缓存反哺（实战调用模式沉淀回 usage/llmPrompt） |
| 三形态 impl 的安装差异 | ⚠️ 低 | tool/image/source 安装方式不同 | download 字段统一指路；安装执行归 deploy-system |

**结论：可行。简化后比 v0.3 更轻——绑定+说明书+调用面，其余全删。**

## 8. 原始设计标注

- A38（R5）：生命周期简化（就是绑定）；impl 三形态（tool/image/source+Ref 统一管理）；命名解析（无前缀=默认 org，带前缀=GitHub 完整配置）；yaml 增加 scheme/usage/llmPrompt/download；Ops=工具调用面，使用处可缓存为 Skill。

## 9. 待决问题

见 open-questions.md#connector

## 10. 审阅标注区

| 标记 | 位置 | 说明 |
|---|---|---|
| | | |
