#!/usr/bin/env bash
# deprecation.test.sh — 守則淘汰機制（deprecated、replaced_by）與審查期限提示的測試。
# 在 /tmp 底下複製一份 repo，加入淘汰的守則後執行，不改動本 repo。
#
# 用法：tests/deprecation.test.sh

set -uo pipefail
export PATH="/usr/bin:/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/aw-deprecation-test.XXXXXX)"
export HOME="$TMP/home"   # 避免讀到使用者全域安裝的守則
mkdir -p "$HOME"

pass=0
fail=0

ok()   { echo "  ✓ $1"; pass=$((pass + 1)); }
bad()  { echo "  ✗ $1" >&2; fail=$((fail + 1)); }
has()  { if grep -qF -- "$2" "$TMP/out"; then ok "$1"; else bad "$1（輸出沒有「$2」）"; sed 's/^/      /' "$TMP/out" >&2; fi; }
hasnt() { if grep -qF -- "$2" "$TMP/out"; then bad "$1（輸出不該有「$2」）"; sed 's/^/      /' "$TMP/out" >&2; else ok "$1"; fi; }

# copy_repo <目錄>：複製執行所需的檔案
copy_repo() {
  mkdir -p "$1"
  cp -R "$ROOT/scripts" "$ROOT/rules" "$ROOT/schema" "$ROOT/templates" "$ROOT/.claude-plugin" "$1/"
}

# add_rule <repo> <id> <tier> <額外 frontmatter>
add_rule() {
  mkdir -p "$(dirname "$1/rules/$2.md")"
  printf -- '---\ncategory: %s\ntier: %s\nlabel: "舊守則"\nincidents:\n  - "測試用"\nlast_reviewed: %s\n%s---\n\n# 舊守則\n\n## 舊條目\n\n**為什麼：** 測試用。\n' \
    "$(dirname "$2")" "$3" "$(date +%F)" "$4" > "$1/rules/$2.md"
}

R="$TMP/repo"
copy_repo "$R"
add_rule "$R" legacy/pitfalls optional $'deprecated: "已併入 database/pitfalls"\nreplaced_by: database/pitfalls\n'

echo "▸ check-budget.sh：淘汰欄位"
ROOT="$R" "$R/scripts/check-budget.sh" > "$TMP/out" 2>&1 && ok "合法的淘汰守則通過" || { bad "合法的淘汰守則應通過"; cat "$TMP/out" >&2; }

B="$TMP/bad-core"; copy_repo "$B"
add_rule "$B" legacy/core core $'deprecated: "不再需要"\n'
ROOT="$B" "$B/scripts/check-budget.sh" > "$TMP/out" 2>&1 && bad "core 守則不可淘汰" || ok "core 守則淘汰時失敗"
has "指出要先改成 optional" "不可直接淘汰"

B="$TMP/bad-replace"; copy_repo "$B"
add_rule "$B" legacy/pitfalls optional $'deprecated: "改用別的"\nreplaced_by: no/such-rule\n'
ROOT="$B" "$B/scripts/check-budget.sh" > "$TMP/out" 2>&1 && bad "replaced_by 指向不存在的守則應失敗" || ok "replaced_by 不存在時失敗"
has "指出 replaced_by" "replaced_by"

B="$TMP/bad-empty"; copy_repo "$B"
add_rule "$B" legacy/pitfalls optional $'deprecated: ""\n'
ROOT="$B" "$B/scripts/check-budget.sh" > "$TMP/out" 2>&1 && bad "deprecated 空字串應失敗" || ok "deprecated 沒寫原因時失敗"
has "指出要寫原因" "淘汰原因"

B="$TMP/bad-self"; copy_repo "$B"
add_rule "$B" legacy/pitfalls optional $'deprecated: "自己取代自己"\nreplaced_by: legacy/pitfalls\n'
ROOT="$B" "$B/scripts/check-budget.sh" > "$TMP/out" 2>&1 && bad "replaced_by 指向自己應失敗" || ok "replaced_by 指向自己時失敗"
has "要求未淘汰的替代守則" "未淘汰"

B="$TMP/bad-orphan"; copy_repo "$B"
add_rule "$B" legacy/pitfalls optional $'replaced_by: database/pitfalls\n'
ROOT="$B" "$B/scripts/check-budget.sh" > "$TMP/out" 2>&1 && bad "只寫 replaced_by 應失敗" || ok "沒有 deprecated 只寫 replaced_by 時失敗"
has "指出要一起寫" "只能跟 deprecated 一起寫"

