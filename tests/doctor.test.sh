#!/usr/bin/env bash
# doctor.test.sh — 驗證 doctor.sh 診斷與 --fix 自動修復功能。

set -euo pipefail
export PATH="/usr/bin:/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCTOR="$ROOT/scripts/doctor.sh"
TMP="$(mktemp -d /tmp/aw-doctor-test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

check() {
  local desc="$1" cond="$2"
  if eval "$cond"; then
    echo "  ✓ $desc"
    pass=$((pass + 1))
  else
    echo "  ✗ $desc"
    fail=$((fail + 1))
  fi
}

echo "▸ doctor.sh 說明與幫助 (--help)"
out_help="$("$DOCTOR" --help)"
check "--help 印出用法且含 --fix" 'printf "%s" "$out_help" | grep -q -- "--fix"'

echo "▸ doctor.sh 診斷未安裝環境"
T_EMPTY="$TMP/empty-proj"
mkdir -p "$T_EMPTY"
out_empty="$("$DOCTOR" "$T_EMPTY" || true)"
check "未安裝專案提示 WARN" 'printf "%s" "$out_empty" | grep -q "\[WARN\]"'
check "評分低於 100" 'printf "%s" "$out_empty" | grep -E "守則體檢評分：[0-9]+ / 100" | grep -v "100 / 100"'

echo "▸ doctor.sh --fix 自動修復"
(cd "$T_EMPTY" && git init -q)
out_fix="$("$DOCTOR" --fix "$T_EMPTY")"
check "--fix 輸出自動修復動作" 'printf "%s" "$out_fix" | grep -q "AUTO-FIX"'
check "--fix 補齊核心守則" '[ -d "$T_EMPTY/.claude/rules/agent-agreements" ]'
check "--fix 補齊 CI 設定檔" '[ -f "$T_EMPTY/.github/workflows/agent-audit.yml" ]'
check "--fix 補齊 pre-commit 守門" '[ -x "$T_EMPTY/.git/hooks/pre-commit" ]'

out_after="$("$DOCTOR" "$T_EMPTY")"
check "修復後評分為滿分 100" 'printf "%s" "$out_after" | grep -q "100 / 100"'

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 $TMP"
[ "$fail" -eq 0 ]
