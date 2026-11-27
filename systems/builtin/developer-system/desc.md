---
name: developer-system-desc
docType: Desc
scope: builtin-developer-system
---
# Desc — builtin-developer-system

**是**：builtin 开发系统——**本地目录 + 本地 git 仓库（origin 可配置 push 远程）+ 本地部署**，构建在本机（dsh 执行器），产物交 storage-system；**零外部依赖，跟 业务实例（或任何部署目标）无关**（2026-11-26 用户裁决：builtin 就是 builtin）。远程 SCM（onedev 等）与部署实例=**workflow 节点的可插拔绑定变体**（通用抽象：workflow 节点可配置不同 service+connectorOps），不是本 builtin 的一部分。**不是**：不含远端构建池（那是后续普通 ServiceDesc 的事）；不管理外部 SCM 本身的安装（那是 deploy-system + Template 的事）；不含部署实例绑定值（部署实例绑定值=业务侧开发实例仓，private）。设计全文（本地链路/通用抽象/首圈走查/可行性）在 instance 仓 impl/developer-system.md。
