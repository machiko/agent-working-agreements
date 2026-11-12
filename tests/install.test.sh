#!/usr/bin/env bash
# install.test.sh — scripts/install.sh 的行為測試。只寫入 /tmp 底下的暫存目錄。
#
# 用法：tests/install.test.sh

set -uo pipefail
export PATH="/usr/bin:/bin:$PATH"

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

# 有 paths（按需載入）的第一個 optional
OPT_OD="$("$INSTALL" --list | awk -F'\t' '$2 == "optional" && $4 == "on-demand" { print $1; exit }')"

# 規則檔本文的第一個 # 標題
rule_title() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm && /^# / { sub(/^# /, ""); print; exit }' "$ROOT/rules/$1.md"
}
FIRST_CORE_TITLE="$(rule_title "$FIRST_CORE")"
OPT_A_TITLE="$(rule_title "$OPT_A")"
OPT_OD_TITLE="$(rule_title "$OPT_OD")"
# frontmatter paths 清單的第一個 glob
OPT_OD_GLOB="$(awk '/^paths:/ { on = 1; next } on && /^  - / { sub(/^  - /, ""); gsub(/"/, ""); print; exit }' "$ROOT/rules/$OPT_OD.md")"

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

echo "▸ --status 未安裝時提示尚未安裝且不寫入"
S="$TMP/status-none"
out="$("$INSTALL" --target "$S" --status)"; rc=$?
check "--target：exit 0" '[ "$rc" -eq 0 ]'
check "--target：印出尚未安裝" 'printf "%s" "$out" | grep -q "尚未安裝"'
check "--target：不建立目錄" '[ ! -e "$S" ]'
out="$("$INSTALL" --agents-md "$S-agents/AGENTS.md" --status)"; rc=$?
check "--agents-md 檔案不存在：exit 0 且印出尚未安裝" '[ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q "尚未安裝"'
check "--agents-md 檔案不存在：不建立檔案或目錄" '[ ! -e "$S-agents" ]'
cp "$U/plain.md" "$TMP/status-plain.md"
out="$("$INSTALL" --agents-md "$TMP/status-plain.md" --status)"; rc=$?
check "--agents-md 沒有區塊：exit 0 且印出尚未安裝" '[ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q "尚未安裝"'
check "--agents-md 沒有區塊：檔案不變" 'cmp -s "$TMP/status-plain.md" "$U/plain.md"'

echo "▸ --status 依 tier 分組列出標題與載入方式"
S="$TMP/status-list"
install_summary="$("$INSTALL" --target "$S" --select "$OPT_OD" | grep '^常駐：')"
# 讓安裝時的版本跟目前版本不同，才分得出 status 是否真的讀了 profile
sed 's/^version=.*/version=0.0.9/' "$S/.agreements-profile" > "$S/profile.tmp" && mv "$S/profile.tmp" "$S/.agreements-profile"
CUR_V="$(sed -n 's/.*"version"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$ROOT/.claude-plugin/plugin.json" | head -n 1)"
out="$("$INSTALL" --target "$S" --status)"; rc=$?
printf '%s\n' "$out" > "$TMP/out-status-list"
core_ln="$(grep -n '^core' "$TMP/out-status-list" | head -n 1 | cut -d: -f1)"
sel_ln="$(grep -n '^選擇的規則' "$TMP/out-status-list" | head -n 1 | cut -d: -f1)"
first_ln="$(grep -n -F "$FIRST_CORE — ${FIRST_CORE_TITLE}｜常駐｜最新" "$TMP/out-status-list" | head -n 1 | cut -d: -f1)"
od_ln="$(grep -n -F "$OPT_OD — ${OPT_OD_TITLE}｜按需載入（" "$TMP/out-status-list" | head -n 1 | cut -d: -f1)"
check "exit 0" '[ "$rc" -eq 0 ]'
check "有 core 與選擇的規則兩組，core 在前" '[ -n "$core_ln" ] && [ -n "$sel_ln" ] && [ "$core_ln" -lt "$sel_ln" ]'
check "core 規則列在 core 組，附標題、常駐與狀態" '[ -n "$first_ln" ] && [ "$first_ln" -gt "$core_ln" ] && [ "$first_ln" -lt "$sel_ln" ]'
check "按需載入的 optional 列在選擇的規則組" '[ -n "$od_ln" ] && [ "$od_ln" -gt "$sel_ln" ]'
check "按需載入列出觸發的 paths" 'grep -F "$OPT_OD — " "$TMP/out-status-list" | grep -qF "$OPT_OD_GLOB"'
check "最後一行是常駐、按需載入行數與規則總數" 'tail -n 1 "$TMP/out-status-list" | grep -qE "^常駐：[0-9]+ 行｜按需載入：[0-9]+ 行｜共 $((CORE_COUNT + 1)) 個規則$"'
check "行數與規則總數跟同一組選擇的安裝摘要一致" '[ -n "$install_summary" ] && [ "$(tail -n 1 "$TMP/out-status-list")" = "$install_summary" ]'
check "印出 profile 記錄的安裝版本與目前版本" 'grep -qxF "安裝版本：0.0.9｜目前版本：${CUR_V}" "$TMP/out-status-list"'

