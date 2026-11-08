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
check "--fix 補齊 pre-push 守門" '[ -x "$T_EMPTY/.git/hooks/pre-push" ]'

out_after="$("$DOCTOR" "$T_EMPTY")"
check "修復後評分為滿分 100" 'printf "%s" "$out_after" | grep -q "100 / 100"'

echo "▸ doctor.sh --check-drift CI 防漂移檢驗"
# 1. 正常安裝專案通過檢驗
out_drift_ok="$("$DOCTOR" --check-drift "$T_EMPTY")"
check "--check-drift 正常專案通過" 'printf "%s" "$out_drift_ok" | grep -q "No Drift Detected"'

# 2. 未安裝專案檢驗失敗 (exit 1)
T_NODRIFT="$TMP/nodrift-proj"
mkdir -p "$T_NODRIFT"
check "--check-drift 未安裝專案回傳非零" '! "$DOCTOR" --check-drift "$T_NODRIFT" >/dev/null 2>&1'

# 3. 核心守則遭修改檢驗失敗
core_file="$T_EMPTY/.claude/rules/agent-agreements/collaboration/git-safety.md"
echo "# 惡意竄改守則" > "$core_file"
check "--check-drift 核心守則被竄改回傳非零" '! "$DOCTOR" --check-drift "$T_EMPTY" >/dev/null 2>&1'

# 還原核心守則
bash "$ROOT/scripts/install.sh" --target "$T_EMPTY/.claude/rules/agent-agreements" --force >/dev/null 2>&1

# 4. 團隊策略強制守則未安裝檢驗失敗
cat <<'EOF' > "$T_EMPTY/.agreements.json"
{
  "enforce_rules": ["security/tenant-isolation"]
}
EOF
check "--check-drift 缺少團隊策略強制守則回傳非零" '! "$DOCTOR" --check-drift "$T_EMPTY" >/dev/null 2>&1'

# 補齊團隊策略強制守則後通過檢驗
bash "$ROOT/scripts/install.sh" --target "$T_EMPTY/.claude/rules/agent-agreements" >/dev/null 2>&1
out_drift_policy="$("$DOCTOR" --check-drift "$T_EMPTY")"
check "--check-drift 補齊團隊強制守則後通過" 'printf "%s" "$out_drift_policy" | grep -q "符合團隊策略檔"'

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 $TMP"
[ "$fail" -eq 0 ]
