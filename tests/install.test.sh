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

sha() { shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1 || sha256sum "$1" | cut -d' ' -f1; }

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

echo "▸ --agents-md：不存在的檔案 → 建立只含區塊的檔案"
A="$TMP/agents-new/AGENTS.md"
"$INSTALL" --agents-md "$A" --select "$OPT_A" --dry-run > "$TMP/out-agents-dry"
check "dry-run 不建立檔案" '[ ! -e "$A" ]'
check "dry-run 輸出列出新增與大小" 'grep -q "＋ 新增 $OPT_A" "$TMP/out-agents-dry" && grep -q "bytes" "$TMP/out-agents-dry"'
"$INSTALL" --agents-md "$A" --select "$OPT_A" > /dev/null
check "檔案以開始標記起頭" 'head -n 1 "$A" | grep -q "^<!-- agent-agreements:start v"'
check "檔案以結束標記收尾" '[ "$(tail -n 1 "$A")" = "<!-- agent-agreements:end -->" ]'
check "記錄 selected" 'grep -qx "<!-- agent-agreements:selected=$OPT_A -->" "$A"'
check "core 與 optional A 都有段落" 'grep -qx "<!-- rule: $FIRST_CORE -->" "$A" && grep -qx "<!-- rule: $OPT_A -->" "$A"'
check "規則數＝core＋1" '[ "$(grep -c "^<!-- rule: " "$A")" -eq $((CORE_COUNT + 1)) ]'
check "frontmatter 已去除" '! grep -qE "^(tier|category):" "$A"'

echo "▸ --agents-md：重跑換選項，只動區塊"
out="$("$INSTALL" --agents-md "$A" --select "$OPT_B")"
check "A 段落移除、B 段落新增" '! grep -qx "<!-- rule: $OPT_A -->" "$A" && grep -qx "<!-- rule: $OPT_B -->" "$A"'
check "輸出列出移除與新增" 'printf "%s" "$out" | grep -q "－ 移除 $OPT_A" && printf "%s" "$out" | grep -q "＋ 新增 $OPT_B"'
check "core 標示為不變" 'printf "%s" "$out" | grep -q "＝ 不變 $CORE_COUNT 個"'
check "只有一組區塊" '[ "$(grep -c "^<!-- agent-agreements:start" "$A")" -eq 1 ]'

echo "▸ --agents-md：區塊外的使用者內容逐位元組保留"
U="$TMP/agents-user"
mkdir -p "$U"
printf '# 我的專案\n\n自己的規則\n' > "$U/before.txt"
printf '\n## 結尾的自訂段落\n最後一行沒有換行' > "$U/after.txt"
cp "$U/before.txt" "$U/AGENTS.md"
"$INSTALL" --agents-md "$U/AGENTS.md" > /dev/null
check "附加時開頭保留原內容" 'head -c "$(wc -c < "$U/before.txt")" "$U/AGENTS.md" | cmp -s - "$U/before.txt"'
cat "$U/after.txt" >> "$U/AGENTS.md"
cp "$U/AGENTS.md" "$U/snapshot.md"
"$INSTALL" --agents-md "$U/AGENTS.md" --select "$OPT_A" > /dev/null
check "區塊後的內容（含無換行結尾）逐位元組保留" 'tail -c "$(wc -c < "$U/after.txt")" "$U/AGENTS.md" | cmp -s - "$U/after.txt"'
check "區塊前的內容逐位元組保留" 'head -c "$(wc -c < "$U/before.txt")" "$U/AGENTS.md" | cmp -s - "$U/before.txt"'
before_sha="$(sha "$U/AGENTS.md")"
"$INSTALL" --agents-md "$U/AGENTS.md" --select "$OPT_B" --dry-run > "$TMP/out-agents-dry2"
check "--dry-run 換選項也不改檔" '[ "$(sha "$U/AGENTS.md")" = "$before_sha" ] && grep -q "dry-run" "$TMP/out-agents-dry2"'

echo "▸ --agents-md --uninstall：只拿掉區塊"
printf '# 我的專案\n\n自己的規則\n' > "$U/plain.md"
cp "$U/plain.md" "$U/roundtrip.md"
"$INSTALL" --agents-md "$U/roundtrip.md" --select "$OPT_A" > /dev/null
cp "$U/roundtrip.md" "$U/roundtrip-installed.md"
"$INSTALL" --agents-md "$U/roundtrip.md" --uninstall --dry-run > /dev/null
check "uninstall --dry-run 不改檔" 'cmp -s "$U/roundtrip.md" "$U/roundtrip-installed.md"'
"$INSTALL" --agents-md "$U/roundtrip.md" --uninstall > /dev/null
check "附加→移除後與原檔逐位元組相同" 'cmp -s "$U/roundtrip.md" "$U/plain.md"'
"$INSTALL" --agents-md "$U/AGENTS.md" --uninstall > /dev/null
check "區塊被拿掉，前後內容仍在" '! grep -q "agent-agreements" "$U/AGENTS.md" && grep -q "自己的規則" "$U/AGENTS.md" && grep -q "結尾的自訂段落" "$U/AGENTS.md"'
"$INSTALL" --agents-md "$A" --uninstall > "$TMP/out-agents-empty"
check "只有區塊的檔案移除後留下空檔案" '[ -f "$A" ] && [ ! -s "$A" ] && grep -q "空檔案" "$TMP/out-agents-empty"'
out="$("$INSTALL" --agents-md "$U/plain.md" --uninstall)"
check "沒有區塊時不改檔" 'cmp -s "$U/plain.md" "$U/roundtrip.md" && printf "%s" "$out" | grep -q "沒有 agent-agreements 區塊"'

echo "▸ --agents-md：大小警告與參數錯誤"
W="$TMP/agents-warn/AGENTS.md"
AGENTS_MD_MAX_BYTES=100 "$INSTALL" --agents-md "$W" > /dev/null 2> "$TMP/err-warn"
check "超過門檻只警告、仍寫入" '[ -s "$W" ] && grep -q "⚠ 超過 100 bytes" "$TMP/err-warn"'
"$INSTALL" --agents-md "$TMP/agents-warn/ok.md" > /dev/null 2> "$TMP/err-nowarn"
check "預設門檻下不警告" '! grep -q "⚠" "$TMP/err-nowarn"'
printf '<!-- agent-agreements:start v0 -->\n沒有結束標記\n' > "$TMP/broken.md"
cp "$TMP/broken.md" "$TMP/broken-orig.md"
"$INSTALL" --agents-md "$TMP/broken.md" > /dev/null 2>&1
check "區塊不完整回傳 2 且不改檔" '[ $? -eq 2 ] && cmp -s "$TMP/broken.md" "$TMP/broken-orig.md"'
"$INSTALL" --agents-md "$TMP/x.md" --target "$TMP/x" > /dev/null 2>&1
check "--target 與 --agents-md 同時使用回傳 2" '[ $? -eq 2 ]'

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 $TMP"
[ "$fail" -eq 0 ]
