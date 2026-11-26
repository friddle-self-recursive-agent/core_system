# Engineering — 高性能与工程化建议基线

| 项 | 值 |
|---|---|
| K8s 对照 | —（工程基线建议，非对象机制） |
| 形态 | 建议基线文档：lint 族基线（含 R-ENG-7 红线）+ 读侧高性能四条 + 依赖选型基线 + RuntimeStore 可插拔持久化建议 |
| 作用域 | 全局（core_system 各代码仓通用；运行时侧落地映射=core_system_instance runtime/perf-lint-baseline.md） |
| 状态 | 定稿（终态制，rule/rule.md） |

## 1. Lint 基线

| lint | 口径 | checker |
|---|---|---|
| **R-ENG-7 单文件行数** | 一切代码与标记语言文件 ≤800 行（含注释与空行；`dist/` 构建输出与 lockfile 豁免）；超限必须拆分——Go 按职责拆文件/子包、TS/JS 按模块/屏拆、CSS 按组件域拆，重构零语义变化 | [lint/max-file-lines.sh](../lint/max-file-lines.sh)（type=lint：git ls-files 遍历 tracked 代码文件，awk 数行，>800 即红并输出文件名与行数） |
| gofmt / go vet 强制 | Go 仓 gofmt 无 diff、go vet 零告警 | 建议挂 go test 前置（回潮即红） |
| esbuild 零警告 | 前端构建零 warning，新增弃用 API 即红 | 建议挂 npm test 前置 |
| npm test 红线 | 测试全绿是合并前置；跳过用例（skip）即红 | npm test |
| R-PUB-1 | 公开仓不暴露 IP/内网域名/部署路径/凭据名/个人选型 | [lint/personal-info.sh](../lint/personal-info.sh) |
| R-DOC-6 | 每篇 tracked md 同目录 metadatainfo 侧车 | [lint/metadatainfo.sh](../lint/metadatainfo.sh) |

**回潮即红**：lint 不是一次性清扫——每类约束的锚词形（超限文件名、skip 用例名、gofmt diff 等）常态接入 `npm test` / `go test` 前置：任何一轮把违例带回，测试即红，零人记成本。

## 2. 高性能建议（读侧）

1. **读面聚合**：console 首屏走一类**聚合快照端点**——一次拉回 kinds + 对象索引 + inbox/runs/tasks/sessions 摘要，替代逐对象 N+1 轮询。
2. **增量推送**：WebSocket/SSE 推快照 + **JSON Patch（RFC 6902）**增量下发，替代 15s 全量轮询。
3. **SQLite 读侧**：WAL 模式读写分离；列表投影不带正文（SELECT 不取 content 列）；索引 `(kind, scope)` 与 `(type, ts)`。
4. **前端**：按 resourceVersion 做对象级缓存（rv 不变不重渲染）；`document.hidden` 暂停轮询；虚拟滚动保留。

判据：首屏一次聚合请求成形；连接存活期无全量轮询；列表查询 SQL 不取 content；隐藏 tab 零轮询。

## 3. 统一使用 library

**成熟库优先**：

| 域 | 选型 |
|---|---|
| markdown 渲染 | marked + dompurify |
| YAML | js-yaml |
| diff | diff |
| JSON Patch | fast-json-patch |
| WebSocket（后端） | coder/websocket |

**自写解析器（正则拆 YAML、自写 markdown 渲染等）一律迁移到库**。迁移红线=**行为零变化 + XSS 白名单不放松**（渲染输出过滤词形保持同一集）。

## 4. RuntimeStore 可插拔持久化

- **运行态投影落 SQLite**：trigger/run/delivery/wake/dispatch/intake 会话等运行态投影默认落 SQLite（ops DB 同库或独立 runtime DB 均可；建议独立 **`rt_*` 表族前缀**）。
- **存储接口化**：Store interface + 驱动注册表，未来可插 Postgres/MySQL/Redis/内存测试假体——上层语义不变。
- **重启恢复语义**：启动时全量装载（rt_* 表→内存投影），恢复后投影与重启前一致；装载失败=启动拒绝（投影宁拒不降级）。
- **与「观测面非账本」口径兼容**：账本=event_log/apply_log 不动（审计权威）；rt_*=活体投影、可重建，不承担账本职责——重启恢复是投影重建，不是账本重放。

运行时侧落地形态（rt_* schema 草案/装配旗标/验收收紧）见 core_system_instance runtime/perf-lint-baseline.md。

终态制：本文档只展示最终结果，变更历史只在 git 历史（[rule.md](../rule/rule.md)）。
