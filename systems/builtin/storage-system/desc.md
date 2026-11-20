---
name: storage-system-desc
docType: Desc
scope: builtin-storage-system
---
# Desc — builtin-storage-system

**是**：builtin 存储系统——本地 git 文档库的宿主、NAS/OSS 的纳管与备份策略、对象（镜像/产物）归档。**不是**：不是通用云存储网关；不管 ops 日志 DB（那是 self-recursive-core 的组件，DB 属核心进程，存储系统只管文件与对象层）。设计细节（NAS 挂载、OSS bucket 规划、备份节奏、可行性）在 instance 仓 impl/storage-system.md。
