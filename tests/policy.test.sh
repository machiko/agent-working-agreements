#!/usr/bin/env bash
# policy.test.sh — scripts/lib/policy.sh（團隊策略檔搜尋與解析）的行為測試。只寫入 /tmp 底下的暫存目錄。
set -uo pipefail
export PATH="/usr/bin:/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../scripts/lib/policy.sh
. "$ROOT/scripts/lib/policy.sh"
TMP="$(cd "$(mktemp -d /tmp/aw-policy-test.XXXXXX)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
check() { if eval "$2"; then echo "  ✓ $1"; pass=$((pass + 1)); else echo "  ✗ $1" >&2; fail=$((fail + 1)); fi; }

# 只放基本工具、沒有 python3 的 PATH，用來測 sed fallback
NOPY="$TMP/nopy-bin"
mkdir -p "$NOPY"
for t in tr sed grep dirname cat cut; do ln -s "$(command -v "$t")" "$NOPY/$t"; done

echo "▸ aw_find_policy：向上搜尋"
mkdir -p "$TMP/mono/packages/api"
printf '{ "enforce_rules": ["security/tenant-isolation"] }' > "$TMP/mono/.agreements.json"
check "子目錄向上找到根目錄策略檔" '[ "$(aw_find_policy "$TMP/mono/packages/api")" = "$TMP/mono/.agreements.json" ]'
check "起點目錄還不存在時從最近的父目錄開始找" '[ "$(aw_find_policy "$TMP/mono/packages/new/.claude/rules")" = "$TMP/mono/.agreements.json" ]'
check "起點是檔案時從所在目錄開始找" 'touch "$TMP/mono/packages/api/AGENTS.md"; [ "$(aw_find_policy "$TMP/mono/packages/api/AGENTS.md")" = "$TMP/mono/.agreements.json" ]'

mkdir -p "$TMP/rc"
printf '{ "enforce_rules": [] }' > "$TMP/rc/.agreementsrc"
check "支援 .agreementsrc" '[ "$(aw_find_policy "$TMP/rc")" = "$TMP/rc/.agreementsrc" ]'

echo "▸ aw_find_policy：停在 git root、不讀家目錄"
mkdir -p "$TMP/outer/repo/sub"
(cd "$TMP/outer/repo" && git init -q)
printf '{}' > "$TMP/outer/.agreements.json"
check "git repo 外層的策略檔不會被讀到" '! aw_find_policy "$TMP/outer/repo/sub" >/dev/null'
printf '{}' > "$TMP/outer/repo/.agreements.json"
check "git root 上的策略檔會被讀到" '[ "$(aw_find_policy "$TMP/outer/repo/sub")" = "$TMP/outer/repo/.agreements.json" ]'

FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude/rules/agent-agreements"
printf '{}' > "$FAKE_HOME/.agreements.json"
check "不在 git repo 時不讀家目錄的策略檔（全域安裝）" '! HOME="$FAKE_HOME" aw_find_policy "$FAKE_HOME/.claude/rules/agent-agreements" >/dev/null'

echo "▸ aw_policy_enforce_rules"
printf '{\n  "enforce_rules": [\n    "a/one",\n    "b/two"\n  ]\n}\n' > "$TMP/multi.json"
printf '{ "enforce_rules": ["a/one", "b/two", "c/three"], "prohibit_disable_hooks": false }' > "$TMP/single.json"
check "多行陣列（python3）" '[ "$(aw_policy_enforce_rules "$TMP/multi.json" | tr "\n" ,)" = "a/one,b/two," ]'
check "單行陣列（python3）" '[ "$(aw_policy_enforce_rules "$TMP/single.json" | tr "\n" ,)" = "a/one,b/two,c/three," ]'
check "多行陣列（沒有 python3）" '[ "$(PATH="$NOPY" aw_policy_enforce_rules "$TMP/multi.json" | tr "\n" ,)" = "a/one,b/two," ]'
check "單行陣列（沒有 python3）取到全部項目" '[ "$(PATH="$NOPY" aw_policy_enforce_rules "$TMP/single.json" | tr "\n" ,)" = "a/one,b/two,c/three," ]'

echo "▸ aw_policy_prohibits_disable"
printf '{ "prohibit_disable_hooks": true }' > "$TMP/lock.json"
printf '{ "prohibit_disable_hooks": "false" }' > "$TMP/str.json"
printf '{ "prohibit_disable_hooks": false }' > "$TMP/open.json"
printf '[1, 2]' > "$TMP/arr.json"
check "true 時鎖定" 'aw_policy_prohibits_disable "$TMP/lock.json"'
check "false 時不鎖定" '! aw_policy_prohibits_disable "$TMP/open.json"'
check "字串 \"false\" 不鎖定" '! aw_policy_prohibits_disable "$TMP/str.json"'
check "不是 JSON 物件時採安全預設（鎖定）" 'aw_policy_prohibits_disable "$TMP/arr.json" 2>/dev/null'
check "沒有 python3 時 true 仍鎖定" 'PATH="$NOPY" aw_policy_prohibits_disable "$TMP/lock.json"'
check "沒有 python3 時字串 \"false\" 不鎖定" '! PATH="$NOPY" aw_policy_prohibits_disable "$TMP/str.json"'
check "沒有 python3 時不是 JSON 物件也採安全預設" 'PATH="$NOPY" aw_policy_prohibits_disable "$TMP/arr.json" 2>/dev/null'

echo "──"
echo "通過 ${pass}｜失敗 ${fail}"
[ "$fail" -eq 0 ]
