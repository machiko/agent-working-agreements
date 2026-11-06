#!/usr/bin/env bash
# review.test.sh — 驗證 review.sh 自省審查工具之行為。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REVIEW="$ROOT/scripts/review.sh"
TMP="$(mktemp -d /tmp/aw-review-test.XXXXXX)"
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

echo "▸ review.sh 說明與幫助 (--help)"
out_help="$("$REVIEW" --help)"
check "--help 印出用法" 'printf "%s" "$out_help" | grep -q "scripts/review.sh"'

echo "▸ review.sh 乾淨專案審查 (PASS)"
T_CLEAN="$TMP/clean-repo"
mkdir -p "$T_CLEAN"
(
  cd "$T_CLEAN"
  git init -q
  echo "hello" > a.txt
  git add a.txt
  git -c user.name="Tester" -c user.email="test@example.com" commit -qm "feat: init"
)
out_clean="$(cd "$T_CLEAN" && "$REVIEW")"
check "乾淨專案審核結論為完美通過" 'printf "%s" "$out_clean" | grep -q "完美通過"'

echo "▸ review.sh 捕捉空 catch 違規 (FAIL)"
(
  cd "$T_CLEAN"
  cat <<'EOF' > app.js
try { doSomething(); } catch (e) {}
EOF
  git add app.js
)
out_catch="$(cd "$T_CLEAN" && "$REVIEW" || true)"
check "捕捉空 catch 區塊" 'printf "%s" "$out_catch" | grep -q "發現靜默吞噬錯誤"'
check "審核結論為未通過" 'printf "%s" "$out_catch" | grep -q "未通過審核"'

echo "▸ review.sh 捕捉測試 sleep 延遲 (WARN)"
(
  cd "$T_CLEAN"
  git rm -f app.js >/dev/null
  cat <<'EOF' > app.test.js
test('sleep', async () => { sleep(1000); });
EOF
  git add app.test.js
)
out_sleep="$(cd "$T_CLEAN" && "$REVIEW" || true)"
check "測試中包含 sleep 輸出警告" 'printf "%s" "$out_sleep" | grep -q "測試中包含靜態硬編碼延遲"'

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 $TMP"
[ "$fail" -eq 0 ]
