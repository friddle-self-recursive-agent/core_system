---
name: storage-system-desc
docType: Desc
scope: builtin-storage-system
---
# Desc — builtin-storage-system

**是**：builtin 存储系统——本机目录存储（storage root：docs/ 文档库 git + files/ 产物 + snapshots/ DB 快照 + templates/ 镜像）的宿主。**不是**：不是通用云存储网关；不含 NAS/OSS（2026-11-27 裁定：builtin=零外部依赖，本机目录即全部；远端备份/归档=部署方接 nas/oss connector 后部署配置的 Task/Workflow，系统本体不感知不承诺）；不管 ops 日志 DB（那是 self-recursive-core 的组件，DB 属核心进程，存储系统只管文件层）。设计细节（目录布局、快照节奏、可行性）在 instance 仓 impl/storage-system.md。
