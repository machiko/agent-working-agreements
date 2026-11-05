#!/usr/bin/env bash
# check-version.test.sh — scripts/check-version.sh 的行為測試。只寫入 /tmp 底下的暫存目錄。
#
# 用法：tests/check-version.test.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/scripts/check-version.sh"
TMP="$(mktemp -d /tmp/aw-version-test.XXXXXX)"

pass=0
fail=0

ok()   { echo "  ✓ $1"; pass=$((pass + 1)); }
bad()  { echo "  ✗ $1" >&2; fail=$((fail + 1)); }

# fixture <目錄> <plugin 版號> <marketplace 版號> <CHANGELOG 最新版本段>
fixture() {
  mkdir -p "$1/.claude-plugin"
  printf '{\n  "name": "x",\n  "version": "%s"\n}\n' "$2" > "$1/.claude-plugin/plugin.json"
  printf '{\n  "plugins": [\n    { "name": "x", "version": "%s" }\n  ]\n}\n' "$3" > "$1/.claude-plugin/marketplace.json"
  printf '# Changelog\n\n## [Unreleased]\n\n## [%s] - 2026-01-01\n\n## [0.0.1] - 2025-01-01\n' "$4" > "$1/CHANGELOG.md"
}

# expect <說明> <預期結束碼> <目錄>
expect() {
  ROOT="$3" "$CHECK" > "$TMP/out" 2>&1
  local rc=$?
  if [ "$rc" -eq "$2" ]; then ok "$1"; else bad "$1（exit $rc，預期 $2）"; sed 's/^/      /' "$TMP/out" >&2; fi
}

echo "▸ 三處版號一致"
fixture "$TMP/same" 1.2.0 1.2.0 1.2.0
expect "exit 0" 0 "$TMP/same"
grep -q "版號一致：1.2.0" "$TMP/out" && ok "印出版號" || bad "印出版號"

echo "▸ marketplace.json 與 plugin.json 不同"
fixture "$TMP/market" 1.2.0 1.1.0 1.2.0
expect "exit 1" 1 "$TMP/market"
grep -q "marketplace.json" "$TMP/out" && ok "指出 marketplace.json" || bad "指出 marketplace.json"

echo "▸ CHANGELOG 最新版本段與 plugin.json 不同（跳過 Unreleased）"
fixture "$TMP/changelog" 1.2.0 1.2.0 1.1.0
expect "exit 1" 1 "$TMP/changelog"
grep -q "CHANGELOG.md" "$TMP/out" && ok "指出 CHANGELOG.md" || bad "指出 CHANGELOG.md"

echo "▸ 缺 CHANGELOG"
fixture "$TMP/missing" 1.2.0 1.2.0 1.2.0
mv "$TMP/missing/CHANGELOG.md" "$TMP/missing/CHANGELOG.bak"
expect "exit 1" 1 "$TMP/missing"

echo "▸ 本 repo"
expect "目前的 repo 版號一致" 0 "$ROOT"

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 ${TMP}"
[ "$fail" -eq 0 ]