echo "▸ install.sh --list：第 8 欄標示淘汰"
"$R/scripts/install.sh" --list > "$TMP/out"
awk -F'\t' '$1 == "legacy/pitfalls" { print $8 }' "$TMP/out" | grep -q "deprecated" && ok "淘汰守則標 deprecated" || bad "淘汰守則沒有標示"
awk -F'\t' '$1 == "database/pitfalls" { print $8 }' "$TMP/out" | grep -qx -- "-" && ok "一般守則標 -" || bad "一般守則第 8 欄應為 -"
awk -F'\t' '$1 == "legacy/pitfalls" { print $9 }' "$TMP/out" | grep -qx "database/pitfalls" && ok "第 9 欄是替代守則" || bad "第 9 欄應為 database/pitfalls"

echo "▸ install.sh --select 淘汰守則：照裝但警告"
"$R/scripts/install.sh" --target "$TMP/sel" --select legacy/pitfalls > "$TMP/out" 2>&1
[ -f "$TMP/sel/legacy/pitfalls.md" ] && ok "仍然安裝" || bad "明確指定時應安裝"
has "警告已淘汰" "已淘汰"
has "提示替代守則" "改用 database/pitfalls"

echo "▸ 策略檔 preset: full 略過淘汰守則"
P="$TMP/proj-full"; mkdir -p "$P"; (cd "$P" && git init -q)
printf '{ "version": "1.0", "preset": "full" }\n' > "$P/.agreements.json"
"$R/scripts/install.sh" --target "$P/.claude/rules/agent-agreements" > "$TMP/out" 2>&1
[ -f "$P/.claude/rules/agent-agreements/database/pitfalls.md" ] && ok "full 安裝一般 optional 守則" || bad "full 應安裝 database/pitfalls"
[ ! -e "$P/.claude/rules/agent-agreements/legacy/pitfalls.md" ] && ok "full 不安裝淘汰守則" || bad "full 不該安裝淘汰守則"

echo "▸ --detect 不推薦淘汰守則"
D="$TMP/deprecated-db"; copy_repo "$D"
printf 'deprecated: "測試用淘汰"\n' > "$TMP/fm"
awk -v add="$(cat "$TMP/fm")" 'NR > 1 && $0 == "---" && !done { print add; done = 1 } { print }' "$D/rules/database/pitfalls.md" > "$TMP/db.md" && mv "$TMP/db.md" "$D/rules/database/pitfalls.md"
mkdir -p "$TMP/detect/migrations"
"$D/scripts/install.sh" --detect "$TMP/detect" > "$TMP/out" 2>&1
hasnt "沒有推薦 database/pitfalls" "database/pitfalls"
"$R/scripts/install.sh" --detect "$TMP/detect" > "$TMP/out" 2>&1
has "未淘汰時照常推薦" "database/pitfalls"

echo "▸ doctor.sh：提示已安裝的淘汰守則與過期審查"
P="$TMP/proj-doc"; mkdir -p "$P"; (cd "$P" && git init -q)
"$R/scripts/install.sh" --target "$P/.claude/rules/agent-agreements" --select legacy/pitfalls,database/pitfalls > /dev/null 2>&1
AGREEMENTS_REVIEW_MAX_YEARS=100 "$R/scripts/doctor.sh" "$P" > "$TMP/out" 2>&1
has "提示淘汰守則" "legacy/pitfalls"
has "提示替代守則" "改用 database/pitfalls"
hasnt "審查日期未過期時不提示" "超過"
score_with="$(sed -n 's/.*體檢評分：\([0-9][0-9]*\).*/\1/p' "$TMP/out" | head -n 1)"
P2="$TMP/proj-doc2"; mkdir -p "$P2"; (cd "$P2" && git init -q)
"$R/scripts/install.sh" --target "$P2/.claude/rules/agent-agreements" --select database/pitfalls > /dev/null 2>&1
AGREEMENTS_REVIEW_MAX_YEARS=100 "$R/scripts/doctor.sh" "$P2" > "$TMP/out" 2>&1
score_without="$(sed -n 's/.*體檢評分：\([0-9][0-9]*\).*/\1/p' "$TMP/out" | head -n 1)"
[ -n "$score_with" ] && [ "$((score_without - score_with))" -eq 5 ] && ok "淘汰守則扣 5 分" || bad "淘汰守則應扣 5 分（${score_without:-?} → ${score_with:-?}）"

S="$TMP/stale"; copy_repo "$S"
sed -i.bak 's/^last_reviewed: .*/last_reviewed: 2020-01-01/' "$S/rules/database/pitfalls.md" && rm "$S/rules/database/pitfalls.md.bak"
P="$TMP/proj-stale"; mkdir -p "$P"; (cd "$P" && git init -q)
"$S/scripts/install.sh" --target "$P/.claude/rules/agent-agreements" --select database/pitfalls > /dev/null 2>&1
"$S/scripts/doctor.sh" "$P" > "$TMP/out" 2>&1
has "提示審查過期的守則" "database/pitfalls"
has "說明期限" "超過"

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 ${TMP}"
[ "$fail" -eq 0 ]
