#!/usr/bin/env bash
# i18n.test.sh — 守則翻譯同步檢查（check-i18n.sh）與 install.sh --lang 的測試。
# 在 /tmp 底下複製 repo 或安裝到暫存目錄，不改動本 repo。
#
# 用法：tests/i18n.test.sh

set -uo pipefail
export PATH="/usr/bin:/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/aw-i18n-test.XXXXXX)"
export HOME="$TMP/home"   # 避免讀到使用者全域安裝的守則
mkdir -p "$HOME"
INSTALL="$ROOT/scripts/install.sh"
EN_HONESTY_TITLE="$(sed -n 's/^# //p' "$ROOT/i18n/en/rules/collaboration/honesty.md" | head -n 1)"

pass=0
fail=0

ok()    { echo "  ✓ $1"; pass=$((pass + 1)); }
bad()   { echo "  ✗ $1" >&2; fail=$((fail + 1)); }
has()   { if grep -qF -- "$2" "$TMP/out"; then ok "$1"; else bad "$1（輸出沒有「$2」）"; sed 's/^/      /' "$TMP/out" >&2; fi; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# fresh <名稱>：複製 check-i18n.sh 需要的檔案，印出路徑
fresh() {
  mkdir -p "$TMP/$1"
  cp -R "$ROOT/scripts" "$ROOT/rules" "$ROOT/i18n" "$TMP/$1/"
  echo "$TMP/$1"
}

# expect_fail <說明> <repo> <訊息片段>
expect_fail() {
  if ROOT="$2" "$2/scripts/check-i18n.sh" > "$TMP/out" 2>&1; then
    bad "$1（應失敗）"
  elif grep -qF -- "$3" "$TMP/out"; then
    ok "$1"
  else
    bad "$1（訊息沒有「$3」）"; sed 's/^/      /' "$TMP/out" >&2
  fi
}

EN=i18n/en/rules/collaboration/honesty.md

echo "▸ check-i18n.sh"
if ROOT="$ROOT" "$ROOT/scripts/check-i18n.sh" > "$TMP/out" 2>&1; then ok "目前的翻譯全部同步"; else bad "目前的翻譯應同步"; cat "$TMP/out" >&2; fi

R="$(fresh zh-changed)"
printf '\n- 新增一行。\n' >> "$R/rules/collaboration/honesty.md"
expect_fail "中文改了、翻譯沒跟上時失敗" "$R" "source_sha256 不符"
has "提示 --stamp 指令" "--stamp en collaboration/honesty"

R="$(fresh missing)"
rm "$R/$EN"
expect_fail "缺翻譯時失敗" "$R" "缺少 collaboration/honesty"

R="$(fresh orphan)"
mkdir -p "$R/i18n/en/rules/legacy" && cp "$R/$EN" "$R/i18n/en/rules/legacy/x.md"
expect_fail "多出沒有中文的翻譯時失敗" "$R" "legacy/x 沒有對應的中文守則"

R="$(fresh tier)"
sed -i.bak 's/^tier: core$/tier: optional/' "$R/$EN"
expect_fail "結構欄位不同時失敗" "$R" "「tier」要與中文相同"

R="$(fresh lines)"
awk '!done && /^- / { done = 1; next } { print }' "$R/$EN" > "$R/x" && mv "$R/x" "$R/$EN"
expect_fail "行數不同時失敗" "$R" "翻譯要逐行對照"

R="$(fresh label)"
sed -i.bak 's/^\*\*Why:\*\*/**Reason:**/' "$R/$EN"
expect_fail "段落標籤沒對應時失敗" "$R" "**Why:**"

R="$(fresh marker)"
sed -i.bak 's/ <!-- 慣例 -->//' "$R/$EN"
expect_fail "標註沒保留時失敗" "$R" "<!-- 慣例 -->"

R="$(fresh stamp)"
printf '\n- 新增一行。\n' >> "$R/rules/collaboration/honesty.md"
printf '\n- Added a line.\n' >> "$R/$EN"
ROOT="$R" "$R/scripts/check-i18n.sh" --stamp en collaboration/honesty > /dev/null 2>&1
check "--stamp 更新雜湊後通過" 'ROOT="$R" "$R/scripts/check-i18n.sh" > /dev/null 2>&1'

R="$(fresh no-rules-dir)"
mkdir -p "$R/i18n/ja"
expect_fail "語言目錄沒有 rules/ 時失敗" "$R" "缺少 i18n/ja/rules/"
check "--stamp 拒絕不合法的 id" '! ROOT="$R" "$R/scripts/check-i18n.sh" --stamp en ../x > /dev/null 2>&1'

echo "▸ install.sh --lang"
"$INSTALL" --lang fr --list > "$TMP/out" 2>&1 && bad "不支援的語言應失敗" || ok "不支援的語言失敗"
"$INSTALL" --lang en --list > "$TMP/out" 2>&1
lbl="$(sed -n 's/^label: "\(.*\)"$/\1/p' "$ROOT/i18n/en/rules/database/pitfalls.md")"
has "--list 顯示英文選項名稱" "$lbl"

T="$TMP/en/.claude/rules/agent-agreements"
"$INSTALL" --target "$T" --lang en --select database/pitfalls > /dev/null 2>&1
check "安裝英文守則" 'grep -qxF "# $EN_HONESTY_TITLE" "$T/collaboration/honesty.md"'
check "profile 記錄語言" 'grep -qx "lang=en" "$T/.agreements-profile"'
"$INSTALL" --target "$T" --status > "$TMP/out" 2>&1
has "--status 顯示語言" "守則語言：en"
check "--status 與英文來源比對為最新" '! grep -q "有新版" "$TMP/out"'
"$INSTALL" --target "$T" --update > /dev/null 2>&1
check "--update 沿用英文" 'grep -qxF "# $EN_HONESTY_TITLE" "$T/collaboration/honesty.md" && grep -qx "lang=en" "$T/.agreements-profile"'
"$INSTALL" --target "$T" --status --lang zh-TW > /dev/null 2>&1 && bad "--status 不該接受 --lang" || ok "--status 拒絕 --lang"
printf '\n<!-- 手動修改 -->\n' >> "$T/collaboration/verification.md"
"$INSTALL" --target "$T" --lang zh-TW > "$TMP/out" 2>&1
check "--lang zh-TW 切回中文" 'grep -qx "# 誠實回報：只回報真的發生過的事" "$T/collaboration/honesty.md" && grep -qx "lang=zh-TW" "$T/.agreements-profile"'
has "切換語言時警告保留原語言的檔案" "保留原語言"

T="$TMP/legacy/.claude/rules/agent-agreements"
"$INSTALL" --target "$T" > /dev/null 2>&1
sed -i.bak '/^lang=/d' "$T/.agreements-profile"
"$INSTALL" --target "$T" --update > /dev/null 2>&1
check "沒記錄語言的舊安裝視為中文" 'grep -qx "# 誠實回報：只回報真的發生過的事" "$T/collaboration/honesty.md"'

echo "▸ 策略檔 lang"
P="$TMP/proj-policy"; mkdir -p "$P"; (cd "$P" && git init -q)
printf '{ "version": "1.0", "preset": "core", "lang": "en" }\n' > "$P/.agreements.json"
"$INSTALL" --target "$P/.claude/rules/agent-agreements" > "$TMP/out" 2>&1
check "依策略檔安裝英文" 'grep -qxF "# $EN_HONESTY_TITLE" "$P/.claude/rules/agent-agreements/collaboration/honesty.md"'
has "提示依策略檔切換語言" "使用守則語言：en"
"$INSTALL" --target "$P/.claude/rules/agent-agreements" --lang zh-TW > /dev/null 2>&1
check "--lang 優先於策略檔" 'grep -qx "lang=zh-TW" "$P/.claude/rules/agent-agreements/.agreements-profile"'
"$ROOT/scripts/doctor.sh" --check-drift "$P" > "$TMP/out" 2>&1 && bad "安裝語言與策略檔不符應判為漂移" || ok "安裝語言與策略檔不符判為漂移"
has "說明語言漂移" "守則語言應為 en"
check "策略檔 lang 符合 schema" '"$ROOT/scripts/check-schema.sh" "$P/.agreements.json" > /dev/null 2>&1'
printf '{ "lang": "fr" }\n' > "$TMP/bad-policy.json"
check "schema 拒絕不支援的語言" '! "$ROOT/scripts/check-schema.sh" "$TMP/bad-policy.json" > /dev/null 2>&1'

echo "▸ AGENTS.md 標記區塊"
A="$TMP/agents/AGENTS.md"; mkdir -p "$(dirname "$A")"
"$INSTALL" --agents-md "$A" --lang en > /dev/null 2>&1
check "區塊記錄語言" 'grep -qx "<!-- agent-agreements:lang=en -->" "$A"'
check "區塊內容是英文" 'grep -qxF "# $EN_HONESTY_TITLE" "$A"'
"$INSTALL" --agents-md "$A" --update > /dev/null 2>&1
check "--update 沿用英文" 'grep -qx "<!-- agent-agreements:lang=en -->" "$A" && grep -qxF "# $EN_HONESTY_TITLE" "$A"'
"$INSTALL" --agents-md "$A" --status > "$TMP/out" 2>&1
has "--status 顯示語言" "守則語言：en"
{ echo "<!-- agent-agreements:lang=zh-TW -->"; cat "$A"; } > "$A.tmp" && mv "$A.tmp" "$A"
"$INSTALL" --agents-md "$A" --status > "$TMP/out" 2>&1
has "只讀標記區塊內的語言" "守則語言：en"

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 ${TMP}"
[ "$fail" -eq 0 ]
