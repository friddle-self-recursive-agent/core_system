---
name: storage-system-goal
docType: Goal
scope: builtin-storage-system
ownerRefs: [{kind: ServiceDesc, name: builtin-storage-system}]
---
# Goal — builtin-storage-system

## intent

三层存储：本地文件夹 git（文档权威副本）、NAS（备份+大文件）、OSS（镜像/产物归档）。文档永不丢、可审计（配合 ops DB）；WorkServiceTemplate 声明的"镜像文件地址"默认指 OSS。

## acceptance

- A1. 文档库每笔提交在 10 分钟内同步到 NAS remote（备份延迟可观测）。
- A2. 任一文档可从 NAS 恢复到任意提交点，演练每季度一次（DriftReport 留痕）。
- A3. 产物/镜像入 OSS 带 digest，WorkServiceTemplate 引用的镜像地址可下载校验。
- A4. 存储三层健康各有 condition（Primary/Backup/Archive），任一降级 → Event(warning)。
