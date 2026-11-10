#!/usr/bin/env bash
# check-budget.test.sh — scripts/check-budget.sh 的行為測試。只寫入 /tmp 底下的暫存目錄。
#
# 用法：tests/check-budget.test.sh

set -uo pipefail
export PATH="/usr/bin:/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/scripts/check-budget.sh"
TMP="$(mktemp -d /tmp/aw-budget-test.XXXXXX)"

pass=0
fail=0

ok()   { echo "  ✓ $1"; pass=$((pass + 1)); }
bad()  { echo "  ✗ $1" >&2; fail=$((fail + 1)); }

# fixture <目錄> <frontmatter 額外內容>：建立一條 collaboration/a 規則
fixture() {
  mkdir -p "$1/rules/collaboration"
  printf -- '---\ncategory: collaboration\ntier: core\n%s---\n\n# 標題\n\n內容\n' "$2" > "$1/rules/collaboration/a.md"
}

# expect <說明> <預期結束碼> <目錄>
expect() {
  ROOT="$3" "$CHECK" > "$TMP/out" 2>&1
  local rc=$?
  if [ "$rc" -eq "$2" ]; then ok "$1"; else bad "$1（exit ${rc}，預期 $2）"; sed 's/^/      /' "$TMP/out" >&2; fi
}

has() {
  if grep -qF -- "$2" "$TMP/out"; then ok "$1"; else bad "$1（輸出沒有「$2」）"; sed 's/^/      /' "$TMP/out" >&2; fi
}

VALID=$'incidents:\n  - 曾在別人的分支上 commit\nlast_reviewed: 2026-11-10\n'

echo "▸ 欄位齊全"
fixture "$TMP/ok" "$VALID"
expect "exit 0" 0 "$TMP/ok"

echo "▸ 缺 incidents"
fixture "$TMP/no-inc" $'last_reviewed: 2026-11-10\n'
expect "exit 1" 1 "$TMP/no-inc"
has "指出 incidents" "incidents"

echo "▸ incidents 是空清單"
fixture "$TMP/empty-inc" $'incidents:\nlast_reviewed: 2026-11-10\n'
expect "exit 1" 1 "$TMP/empty-inc"
has "指出 incidents" "incidents"

echo "▸ 缺 last_reviewed"
fixture "$TMP/no-date" $'incidents:\n  - 事故\n'
expect "exit 1" 1 "$TMP/no-date"
has "指出 last_reviewed" "last_reviewed"

echo "▸ last_reviewed 格式錯誤"
fixture "$TMP/bad-date" $'incidents:\n  - 事故\nlast_reviewed: 2026/11/10\n'
expect "exit 1" 1 "$TMP/bad-date"
has "指出日期格式" "YYYY-MM-DD"

echo "▸ 本 repo"
expect "目前的守則全部通過" 0 "$ROOT"

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 ${TMP}"
[ "$fail" -eq 0 ]
