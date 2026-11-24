#!/bin/sh
# lint/docsroot-admission.sh — docsRoot 存量对象净入 lint wrapper（R-TYPE-2 checker 契约）
# 规则回指：core_design/concepts/scheme.md 设计规则 6「spec 声明机读语义（准入 checker）」应用点②
#           ——存量面净入 lint（docsRoot 存量对象零校验放行收口：读面宽松/写面严格双严格度劈叉）。
# checker 本体：core_system_workservice `cmd/cored-lint`（internal/repository.LintDocs 五闸引擎，
# 与写路径同闸门清单——路径注册/可解析/身份一致/spec 准入/凭据来源 + scheme 镜像漂移闸）。
#
# 用法: lint/docsroot-admission.sh <scheme.yaml> <docsRoot>
#   <scheme.yaml>  scheme 权威声明（净入判据的声明面）
#   <docsRoot>     文档库根（净入扫描根，git 布局）
#   环境变量 CORE_LINT_BIN 可指预编译 cored-lint 二进制（缺省 go run 本仓兄弟仓源码）。
#   退出码: 0=净入全绿  1=有发现  2=用法/装配错
#
# 纪律：本 wrapper 纯只读透传——路径由调用方传入（部署面不入仓，R-PUB-1）。

set -u

scheme_file="${1:-}"
docs_root="${2:-}"
if [ -z "$scheme_file" ] || [ -z "$docs_root" ]; then
  echo "用法: lint/docsroot-admission.sh <scheme.yaml> <docsRoot>" >&2
  exit 2
fi
if [ ! -f "$scheme_file" ]; then
  echo "scheme 权威不存在: $scheme_file" >&2
  exit 2
fi
if [ ! -d "$docs_root" ]; then
  echo "docsRoot 不存在: $docs_root" >&2
  exit 2
fi

self_dir="$(cd "$(dirname "$0")" && pwd)"
ws_dir="${CORE_WORKSERVICE_DIR:-$self_dir/../../core_system_workservice}"

if [ -n "${CORE_LINT_BIN:-}" ]; then
  exec "$CORE_LINT_BIN" --scheme "$scheme_file" --docs "$docs_root"
fi
if [ ! -d "$ws_dir" ]; then
  echo "workservice 仓不可达（CORE_WORKSERVICE_DIR 或缺省兄弟仓布局）: $ws_dir" >&2
  exit 2
fi
cd "$ws_dir" && exec go run ./cmd/cored-lint --scheme "$scheme_file" --docs "$docs_root"
