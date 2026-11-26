#!/usr/bin/env bash
# R-DOC-6 元数据侧车检查（rule/rule_doc.md）：
#   每篇 tracked *.md 同目录必须有 <name>.md.metadatainfo；
#   侧车必须含 tags: 且至少一项 {tag: ..., tag_type: ...}；importance: 0-100。
# 用法：lint/metadatainfo.sh [repo-root]（缺省=本仓根；可传 ../core_system_instance）
# 运行时验收报告（acceptance/ 根，gitignored）不在 tracked 集合内，自动跳过。
set -euo pipefail
cd "${1:-$(dirname "$0")/..}"

fail=0
count=0

while IFS= read -r f; do
  count=$((count + 1))
  meta="$f.metadatainfo"
  if [ ! -f "$meta" ]; then
    echo "MISSING  $meta"
    fail=1
    continue
  fi
  if ! grep -q '^tags:' "$meta"; then
    echo "NO_TAGS  $meta"
    fail=1
  fi
  if ! grep -Eq '^[[:space:]]*-[[:space:]]*\{[[:space:]]*tag:[[:space:]]*[^,}]+,[[:space:]]*tag_type:[[:space:]]*[a-z_-]+[[:space:]]*\}' "$meta"; then
    echo "BAD_TAG  $meta"
    fail=1
  fi
  imp="$(awk -F': *' '/^importance:/{print $2; exit}' "$meta")"
  if ! [[ "${imp:-}" =~ ^[0-9]+$ ]] || [ "$imp" -lt 0 ] || [ "$imp" -gt 100 ]; then
    echo "BAD_IMPORTANCE  $meta (${imp:-missing})"
    fail=1
  fi
done < <(git ls-files '*.md')

while IFS= read -r m; do
  doc="${m%.metadatainfo}"
  if [ ! -f "$doc" ]; then
    echo "ORPHAN  $m"
    fail=1
  fi
done < <(git ls-files '*.md.metadatainfo')

if [ "$fail" -ne 0 ]; then
  echo "✗ metadatainfo lint FAIL"
  exit 1
fi
echo "✓ metadatainfo lint 通过（$count 篇）"
