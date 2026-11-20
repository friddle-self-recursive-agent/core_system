---
name: developer-system-desc
docType: Desc
scope: builtin-developer-system
---
# Desc — builtin-developer-system

**是**：builtin 开发系统——源码在 onedev（既有系统，WorkService 纳管），构建默认在本机（dsh 执行器），产物交 storage-system。**不是**：不含远端构建池（那是后续普通 ServiceDesc 的事）；不管理 onedev 本身的安装（那是 deploy-system + WorkServiceTemplate 的事）。设计全文（如何利用 onedev/如何开发/如何满足循环/可行性）在 instance 仓 impl/developer-system.md。
