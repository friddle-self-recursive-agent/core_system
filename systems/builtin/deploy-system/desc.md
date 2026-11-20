---
name: deploy-system-desc
docType: Desc
scope: builtin-deploy-system
---
# Desc — builtin-deploy-system

**是**：当前机器上的安装/落地执行器：WorkServiceTemplate 安装、builtin 服务自身安装、外部资源副作用清理（finalizer 执行者）。**不是**：不是通用远程部署系统（只有本机，dsh 单节点）；不做容量决策（装不装由人/Policy 决，它只负责装好装干净）。镜像/资源从 storage-system（OSS）取。实现细节在 instance 仓 impl/deploy-system.md。
