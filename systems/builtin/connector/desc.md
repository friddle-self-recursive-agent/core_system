---
name: builtin-connector-desc
docType: Desc
scope: builtin-connector
---
# Desc — builtin-connector

**是**：全局默认 ConnectorOps 的宿主服务（代码在 workservice 仓 connectors/）。**不是**：不是驱动类型注册处（那是 ConnectorProvider，Scheme 管）；不承载任何业务系统。它存在的唯一理由：让"connector 默认有 builtin 供给，每个 service instance 自己实现自己的"这条规则有明确落点（A25/R2）。