echo "▸ --status 讀出 AGENTS.md 區塊內的規則"
SA="$TMP/status-agents/AGENTS.md"
"$INSTALL" --agents-md "$SA" --select "$OPT_A" > /dev/null
before_sha="$(sha "$SA")"
out="$("$INSTALL" --agents-md "$SA" --status)"; rc=$?
printf '%s\n' "$out" > "$TMP/out-status-agents"
sel_ln="$(grep -n '^選擇的規則' "$TMP/out-status-agents" | head -n 1 | cut -d: -f1)"
a_ln="$(grep -n -F "$OPT_A — ${OPT_A_TITLE}｜" "$TMP/out-status-agents" | head -n 1 | cut -d: -f1)"
check "exit 0 且檔案不變" '[ "$rc" -eq 0 ] && [ "$(sha "$SA")" = "$before_sha" ]'
check "core 規則附標題並標最新" 'grep -qF "$FIRST_CORE — ${FIRST_CORE_TITLE}｜常駐｜最新" "$TMP/out-status-agents"'
check "optional A 列在選擇的規則組" '[ -n "$sel_ln" ] && [ -n "$a_ln" ] && [ "$a_ln" -gt "$sel_ln" ]'
check "最後一行是規則總數" 'tail -n 1 "$TMP/out-status-agents" | grep -q "共 $((CORE_COUNT + 1)) 個規則$"'
awk -v id="$OPT_A" '$0 == "<!-- rule: " id " -->" { print; print "舊版的一行"; next } { print }' "$SA" > "$SA.tmp" && mv "$SA.tmp" "$SA"
out="$("$INSTALL" --agents-md "$SA" --status)"
check "區塊內容與來源不同時標有新版" 'printf "%s" "$out" | grep -qF "$OPT_A — ${OPT_A_TITLE}｜常駐｜有新版"'
# 大區塊（超過管線緩衝）＋來源已移除又沒有標題的段落：放在最後，讀前面的段落時後面還有大量資料
SB="$TMP/status-agents-big/AGENTS.md"
"$INSTALL" --agents-md "$SB" --select "$OPT_A" > /dev/null
lines_before="$("$INSTALL" --agents-md "$SB" --status | tail -n 1 | sed 's/^常駐：\([0-9]*\) 行.*/\1/')"
awk '$0 == "<!-- agent-agreements:end -->" { print "<!-- rule: gone/rule -->"; for (i = 0; i < 3000; i++) print "填充內容，讓區塊超過管線緩衝區的大小 " i; print "" } { print }' "$SB" > "$SB.tmp" && mv "$SB.tmp" "$SB"
out="$("$INSTALL" --agents-md "$SB" --status 2> "$TMP/err-status-big")"; rc=$?
check "大區塊 exit 0 且沒有錯誤輸出" '[ "$rc" -eq 0 ] && [ ! -s "$TMP/err-status-big" ] && [ "$(wc -c < "$SB")" -gt 100000 ]'
check "沒有標題的已下架規則不錯位" 'printf "%s\n" "$out" | grep -qx "  gone/rule｜常駐｜來源已移除"'
check "大區塊的行數與規則總數正確" '[ "$(printf "%s\n" "$out" | tail -n 1)" = "常駐：$((lines_before + 3000)) 行｜按需載入：0 行｜共 $((CORE_COUNT + 2)) 個規則" ]'

