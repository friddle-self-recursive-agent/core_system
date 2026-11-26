#!/usr/bin/env bash
# R-DOC-8 单文件单 Scheme 检查（rule/rule_doc.md）：
#   自己保存的权威 .yaml 文件严禁出现多个 Scheme / TaskScheme 对象（禁止多 Scheme 在一个文件）；
#   外部导入目录（imports/ 或 *.import.yaml）除外，但落库后必须拆为单文件单 Scheme。
set -euo pipefail
cd "${1:-$(dirname "$0")/..}"

fail=0
count=0

while IFS= read -r f; do
  case "$f" in
    *.import.yaml|imports/*) continue ;;
  esac
  count=$((count + 1))
  schemes="$(grep -Ec '^[[:space:]]*kind:[[:space:]]*(Scheme|TaskScheme)([[:space:]]|$|#)' "$f" || true)"
  if [ "${schemes:-0}" -gt 1 ]; then
    echo "MULTI_SCHEME  $f (found $schemes Scheme/TaskScheme objects in one file; R-DOC-8 requires 1 per file)"
    fail=1
  fi
done < <(git ls-files '*.yaml' '*.yml')

if [ "$fail" -ne 0 ]; then
  echo "✗ single-scheme lint FAIL"
  exit 1
fi
echo "✓ single-scheme lint 通过（扫描 $count 个 yaml 文件，均满足单文件单 Scheme）"
