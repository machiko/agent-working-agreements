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

echo "▸ doctor.sh --init-policy 生成策略檔"
T_INIT_POLICY="$TMP/init-policy-proj"
mkdir -p "$T_INIT_POLICY"
(cd "$T_INIT_POLICY" && git init -q)
# 先安裝一些守則 (core + tenant-isolation)
bash "$ROOT/scripts/install.sh" --target "$T_INIT_POLICY/.claude/rules/agent-agreements" --select "security/tenant-isolation" >/dev/null 2>&1

# 執行 --init-policy
out_init="$("$DOCTOR" --init-policy "$T_INIT_POLICY")"
check "--init-policy 成功產出 .agreements.json" '[ -f "$T_INIT_POLICY/.agreements.json" ]'
check "--init-policy 包含 schema 引用" 'grep -q "schema/v1.json" "$T_INIT_POLICY/.agreements.json"'
check "--init-policy 包含已安裝守則" 'grep -q "security/tenant-isolation" "$T_INIT_POLICY/.agreements.json"'
check "--init-policy 包含 prohibit_disable_hooks" 'grep -q "prohibit_disable_hooks" "$T_INIT_POLICY/.agreements.json"'
if command -v python3 >/dev/null 2>&1; then
  check "--init-policy 產出符合 schema" '"$ROOT/scripts/check-schema.sh" "$T_INIT_POLICY/.agreements.json" >/dev/null'
fi

# 再次執行 --init-policy 應提示已存在而不覆蓋
out_init_again="$("$DOCTOR" --init-policy "$T_INIT_POLICY" 2>&1 || true)"
check "--init-policy 遇到已存在檔案不覆蓋" 'printf "%s" "$out_init_again" | grep -q "已存在"'

echo "▸ doctor.sh --fix 在已有 CI 設定的專案（不會複製 scripts/audit.sh）"
T_HAS_CI="$TMP/has-ci-proj"
mkdir -p "$T_HAS_CI"
(cd "$T_HAS_CI" && git init -q && git config user.email t@example.com && git config user.name T && git checkout -q -b feature/x)
echo "stages: [test]" > "$T_HAS_CI/.gitlab-ci.yml"
"$DOCTOR" --fix "$T_HAS_CI" > /dev/null
check "專案內沒有 scripts/audit.sh（前提）" '[ ! -f "$T_HAS_CI/scripts/audit.sh" ]'
check "pre-commit hook 已安裝" '[ -x "$T_HAS_CI/.git/hooks/pre-commit" ]'
(cd "$T_HAS_CI" && echo "x" > a.txt && git add a.txt)
check "沒有專案內 audit.sh 時 commit 仍成功（hook 改用 plugin 內的稽核腳本）" '(cd "$T_HAS_CI" && git commit -q -m "add a" >/dev/null 2>&1)'

echo "▸ doctor.sh 在 git worktree 中"
T_WT="$TMP/wt-proj"
(cd "$T_HAS_CI" && git worktree add -q "$T_WT" -b wt-branch >/dev/null 2>&1)
rm -f "$T_HAS_CI/.git/hooks/pre-commit" "$T_HAS_CI/.git/hooks/pre-push"
"$DOCTOR" --fix "$T_WT" > /dev/null
check "worktree 中 --fix 安裝 pre-commit 到共用 hooks 目錄" '[ -x "$T_HAS_CI/.git/hooks/pre-commit" ]'
check "worktree 中 --fix 安裝 pre-push 到共用 hooks 目錄" '[ -x "$T_HAS_CI/.git/hooks/pre-push" ]'
out_wt="$("$DOCTOR" "$T_WT")"
check "worktree 中診斷認得已安裝的 pre-commit" 'printf "%s" "$out_wt" | grep -q "pre-commit 主動稽核防線已啟動"'

echo "▸ doctor.sh --check-drift 在 Monorepo 子目錄"
T_MONO="$TMP/mono-proj"
mkdir -p "$T_MONO/packages/api"
(cd "$T_MONO" && git init -q)
printf '{ "enforce_rules": ["security/tenant-isolation"] }' > "$T_MONO/.agreements.json"
bash "$ROOT/scripts/install.sh" --target "$T_MONO/packages/api/.claude/rules/agent-agreements" >/dev/null 2>&1
check "子目錄安裝齊全時通過" '"$DOCTOR" --check-drift "$T_MONO/packages/api" >/dev/null 2>&1'
rm -f "$T_MONO/packages/api/.claude/rules/agent-agreements/security/tenant-isolation.md"
check "子目錄中策略強制守則檔案遺失時回傳非零" '! "$DOCTOR" --check-drift "$T_MONO/packages/api" >/dev/null 2>&1'

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 $TMP"
[ "$fail" -eq 0 ]