echo "▸ --status 標出手動修改、有新版、檔案遺失且不寫入"
S="$TMP/status-drift"
"$INSTALL" --target "$S" > /dev/null
CORE_2="$(printf '%s\n' "$CORE_IDS" | sed -n 2p)"
CORE_3="$(printf '%s\n' "$CORE_IDS" | sed -n 3p)"
CORE_4="$(printf '%s\n' "$CORE_IDS" | sed -n 4p)"
echo "<!-- 手動加的 -->" >> "$S/$FIRST_CORE.md"
echo "<!-- 舊版內容 -->" >> "$S/$CORE_2.md"
old_sha="$(sha "$S/$CORE_2.md")"
sed "s#^file=$CORE_2 sha256=.*#file=$CORE_2 sha256=$old_sha#" "$S/.agreements-profile" > "$S/profile.tmp" && mv "$S/profile.tmp" "$S/.agreements-profile"
rm "$S/$CORE_3.md"
# 來源已下架、安裝檔也不在：沒有標題可讀
printf 'file=gone/rule sha256=0000\n' >> "$S/.agreements-profile"
snapshot() { find "$S" -type f | sort | while read -r f; do printf '%s %s\n' "$f" "$(sha "$f")"; done; }
before="$(snapshot)"
out="$("$INSTALL" --target "$S" --status 2> "$TMP/err-status-drift")"; rc=$?
check "exit 0 且沒有錯誤輸出" '[ "$rc" -eq 0 ] && [ ! -s "$TMP/err-status-drift" ]'
check "來源已下架又遺失的規則沒有標題也不錯位" 'printf "%s\n" "$out" | grep -qx "  gone/rule｜常駐｜檔案遺失"'
check "總數算進沒有標題的規則" 'printf "%s\n" "$out" | tail -n 1 | grep -q "共 $((CORE_COUNT + 1)) 個規則$"'
check "被改過的標已手動修改" 'printf "%s\n" "$out" | grep -F "$FIRST_CORE — " | grep -q "｜已手動修改$"'
check "記錄與來源不同的標有新版" 'printf "%s\n" "$out" | grep -F "$CORE_2 — " | grep -q "｜有新版$"'
check "被刪掉的標檔案遺失" 'printf "%s\n" "$out" | grep -F "$CORE_3 — " | grep -q "｜檔案遺失$"'
check "其他標最新" 'printf "%s\n" "$out" | grep -F "$CORE_4 — " | grep -q "｜最新$"'
check "profile 與規則檔的 sha 都不變" '[ "$(snapshot)" = "$before" ]'

echo "▸ 預覽輸出附上規則標題"
P="$TMP/preview-title"
out="$("$INSTALL" --target "$P" --select "$OPT_A" --dry-run)"
check "--target 新增行接標題" 'printf "%s" "$out" | grep -qF "＋ 新增 $OPT_A.md — $OPT_A_TITLE"'
"$INSTALL" --target "$P" --select "$OPT_A" > /dev/null
echo "改過" >> "$P/$FIRST_CORE.md"
out="$("$INSTALL" --target "$P" --dry-run)"
check "--target 保留行接標題" 'printf "%s" "$out" | grep -F "$FIRST_CORE.md — $FIRST_CORE_TITLE" | grep -q "^！ 保留"'
check "--target 移除行接標題" 'printf "%s" "$out" | grep -qF "－ 移除 $OPT_A.md — $OPT_A_TITLE"'
out="$("$INSTALL" --target "$P" --uninstall --dry-run)"
check "--target 移除時保留行接標題" 'printf "%s" "$out" | grep -qF "！ 保留（已被手動修改，加 --force 才移除）$FIRST_CORE.md — $FIRST_CORE_TITLE"'
check "--target 略過同名檔案行接標題" 'grep -qF "！ 略過（目標已有同名檔案且非本工具安裝，加 --force 才覆蓋）$FIRST_CORE.md — $FIRST_CORE_TITLE" "$TMP/out-foreign"'
out="$("$INSTALL" --agents-md "$SA" --select "$OPT_A" --dry-run)"
check "--agents-md 更新行接標題" 'printf "%s" "$out" | grep -qF "↻ 更新 $OPT_A — $OPT_A_TITLE"'
PA="$TMP/preview-title/AGENTS.md"
out="$("$INSTALL" --agents-md "$PA" --select "$OPT_A" --dry-run)"
check "--agents-md 新增行接標題" 'printf "%s" "$out" | grep -qF "＋ 新增 $OPT_A — $OPT_A_TITLE"'
"$INSTALL" --agents-md "$PA" --select "$OPT_A" > /dev/null
out="$("$INSTALL" --agents-md "$PA" --dry-run)"
check "--agents-md 移除行接標題" 'printf "%s" "$out" | grep -qF "－ 移除 $OPT_A — $OPT_A_TITLE"'

