---
name: storage-system-goal
docType: Goal
scope: builtin-storage-system
ownerRefs: [{kind: ServiceDesc, name: builtin-storage-system}]
---
# Goal — builtin-storage-system

## intent

本机目录存储（2026-11-27 裁定：builtin 无 NAS/OSS）：storage root 一个本机目录管全部——docs/（本地文件夹 git，文档权威副本）、files/（产物/大文件，digest）、snapshots/（ops DB 快照）、templates/（镜像取件）。可审计（配合 ops DB）；WorkServiceTemplate 声明的"镜像文件地址"默认指本地 templates/。

## acceptance

- A1. ops DB 每日快照落 snapshots/，滚动保留，快照延迟可观测。内置不承诺远端备份（远端=外接 connector 后部署自配的加分项）。
- A2. 任一文档可从 docs/ + snapshots/ 恢复到任意提交点，演练每季度一次（DriftReport 留痕）。
- A3. 产物/镜像写 files/ 带 digest，WorkServiceTemplate 引用的镜像地址可下载校验（install 默认走本地 templates/）。
- A4. storage root 一个 condition（Primary：盘满/权限/fsck 探针），降级 → Event(warning)。
