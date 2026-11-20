# 原始要求存档：agent_pool 与反馈闭环（2026-11-20 第三批）

> 编号 R14-x。本批确定 agent_pool 机器、双 dsh profile 分工、反馈修复闭环 workflow、内网集群接入与仓库前缀规则。是 v0.14 设计的直接依据（R13 已被终态制批次占用，本批顺延）。
> 存档原则：涉及公司实物信息（域名、地址、凭据、真实系统名）一律只存公司 git（见 R14.6）；本存档只保留可公开的概念性要求。

## R14.1 agent_pool 机器与双 profile

- 新增一台 agent_pool 机器（内网 dev 容器，ubuntu 24.04，dsh + node/go 基础环境已装）。
- 该机器上装 **两个 dsh profile**：
  1. **core-system profile**：专门跑 core_system 自己的完整最短内置 developer-system 开发流程进行自举开发；**唯一目标 = 更新第二个 profile 所用的 plugin**。
  2. **kube-inner profile**：准备接入公司 OneDev、现有 kube-inner 内网集群的所有系统（经跳板 SSH 通道 + npm 反代面），对**所有页面功能做模块划分**。
- 模块划分由 subagent 完成，参考公司门户客户端仓库（inner_service_client）的服务清单与描述、相应代码位置；数据库账号密码在该侧存在——**凭据永不入库**（A40：Provider.auth.secret 引用式）。

## R14.2 反馈闭环 workflow（首先明确）

feedback 监测的修复闭环：

```
有错误报错 → event 到 service 的 agent → root 的 agent → 生成提议
→ 批准（dsh plugin 页面实现）
→ onedev 系统 pull 下来（developer_system）
→ deploy_system 发布正式环境 → 验收
```

设计要求：严格按文档规则写**每个概念每个组件的完整功能图**，按标准化、组件化、解耦化来做设计。**先做设计，不开做。**

## R14.3 内网集群接入

- kube-inner 是公司内网 K8s 集群（zh 区），承载全部内部管理系统的 prod/preview/pubtest 环境；管理面经一台内网宿主机的 SSH 通道进入。
- 集群访问账号为受限部署 SA（deployments/pods/replicasets/events 可读写，nodes/namespaces 不可列）——权限模型与此对齐。
- 页面功能模块划分以门户客户端的服务注册表（90 项，六类）为第一手清单，与集群部署清单对账。

## R14.4 OneDev 项目与报告

- 在公司 OneDev 创建项目，**默认前缀 `agent_pool`**；把**真实的可验证报告**（验证过的事实 + 设计文档）放上去。
- 报告中的每个事实都要可验证（API 响应、清单文件、命令输出），不接受编造。

## R14.5 设计落点（按三仓规则）

- 概念/裁决 → core_system 仓（annotations 预标注，A54 起）。
- 实现形式 + 可行性 → core_system_instance 仓（impl/feedback-workflow、impl/kube-inner-integration、runtime/agent-pool-machine）。
- 代码 → core_system_workservice 仓（本次不做）。

## R14.6 信息隔离规则（硬规则）

- **GitHub（公开 org）不允许出现任何现有公司信息**：真实域名、内网地址、系统名、凭据一律不进 GitHub 仓。
- 真实的公司需求与公司代码都存公司 git（OneDev，agent_pool 前缀仓）。