echo "▸ --status 參數錯誤"
"$INSTALL" --target "$TMP/x" --status --select "$OPT_A" > /dev/null 2>&1
check "--status 搭配 --select 回傳 2" '[ $? -eq 2 ]'
"$INSTALL" --target "$TMP/x" --status --uninstall > /dev/null 2>&1
check "--status 搭配 --uninstall 回傳 2" '[ $? -eq 2 ]'
"$INSTALL" --target "$TMP/x" --status --dry-run > /dev/null 2>&1
check "--status 搭配 --dry-run 回傳 2" '[ $? -eq 2 ]'
"$INSTALL" --target "$TMP/x" --force --status > /dev/null 2>&1
check "--status 搭配 --force 回傳 2" '[ $? -eq 2 ] && [ ! -e "$TMP/x" ]'

echo "▸ setup skill 涵蓋 --status、狀態參數與重複載入提醒"
SKILL="$ROOT/skills/setup/SKILL.md"
check "SKILL.md 用 --status 讀取現況" 'grep -qF -- "--status" "$SKILL"'
check "argument-hint 有「狀態」" 'grep -q "^argument-hint:.*狀態" "$SKILL"'
check "提醒兩個範圍會重複載入" 'grep -q "重複" "$SKILL"'
check "參數是「狀態」時只顯示現況、不進入問答" 'grep -q "參數是「狀態」.*不進入問答" "$SKILL"'
check "提問前列出 core 規則的標題" 'grep -q "列出 core 規則的標題" "$SKILL"'
check "套用後再跑一次 --status 收尾" 'grep -qF "套用完再執行一次 \`install.sh --status" "$SKILL"'
check "setup skill 包含 frontend/pitfalls" 'grep -q "frontend/pitfalls" "$SKILL"'
check "setup skill 包含 collaboration/sdlc-lifecycle" 'grep -q "collaboration/sdlc-lifecycle" "$SKILL"'
check "setup skill 包含智慧專案推薦引導" 'grep -q "智慧專案推薦" "$SKILL"'
check "setup skill 包含完整防禦套裝引導" 'grep -q "完整防禦套裝" "$SKILL"'
check "setup skill argument-hint 包含更新" 'grep -q "argument-hint:.*更新" "$SKILL"'
check "setup skill 包含維持現有規則一鍵更新引導" 'grep -q "維持現有規則並一鍵更新" "$SKILL"'
check "setup skill 包含遠端版本檢查機制" 'grep -q "releases/latest" "$SKILL"'

echo "▸ --update：沿用既有安裝設定一鍵更新"
T_UP="$TMP/update-fixture"
"$INSTALL" --target "$T_UP" --select "$OPT_A" > /dev/null
check "update 既有安裝存在" '[ -f "$T_UP/$OPT_A.md" ]'

# 模擬舊版檔案（修改檔案內容與 profile 中的 sha 使其成為舊版）
echo "/* outdated content */" > "$T_UP/$OPT_A.md"
outdated_sha="$(sha "$T_UP/$OPT_A.md")"
sed -i.bak "s#^file=$OPT_A sha256=.*#file=$OPT_A sha256=$outdated_sha#" "$T_UP/.agreements-profile"
rm -f "$T_UP/.agreements-profile.bak"

# 驗證 status 顯示有新版
out_stat="$("$INSTALL" --target "$T_UP" --status)"
check "status 辨識出有新版" 'printf "%s" "$out_stat" | grep -q "有新版"'

# 驗證 --update --dry-run
out_up_dry="$("$INSTALL" --target "$T_UP" --update --dry-run)"
check "update dry-run 輸出更新提示" 'printf "%s" "$out_up_dry" | grep -q "↻ 更新 $OPT_A.md"'
check "update dry-run 不實際覆寫" 'grep -q "outdated content" "$T_UP/$OPT_A.md"'

# 執行 --update
"$INSTALL" --target "$T_UP" --update > /dev/null
check "update 成功將規則還原至最新內容" '! grep -q "outdated content" "$T_UP/$OPT_A.md"'
out_stat_after="$("$INSTALL" --target "$T_UP" --status)"
check "update 後 status 全部為最新" '! printf "%s" "$out_stat_after" | grep -q "有新版"'

# 測試錯誤防護：未安裝目標不能 update
"$INSTALL" --target "$TMP/no-such-install" --update > /dev/null 2>&1
check "未安裝目錄執行 update 回傳非零" '[ $? -ne 0 ]'

# 測試錯誤防護：--update 不能搭配 --select
"$INSTALL" --target "$T_UP" --update --select "$OPT_B" > /dev/null 2>&1
check "update 搭配 --select 回傳非零" '[ $? -ne 0 ]'

