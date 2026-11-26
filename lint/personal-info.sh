#!/bin/sh
# lint/personal-info.sh — R-PUB-1 checker（rule.md「开发规范（公开暴露面）」）
# 规则回指：R-PUB-1 公开仓不暴露个人信息 + R-PUB-2 个人决策不入公开仓
#
# 用法: lint/personal-info.sh [paths...]
#   缺省扫描本仓根；可传其他仓路径（如 ../core_system_instance）
#   退出码: 0=干净  1=有命中
#
# 机械判定范围（判不准的留在 policy，R-TYPE-2）：
#   ① IP 地址（白名单：127.0.0.1 / 0.0.0.0 / 255.255.255.255 / RFC5737 文档段）
#   ② 真实部署绝对路径（/root/、/home/<user>/）
#   ③ 个人网络标识（内网域名/个人域名）与 provider 选型残留
#      （bigmodel、code27.cn、glm-<数字> 模型名、绑定账号的 *_API_KEY 变量名）
# 排除：.git/、lint/ 自身、friddle_decision.md（R-PUB-2 台账，gitignore）

set -u
set -f   # noglob：--include=*.md 等模式不随 cwd 误展开

self_dir="$(cd "$(dirname "$0")" && pwd)"
targets="${*:-"$self_dir/.."}"

# RFC5737 文档段与回环地址是合规示例，不拦
IP_RE='([0-9]{1,3}\.){3}[0-9]{1,3}'
IP_WHITELIST='127\.0\.0\.1|0\.0\.0\.0|255\.255\.255\.255|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.'
PATH_RE='/root/|/home/[a-zA-Z0-9._-]+/'
IDENT_RE='code27\.cn|bigmodel|GLM_CODING|DEEPSEEK_API_KEY|DASHSCOPE_API_KEY|MOONSHOT_API_KEY|glm-[0-9]'

GREP_OPTS="-rnE --include=*.md --include=*.yaml --include=*.yml --include=*.json --include=*.ts --include=*.js --exclude-dir=.git --exclude-dir=.playwright-mcp --exclude-dir=shots --exclude-dir=lint --exclude-dir=node_modules --exclude-dir=acceptance --exclude=friddle_decision.md"

hits=0

report() {
  # $1=规则点 $2=正则 $3=附加过滤正则（可为空）
  if [ -n "${3:-}" ]; then
    matches=$(grep $GREP_OPTS -e "$2" $targets 2>/dev/null | grep -vE "$3" || true)
  else
    matches=$(grep $GREP_OPTS -e "$2" $targets 2>/dev/null || true)
  fi
  if [ -n "$matches" ]; then
    echo "✗ R-PUB-1 命中 [$1]:"
    echo "$matches" | cut -c1-160
    hits=$((hits + $(echo "$matches" | wc -l)))
  fi
}

report "IP地址"        "$IP_RE"    "$IP_WHITELIST"
report "部署绝对路径"  "$PATH_RE"  ""
report "个人标识/选型" "$IDENT_RE" ""

if [ "$hits" -eq 0 ]; then
  echo "✓ personal-info lint 通过（R-PUB-1/R-PUB-2）"
  exit 0
fi
echo "  共 $hits 处。公开文档改用占位符：<内网域名> / <部署根目录> / <PROVIDER>_API_KEY / “X 档”；实际值记 friddle_decision.md（R-PUB-2）"
exit 1
