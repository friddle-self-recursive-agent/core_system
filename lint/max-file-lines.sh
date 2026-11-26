#!/usr/bin/env bash
# lint/max-file-lines.sh — R-ENG-7 单文件行数硬上限 checker（rule/rule_eng.md，ruleId=R-ENG-7）
#   一切代码与标记语言文件不允许超过 800 行（含注释与空行；dist/ 构建输出与 lockfile 豁免）。
#   超限必须拆分：Go 按职责拆文件/子包；TS/JS 按模块/屏拆；CSS 按组件域拆（重构零语义变化）。
# 用法：lint/max-file-lines.sh [repo-root]（缺省=本仓根；可传 ../core_system_instance）
# 退出码：0=全绿（无超限）  1=有超限文件（输出文件名与行数）
set -euo pipefail
cd "${1:-$(dirname "$0")/..}"

LIMIT=800

fail=0
while IFS= read -r f; do
  base="${f##*/}"
  # 豁免词形：构建产物 dist/ 与 lockfile（R-ENG-7 判据④）
  case "$f" in
    dist/*|*/dist/*) continue ;;
  esac
  case "$base" in
    *.lock|pnpm-lock.yaml|package-lock.json|go.sum) continue ;;
  esac
  # 受检扩展名：一切代码与标记语言（R-ENG-7 判据③：集合=git ls-files，新增文件默认受检）
  ext="${base##*.}"
  case "$ext" in
    go|ts|tsx|js|jsx|mjs|cjs|mts|cts|css|scss|less|html|htm|sh|bash|py|sql|rs|java|kt|swift|php|c|cc|cpp|h|hpp|vue) ;;
    *) continue ;;
  esac
  lines="$(awk 'END{print NR}' "$f")"
  if [ "$lines" -gt "$LIMIT" ]; then
    echo "OVER  $f  ${lines} 行（上限 ${LIMIT}）"
    fail=1
  fi
done < <(git ls-files)

if [ "$fail" -ne 0 ]; then
  echo "✗ max-file-lines lint FAIL（R-ENG-7：>800 行必须拆分）"
  exit 1
fi
echo "✓ max-file-lines lint 通过（R-ENG-7 单文件≤${LIMIT} 行）"