# 測試 --agents-md --update
T_AG_UP="$TMP/agents-up.md"
"$INSTALL" --agents-md "$T_AG_UP" --select "$OPT_A" > /dev/null
sed -i.bak "s#rules/$OPT_A.md#outdated-marker#g" "$T_AG_UP" && rm -f "$T_AG_UP.bak"
"$INSTALL" --agents-md "$T_AG_UP" --update > /dev/null
check "agents-md update 成功更新區塊" 'grep -q "$OPT_A" "$T_AG_UP"'

echo "▸ --cursor：安裝為 Cursor .mdc 規則檔"
TC="$TMP/test-cursor"
"$INSTALL" --cursor "$TC" --select "$OPT_A" --dry-run > "$TMP/out-cursor-dry"
check "cursor dry-run 不寫檔" '[ ! -e "$TC" ]'
check "cursor dry-run 列出 .mdc 檔" 'grep -q "＋ 新增 $OPT_A.mdc" "$TMP/out-cursor-dry"'
"$INSTALL" --cursor "$TC" --select "$OPT_A" > /dev/null
check "cursor 安裝產出 .mdc 檔" '[ -f "$TC/$FIRST_CORE.mdc" ] && [ -f "$TC/$OPT_A.mdc" ]'
check "cursor core 檔標記 alwaysApply: true" 'grep -q "^alwaysApply: true$" "$TC/$FIRST_CORE.mdc"'
check "cursor optional 檔含 globs 與 alwaysApply: false" 'grep -q "^globs:" "$TC/$OPT_A.mdc" && grep -q "^alwaysApply: false$" "$TC/$OPT_A.mdc"'
fm_items() { awk 'NR == 1 { next } $0 == "---" { exit } /^[ ]+- / { n++ } END { print n + 0 }' "$1"; }
paths_items() { awk 'NR == 1 { next } $0 == "---" { exit } /^paths:/ { on = 1; next } on && /^[ ]+- / { n++; next } on { on = 0 } END { print n + 0 }' "$1"; }
check "cursor globs 只含 paths（incidents 等其他清單不混入）" '[ "$(fm_items "$TC/$OPT_A.mdc")" -eq "$(paths_items "$ROOT/rules/$OPT_A.md")" ]'
check "cursor profile 記錄 format=cursor" 'grep -q "^format=cursor$" "$TC/.agreements-profile"'
out="$("$INSTALL" --cursor "$TC" --status)"
check "cursor --status 正常輸出且顯示最新" 'printf "%s" "$out" | grep -q "最新"'
"$INSTALL" --cursor "$TC" --uninstall > /dev/null
check "cursor uninstall 清除所有 .mdc 與目錄" '[ ! -e "$TC" ]'
"$INSTALL" --cursor "$TMP/x" --target "$TMP/y" > /dev/null 2>&1
check "--cursor 與 --target 同時使用回傳 2" '[ $? -eq 2 ]'

echo "▸ --detect：智慧專案特徵偵測"
TD="$TMP/detect-fixture"
mkdir -p "$TD/migrations" "$TD/routes"
touch "$TD/Dockerfile" "$TD/schema.sql"
out="$("$INSTALL" --detect "$TD")"
check "detect 辨識出 database/pitfalls" 'printf "%s" "$out" | grep -q "^database/pitfalls"'
check "detect 辨識出 api/pitfalls" 'printf "%s" "$out" | grep -q "^api/pitfalls"'
check "detect 辨識出 container/pitfalls" 'printf "%s" "$out" | grep -q "^container/pitfalls"'
check "detect 不包含未匹配的 backend/pitfalls" '! printf "%s" "$out" | grep -q "^backend/pitfalls"'
"$INSTALL" --detect "$TMP/no-such-dir" > /dev/null 2>&1
check "detect 目錄不存在回傳 2" '[ $? -eq 2 ]'
"$INSTALL" --status --detect > /dev/null 2>&1
check "--status 搭配 --detect 回傳 2" '[ $? -eq 2 ]'

