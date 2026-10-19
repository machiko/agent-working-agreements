#!/usr/bin/env bash
# sanitize-check.sh — 發布前掃描會公開的檔案，找出識別資訊。
#
# 用法：scripts/sanitize-check.sh
#   AGREEMENTS_DENYLIST=<檔案>  私人禁用詞清單（預設 ~/.claude/agreements-harvest/denylist.txt）
#
# 禁用詞清單一行一個 extended regex（不分大小寫），# 開頭為註解。
# 清單本身含識別資訊，絕不可放進 repo。
#
# 結束碼：0 通過；1 有命中。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DENYLIST="${AGREEMENTS_DENYLIST:-$HOME/.claude/agreements-harvest/denylist.txt}"

# 內建規則：不需要私人清單也能抓到的通用識別資訊
BUILTIN='/Users/[A-Za-z0-9._-]+|/home/[A-Za-z0-9._-]+|(^|[^0-9.])(10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+)|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
EMAIL='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
EMAIL_ALLOWED='@users\.noreply\.github\.com$|@example\.(com|org|net)$'

cd "$ROOT"

# 掃描範圍：會公開的檔案（已追蹤，或未追蹤但沒被 .gitignore 排除）
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  FILES="$(git ls-files -co --exclude-standard)"
else
  FILES="$(find . -type f -not -path './.git/*' -not -path './.claude/PRPs/*' | sed 's#^\./##')"
fi
# 本腳本自己含有規則字串，不掃
FILES="$(printf '%s\n' "$FILES" | grep -v '^scripts/sanitize-check\.sh$' || true)"

hits=0

# grep_files <grep 旗標> <regex>：對所有檔案跑 grep，輸出 檔案:行號:內容
grep_files() {
  printf '%s\n' "$FILES" | while IFS= read -r f; do
    [ -f "$f" ] && grep -Hn "$1" -e "$2" "$f" 2>/dev/null || true
  done
}

report() {
  local label="$1" line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    echo "✗ [${label}] ${line}"
    hits=$((hits + 1))
  done
}

report "通用" < <(grep_files -E "$BUILTIN")
report "信箱" < <(grep_files -oE "$EMAIL" | grep -viE "$EMAIL_ALLOWED" || true)

if [ -f "$DENYLIST" ]; then
  while IFS= read -r pattern; do
    case "$pattern" in ''|'#'*) continue ;; esac
    report "禁用詞" < <(grep_files -iE "$pattern")
  done < "$DENYLIST"
else
  echo "⚠ 找不到私人禁用詞清單：${DENYLIST}（只跑內建規則）" >&2
fi

echo "──"
if [ "$hits" -gt 0 ]; then
  echo "✗ ${hits} 處命中，發布前請改寫" >&2
  exit 1
fi
echo "✓ 沒有命中"
