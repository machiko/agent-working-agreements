#!/usr/bin/env bash
# check-schema.test.sh — check-schema.sh 的守則與機器檢查連動（enforced_by ↔ audit.sh @check、guard-rules.tsv）測試。
# 在 /tmp 底下複製一份 repo 再改壞，不改動本 repo。
#
# 用法：tests/check-schema.test.sh

set -uo pipefail
export PATH="/usr/bin:/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/aw-check-schema-test.XXXXXX)"

pass=0
fail=0

ok()  { echo "  ✓ $1"; pass=$((pass + 1)); }
bad() { echo "  ✗ $1" >&2; fail=$((fail + 1)); }

# fresh <名稱>：複製一份 repo，印出路徑
fresh() {
  mkdir -p "$TMP/$1"
  cp -R "$ROOT/scripts" "$ROOT/rules" "$ROOT/schema" "$ROOT/templates" "$TMP/$1/"
  echo "$TMP/$1"
}

# expect_fail <說明> <repo> <訊息片段>
expect_fail() {
  if ROOT="$2" "$2/scripts/check-schema.sh" > "$TMP/out" 2>&1; then
    bad "$1（應失敗）"
  elif grep -qF -- "$3" "$TMP/out"; then
    ok "$1"
  else
    bad "$1（訊息沒有「$3」）"; sed 's/^/      /' "$TMP/out" >&2
  fi
}

# drop_line <檔案> <整行內容>
drop_line() { grep -vxF -- "$2" "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }

echo "▸ 目前的 repo"
if ROOT="$ROOT" "$ROOT/scripts/check-schema.sh" > "$TMP/out" 2>&1; then ok "通過"; else bad "應通過"; cat "$TMP/out" >&2; fi
grep -q "機器檢查" "$TMP/out" && ok "回報連動的檢查數" || bad "沒有回報連動的檢查數"

echo "▸ 守則漏列 audit 檢查"
R="$(fresh missing-audit)"
drop_line "$R/rules/api/pitfalls.md" "  - audit:empty-catch"
expect_fail "缺 enforced_by 時失敗" "$R" "audit:empty-catch"

echo "▸ 守則漏列 guard"
R="$(fresh missing-guard)"
drop_line "$R/rules/security/dangerous-operations.md" "  - guard:dangerous-operations"
expect_fail "guard 沒被列入時失敗" "$R" "guard:dangerous-operations"

echo "▸ enforced_by 指向不存在的檢查"
R="$(fresh unknown-id)"
awk '{ print } $0 == "  - audit:empty-catch" { print "  - audit:no-such-check" }' "$R/rules/api/pitfalls.md" > "$R/x" && mv "$R/x" "$R/rules/api/pitfalls.md"
expect_fail "不存在的 ID 失敗" "$R" "audit:no-such-check"

echo "▸ 檢查列在錯誤的守則"
R="$(fresh wrong-rule)"
awk '{ print } $0 == "enforced_by:" { print "  - audit:main-branch" }' "$R/rules/security/data-files.md" > "$R/x" && mv "$R/x" "$R/rules/security/data-files.md"
expect_fail "audit ID 歸屬不符時失敗" "$R" "collaboration/git-safety"

echo "▸ guard 列在非同名守則"
R="$(fresh wrong-guard)"
awk '{ print } $0 == "enforced_by:" { print "  - guard:git-safety" }' "$R/rules/security/data-files.md" > "$R/x" && mv "$R/x" "$R/rules/security/data-files.md"
expect_fail "guard 只能由同名守則列入" "$R" "同名守則"

echo "▸ audit.sh 標記格式與歸屬"
R="$(fresh bad-marker)"
sed -i.bak 's|^# @check audit:empty-catch api/pitfalls$|# @check audit:empty-catch|' "$R/scripts/audit.sh"
expect_fail "缺守則 id 的標記失敗" "$R" "格式"

R="$(fresh missing-rule)"
sed -i.bak 's|^# @check audit:empty-catch api/pitfalls$|# @check audit:empty-catch api/no-such-rule|' "$R/scripts/audit.sh"
expect_fail "標記指向不存在的守則時失敗" "$R" "api/no-such-rule"

echo "▸ 寬鬆寫法要報錯，不可默默略過"
R="$(fresh inline-list)"
awk '$0 == "enforced_by:" { print "enforced_by: [audit:empty-catch]"; skip = 1; next } skip && /^  - / { next } { skip = 0; print }' "$R/rules/api/pitfalls.md" > "$R/x" && mv "$R/x" "$R/rules/api/pitfalls.md"
expect_fail "行內清單寫法失敗" "$R" "區塊清單"

R="$(fresh unmarked-check)"
awk '{ print } /^# 7\. / { print ""; print "# 8. 新的檢查"; print "true" }' "$R/scripts/audit.sh" > "$R/x" && mv "$R/x" "$R/scripts/audit.sh"
expect_fail "新增檢查沒加標記時失敗" "$R" "8. 新的檢查"

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 ${TMP}"
[ "$fail" -eq 0 ]