echo "▸ 別名相容對應 (vue -> frontend, docker -> container, laravel -> backend, data-scope -> tenant-isolation)"
T_ALIAS="$TMP/alias-fixture"
"$INSTALL" --target "$T_ALIAS" --select vue/pitfalls,docker/pitfalls,laravel/pitfalls,security/data-scope,security/tls-certificates --dry-run > "$TMP/out-alias"
check "vue/pitfalls 自動對應至 frontend/pitfalls" 'grep -q "frontend/pitfalls" "$TMP/out-alias"'
check "docker/pitfalls 自動對應至 container/pitfalls" 'grep -q "container/pitfalls" "$TMP/out-alias"'
check "laravel/pitfalls 自動對應至 backend/pitfalls" 'grep -q "backend/pitfalls" "$TMP/out-alias"'
check "security/data-scope 自動對應至 security/tenant-isolation" 'grep -q "security/tenant-isolation" "$TMP/out-alias"'
check "security/tls-certificates 自動對應至 container/pitfalls" 'grep -q "container/pitfalls" "$TMP/out-alias"'

echo "▸ --copilot：安裝 GitHub Copilot 指示"
T_COP="$TMP/copilot-fixture"
mkdir -p "$T_COP"
"$INSTALL" --copilot "$T_COP/.github/copilot-instructions.md" --select "$OPT_A" > /dev/null
check "copilot 檔案產出且含標記區塊" '[ -f "$T_COP/.github/copilot-instructions.md" ] && grep -q "<!-- agent-agreements:start" "$T_COP/.github/copilot-instructions.md"'

echo "▸ --windsurf：安裝 Windsurf 規則"
T_WIND="$TMP/windsurf-fixture"
mkdir -p "$T_WIND"
"$INSTALL" --windsurf "$T_WIND/.windsurfrules" --select "$OPT_A" > /dev/null
check "windsurf 檔案產出且含標記區塊" '[ -f "$T_WIND/.windsurfrules" ] && grep -q "<!-- agent-agreements:start" "$T_WIND/.windsurfrules"'

echo "▸ --ci：安裝 GitHub Actions CI 守門工作流"
T_CI="$TMP/ci-fixture"
mkdir -p "$T_CI"
"$INSTALL" --ci "$T_CI" --dry-run > "$TMP/out-ci-dry"
check "ci dry-run 不寫入檔案" '[ ! -f "$T_CI/.github/workflows/agent-audit.yml" ]'
check "ci dry-run 列出新增工作流" 'grep -q "agent-audit.yml" "$TMP/out-ci-dry"'
"$INSTALL" --ci "$T_CI" > /dev/null
check "ci 產出 GitHub Actions 工作流檔" '[ -f "$T_CI/.github/workflows/agent-audit.yml" ]'
check "ci 複製 audit.sh 且具備執行權限" '[ -x "$T_CI/scripts/audit.sh" ]'

echo "▸ --detect：雲原生與可觀測性特徵"
mkdir -p "$TD/k8s"
out_cloud="$("$INSTALL" --detect "$TD")"
check "detect 辨識出 cloud/pitfalls" 'printf "%s" "$out_cloud" | grep -q "^cloud/pitfalls"'

echo "▸ --detect：自動化測試特徵"
mkdir -p "$TD/tests"
out_test="$("$INSTALL" --detect "$TD")"
check "detect 辨識出 testing/pitfalls" 'printf "%s" "$out_test" | grep -q "^testing/pitfalls"'

echo "▸ --detect：AI 與 LLM 應用特徵"
mkdir -p "$TD/openai-pkg"
echo '{"dependencies":{"openai":"^4.0.0"}}' > "$TD/openai-pkg/package.json"
out_ai="$("$INSTALL" --detect "$TD/openai-pkg")"
check "detect 辨識出 ai/pitfalls" 'printf "%s" "$out_ai" | grep -q "^ai/pitfalls"'

echo "▸ --ci 多平台：GitLab CI、Bitbucket Pipelines 與 pre-commit"
T_CI_GL="$TMP/ci-gl"
mkdir -p "$T_CI_GL"
"$INSTALL" --ci gitlab "$T_CI_GL" > /dev/null
check "ci gitlab 產出 .gitlab-ci.yml" '[ -f "$T_CI_GL/.gitlab-ci.yml" ] && grep -q "agent-audit" "$T_CI_GL/.gitlab-ci.yml"'
check "ci gitlab 複製 audit.sh 且具執行權限" '[ -x "$T_CI_GL/scripts/audit.sh" ]'

T_CI_BB="$TMP/ci-bb"
mkdir -p "$T_CI_BB"
"$INSTALL" --ci bitbucket "$T_CI_BB" > /dev/null
check "ci bitbucket 產出 bitbucket-pipelines.yml" '[ -f "$T_CI_BB/bitbucket-pipelines.yml" ] && grep -q "Agent Agreements Guardrail Audit" "$T_CI_BB/bitbucket-pipelines.yml"'

