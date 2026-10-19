#!/usr/bin/env bash
# install.test.sh — scripts/install.sh 的行為測試。只寫入 /tmp 底下的暫存目錄。
#
# 用法：tests/install.test.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/scripts/install.sh"
TMP="$(mktemp -d /tmp/aw-install-test.XXXXXX)"

pass=0
fail=0

ok()   { echo "  ✓ $1"; pass=$((pass + 1)); }
bad()  { echo "  ✗ $1" >&2; fail=$((fail + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# 從 --list 取得 core 清單與兩個 optional id，避免測試綁死特定規則
CORE_IDS="$("$INSTALL" --list | awk -F'\t' '$2 == "core" { print $1 }')"
CORE_COUNT="$(printf '%s\n' "$CORE_IDS" | grep -c .)"
FIRST_CORE="$(printf '%s\n' "$CORE_IDS" | head -n 1)"
OPT_A="$("$INSTALL" --list | awk -F'\t' '$2 == "optional" { print $1 }' | sed -n 1p)"
OPT_B="$("$INSTALL" --list | awk -F'\t' '$2 == "optional" { print $1 }' | sed -n 2p)"

profile_files() { grep -c '^file=' "$1/.agreements-profile" 2>/dev/null || echo 0; }

echo "▸ dry-run 不寫入任何檔案"
T="$TMP/dry"
out="$("$INSTALL" --target "$T" --select "$OPT_A" --dry-run)"
check "目標目錄未建立" '[ ! -e "$T" ]'
check "輸出列出新增項目" 'printf "%s" "$out" | grep -q "＋ 新增 $OPT_A.md"'

echo "▸ 首次安裝：core ＋ 選擇的 optional"
T="$TMP/fresh"
"$INSTALL" --target "$T" --select "$OPT_A" > /dev/null
check "core 第一個檔案存在" '[ -f "$T/$FIRST_CORE.md" ]'
check "optional A 存在" '[ -f "$T/$OPT_A.md" ]'
check "profile 記錄 core＋1 個檔案" '[ "$(profile_files "$T")" -eq $((CORE_COUNT + 1)) ]'
check "profile 記錄 selected" 'grep -qx "selected=$OPT_A" "$T/.agreements-profile"'
check "內容與來源相同" 'cmp -s "$ROOT/rules/$OPT_A.md" "$T/$OPT_A.md"'

echo "▸ 重跑換選項：移除 A、新增 B，core 不變"
out="$("$INSTALL" --target "$T" --select "$OPT_B")"
check "A 已移除" '[ ! -e "$T/$OPT_A.md" ]'
check "B 已新增" '[ -f "$T/$OPT_B.md" ]'
check "core 標示為不變" 'printf "%s" "$out" | grep -q "＝ 不變 $CORE_COUNT 個"'
check "profile 檔案數正確" '[ "$(profile_files "$T")" -eq $((CORE_COUNT + 1)) ]'

echo "▸ 手動修改過的檔案：沒有 --force 就保留"
echo "<!-- 使用者自己加的 -->" >> "$T/$FIRST_CORE.md"
"$INSTALL" --target "$T" --select "$OPT_B,$OPT_A" > "$TMP/out-modified" 2>&1
check "修改內容仍在" 'grep -q "使用者自己加的" "$T/$FIRST_CORE.md"'
check "輸出提示保留" 'grep -q "！ 保留.*$FIRST_CORE.md" "$TMP/out-modified"'
check "同一輪的新增照常進行" '[ -f "$T/$OPT_A.md" ]'
"$INSTALL" --target "$T" --select "$OPT_B,$OPT_A" > /dev/null
check "重跑仍保留（不被當成已同步）" 'grep -q "使用者自己加的" "$T/$FIRST_CORE.md"'
"$INSTALL" --target "$T" --select "$OPT_B,$OPT_A" --force > /dev/null
check "加 --force 後還原成來源內容" 'cmp -s "$ROOT/rules/$FIRST_CORE.md" "$T/$FIRST_CORE.md"'

echo "▸ 目標已有非本工具安裝的同名檔案：不覆蓋"
T2="$TMP/foreign-same-name"
mkdir -p "$(dirname "$T2/$FIRST_CORE.md")"
echo "別人的檔案" > "$T2/$FIRST_CORE.md"
"$INSTALL" --target "$T2" > "$TMP/out-foreign" 2>&1
check "同名檔案內容未變" '[ "$(cat "$T2/$FIRST_CORE.md")" = "別人的檔案" ]'
check "輸出提示略過" 'grep -q "！ 略過.*$FIRST_CORE.md" "$TMP/out-foreign"'
check "未寫入 profile 記錄" '! grep -q "file=$FIRST_CORE " "$T2/.agreements-profile"'

echo "▸ 移除：只刪 profile 記錄的檔案"
echo "使用者自己的規則" > "$T/my-own-rule.md"
"$INSTALL" --target "$T" --uninstall --dry-run > /dev/null
check "uninstall --dry-run 不刪檔" '[ -f "$T/$OPT_A.md" ] && [ -f "$T/.agreements-profile" ]'
"$INSTALL" --target "$T" --uninstall > /dev/null
check "已安裝的規則都被刪除" '[ ! -e "$T/$FIRST_CORE.md" ] && [ ! -e "$T/$OPT_A.md" ] && [ ! -e "$T/$OPT_B.md" ]'
check "profile 被刪除" '[ ! -e "$T/.agreements-profile" ]'
check "使用者自己的檔案還在" '[ -f "$T/my-own-rule.md" ]'

echo "▸ 移除時保留被手動修改的檔案"
T3="$TMP/uninstall-modified"
"$INSTALL" --target "$T3" > /dev/null
echo "改過" >> "$T3/$FIRST_CORE.md"
"$INSTALL" --target "$T3" --uninstall > /dev/null
check "修改過的檔案保留" '[ -f "$T3/$FIRST_CORE.md" ]'
"$INSTALL" --target "$T3" --uninstall --force > /dev/null
check "加 --force 後刪除" '[ ! -e "$T3/$FIRST_CORE.md" ] && [ ! -e "$T3/.agreements-profile" ]'

echo "▸ 參數錯誤"
"$INSTALL" --target "$TMP/bad" --select no/such-rule > /dev/null 2>&1
check "未知 id 回傳 2" '[ $? -eq 2 ]'
"$INSTALL" --select "$OPT_A" > /dev/null 2>&1
check "缺 --target 回傳 2" '[ $? -eq 2 ]'

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 $TMP"
[ "$fail" -eq 0 ]