T_CI_PC="$TMP/ci-pc"
mkdir -p "$T_CI_PC"
"$INSTALL" --ci pre-commit "$T_CI_PC" > /dev/null
check "ci pre-commit 產出 .pre-commit-config.yaml" '[ -f "$T_CI_PC/.pre-commit-config.yaml" ] && grep -q "agent-agreements-audit" "$T_CI_PC/.pre-commit-config.yaml"'

echo "▸ collaboration/sdlc-lifecycle：安裝軟體生命週期規範"
T_SDLC="$TMP/sdlc-fixture"
"$INSTALL" --target "$T_SDLC" --select collaboration/sdlc-lifecycle > /dev/null
check "sdlc-lifecycle 檔案產出且存在" '[ -f "$T_SDLC/collaboration/sdlc-lifecycle.md" ]'
check "sdlc-lifecycle profile 記錄" 'grep -q "^file=collaboration/sdlc-lifecycle" "$T_SDLC/.agreements-profile"'
out_sdlc_stat="$("$INSTALL" --target "$T_SDLC" --status)"
check "sdlc-lifecycle status 正確標示標題" 'printf "%s" "$out_sdlc_stat" | grep -q "軟體開發生命週期"'

echo "▸ collaboration/communication：包含命中守則顯式標註規範"
check "core 安裝後 communication.md 含命中守則標註" 'grep -q "🛡️ 命中守則：" "$T_SDLC/collaboration/communication.md"'
check "templates/CLAUDE.md 含命中守則標註" 'grep -q "🛡️ 命中守則：" "$ROOT/templates/CLAUDE.md"'

echo "▸ Schema v1 與團隊策略檔 (.agreements.json)"
T_SCHEMA="$TMP/schema-fixture"
"$INSTALL" --target "$T_SCHEMA" > /dev/null
check "profile 寫入 schema_version=1" 'grep -q "^schema_version=1" "$T_SCHEMA/.agreements-profile"'

out_schema_status="$("$INSTALL" --target "$T_SCHEMA" --status)"
check "status 標註 Schema v1" 'printf "%s" "$out_schema_status" | grep -q "Schema v1"'

# 舊版 profile (無 schema_version) 遷移測試
T_LEGACY="$TMP/legacy-fixture"
mkdir -p "$T_LEGACY/collaboration"
cp "$ROOT/rules/collaboration/git-safety.md" "$T_LEGACY/collaboration/"
c_sha="$(sha "$T_LEGACY/collaboration/git-safety.md")"
cat <<EOF > "$T_LEGACY/.agreements-profile"
# legacy
version=0.9.0
selected=
file=collaboration/git-safety sha256=$c_sha
EOF
out_leg_stat="$("$INSTALL" --target "$T_LEGACY" --status)"
check "legacy profile 讀取時不報錯" '[ -n "$out_leg_stat" ]'

# 執行 update 後升級至 schema_version=1
"$INSTALL" --target "$T_LEGACY" --update > /dev/null
check "update 後升級為 schema_version=1" 'grep -q "^schema_version=1" "$T_LEGACY/.agreements-profile"'

# 團隊策略檔讀取測試
T_POLICY="$TMP/policy-fixture"
mkdir -p "$T_POLICY"
cat <<'EOF' > "$T_POLICY/.agreements.json"
{
  "enforce_rules": ["security/tenant-isolation", "security/supply-chain"]
}
EOF
"$INSTALL" --target "$T_POLICY" > /dev/null
check "依團隊策略強制安裝 tenant-isolation" '[ -f "$T_POLICY/security/tenant-isolation.md" ]'
check "依團隊策略強制安裝 supply-chain" '[ -f "$T_POLICY/security/supply-chain.md" ]'
check "profile 記錄 policy 檔名" 'grep -q "^policy=.agreements.json" "$T_POLICY/.agreements-profile"'

# Monorepo 向上尋找根目錄策略檔測試
T_MONO="$TMP/monorepo-fixture"
mkdir -p "$T_MONO/packages/backend"
cat <<'EOF' > "$T_MONO/.agreements.json"
{
  "enforce_rules": ["security/tenant-isolation"]
}
EOF
"$INSTALL" --target "$T_MONO/packages/backend" > /dev/null
check "Monorepo 子目錄向上找到根目錄策略檔並安裝 tenant-isolation" '[ -f "$T_MONO/packages/backend/security/tenant-isolation.md" ]'
check "Monorepo 子目錄 profile 記錄根目錄 policy" 'grep -q "^policy=.agreements.json" "$T_MONO/packages/backend/.agreements-profile"'

# 策略檔 preset=full 與 preset=smart 測試
T_PRESET_FULL="$TMP/preset-full-fixture"
mkdir -p "$T_PRESET_FULL"
cat <<'EOF' > "$T_PRESET_FULL/.agreements.json"
{
  "preset": "full",
  "enforce_rules": ["security/tenant-isolation"]
}
EOF
"$INSTALL" --target "$T_PRESET_FULL" > /dev/null
check "preset=full 自動安裝所有 optional 規則 (例如 database/pitfalls)" '[ -f "$T_PRESET_FULL/database/pitfalls.md" ]'
check "preset=full 包含 frontend/pitfalls" '[ -f "$T_PRESET_FULL/frontend/pitfalls.md" ]'
check "preset=full 包含 enforce_rules" '[ -f "$T_PRESET_FULL/security/tenant-isolation.md" ]'

T_PRESET_SMART="$TMP/preset-smart-fixture"
mkdir -p "$T_PRESET_SMART"
echo '{"dependencies": {"react": "^18.0.0"}}' > "$T_PRESET_SMART/package.json"
cat <<'EOF' > "$T_PRESET_SMART/.agreements.json"
{
  "preset": "smart"
}
EOF
"$INSTALL" --target "$T_PRESET_SMART" > /dev/null
check "preset=smart 依專案特徵自動安裝 frontend/pitfalls" '[ -f "$T_PRESET_SMART/frontend/pitfalls.md" ]'

# 首次安裝到還不存在的目錄：仍要找到上層的策略檔
T_FRESH="$TMP/fresh-proj"
mkdir -p "$T_FRESH"
cat <<'EOF' > "$T_FRESH/.agreements.json"
{ "enforce_rules": ["security/tenant-isolation"] }
EOF
(cd "$TMP" && "$INSTALL" --target "$T_FRESH/.claude/rules/agent-agreements" > /dev/null)
check "目標目錄還不存在時仍套用上層策略檔" '[ -f "$T_FRESH/.claude/rules/agent-agreements/security/tenant-isolation.md" ]'

# v0 → v1 遷移：選項與檔案記錄要保留
T_MIGRATE="$TMP/migrate-fixture"
mkdir -p "$T_MIGRATE/collaboration" "$T_MIGRATE/writing"
cp "$ROOT/rules/collaboration/git-safety.md" "$T_MIGRATE/collaboration/"
cp "$ROOT/rules/writing/changelog.md" "$T_MIGRATE/writing/"
cat <<EOF > "$T_MIGRATE/.agreements-profile"
# legacy
version=0.9.0
selected=writing/changelog
file=collaboration/git-safety sha256=$(sha "$T_MIGRATE/collaboration/git-safety.md")
file=writing/changelog sha256=$(sha "$T_MIGRATE/writing/changelog.md")
EOF
"$INSTALL" --target "$T_MIGRATE" --update > /dev/null
check "遷移後保留 selected 選項" 'grep -q "^selected=.*writing/changelog" "$T_MIGRATE/.agreements-profile"'
check "遷移後保留選擇的規則檔記錄與雜湊" 'grep -qE "^file=writing/changelog sha256=[0-9a-f]{64}" "$T_MIGRATE/.agreements-profile"'
check "遷移後 core 規則記錄附雜湊" 'grep -qE "^file=collaboration/git-safety sha256=[0-9a-f]{64}" "$T_MIGRATE/.agreements-profile"'

echo "▸ 錯誤訊息：變數後面緊接全形標點"
# UTF-8 locale 下，bash 會把 $var 後面的全形字元當成變數名稱的一部分，觸發 unbound variable
out_lang="$(LC_ALL=en_US.UTF-8 bash "$INSTALL" --lang fr 2>&1)"
check "--lang 不支援的語言時印出可用語言" 'printf "%s" "$out_lang" | grep -q "不支援的語言：fr（可用："'
unbraced="$(cd "$ROOT" && perl -ne 'print "$ARGV:$.\n" if /\$[A-Za-z_][A-Za-z0-9_]*[^\x00-\x7f]/ && !/^\s*#/; close ARGV if eof' scripts/*.sh scripts/lib/*.sh tests/*.sh evals/lib/*.sh)"
check "腳本裡 \$var 後面緊接非 ASCII 字元時都加了大括號" '[ -z "$unbraced" ]' || printf '%s\n' "$unbraced" >&2

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 $TMP"
[ "$fail" -eq 0 ]
