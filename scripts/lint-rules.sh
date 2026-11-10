#!/usr/bin/env bash
# lint-rules.sh — 依 docs/rule-quality.md 檢查守則本文的結構與用語。
#
# 用法：scripts/lint-rules.sh
#   ROOT=<目錄>            改檢查其他目錄的 rules/（測試用）
#   MAX_ENTRY_LINES=<n>   單一條目本文行數上限（預設 40）
#
# 檢查項目（條目＝每個 `##` 標題；檔案沒有 `##` 時改用 `###`）：
#   1. 有「**症狀**」的條目，必須同時有「**根因**」與「**怎麼做**」
#   2. 每個條目要有事故依據（「**為什麼**」或「**根因**」）；
#      沒有事故依據的條目要在標題標 `<!-- 慣例 -->`（團隊偏好）或 `<!-- 參考 -->`（對照表、格式、清單）
#   3. 不用沒有可驗證動作的空泛用語（盡量、適當、視情況……）；「」引號、行內程式碼與程式碼區塊內不算
#   4. 條目標題不可跨檔重複（忽略編號與標註）
#   5. 條目本文不超過 MAX_ENTRY_LINES 行
#
# 結束碼：0 通過；1 有違規。

set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MAX_ENTRY_LINES="${MAX_ENTRY_LINES:-40}"
VAGUE='盡量|儘量|盡可能|儘可能|適當|視情況|多加注意'

files=()
while IFS= read -r f; do files+=("$f"); done < <(find "$ROOT/rules" -type f -name '*.md' | sort)
[ "${#files[@]}" -gt 0 ] || { echo "✗ ${ROOT}/rules 底下沒有規則檔" >&2; exit 1; }

awk -v root="$ROOT/" -v max="$MAX_ENTRY_LINES" -v vague="$VAGUE" '
function err(line, msg) { printf "✗ %s:%d：%s\n", rel, line, msg > "/dev/stderr"; errors++ }

# 去掉「…」引號內文與 `…` 行內程式碼（逐字元處理，避免 awk 以位元組比對多位元組字元）
function strip_quoted(s,   out, i, j) {
  out = ""
  while ((i = index(s, "「")) > 0) {
    out = out substr(s, 1, i - 1); s = substr(s, i)
    j = index(s, "」"); if (j == 0) { s = ""; break }
    s = substr(s, j + length("」"))
  }
  s = out s; out = ""
  while ((i = index(s, "`")) > 0) {
    out = out substr(s, 1, i - 1); s = substr(s, i + 1)
    j = index(s, "`"); if (j == 0) { s = ""; break }
    s = substr(s, j + 1)
  }
  return out s
}

function check_vague(line,   plain) {
  plain = strip_quoted(line)
  if (match(plain, vague)) err(FNR, "空泛用語「" substr(plain, RSTART, RLENGTH) "」：改寫成可以驗證的具體動作")
}

function normalize(h) {
  sub(/<!--.*-->/, "", h)
  sub(/^[0-9]+\.[ ]*/, "", h)
  gsub(/^[ ]+|[ ]+$/, "", h)
  return h
}

function close_entry() {
  if (title == "") return
  if (has_symptom && (!has_cause || !has_how))
    err(eline, "「" title "」有症狀，但症狀／根因／怎麼做三段不齊（缺" (has_cause ? "" : "根因") (has_how ? "" : "怎麼做") "）")
  if (!has_why && !has_cause && !marked)
    err(eline, "「" title "」缺少「為什麼」或「根因」；沒有事故依據的條目請在標題標 <!-- 慣例 --> 或 <!-- 參考 -->")
  if (nlines > max)
    err(eline, "「" title "」本文 " nlines " 行，超過上限 " max " 行；請拆分或精簡")
  key = normalize(title)
  if (key in seen) err(eline, "「" key "」與 " seen[key] " 的條目標題重複")
  else seen[key] = rel ":" eline
  title = ""
}

FNR == 1 {
  if (rel != "") close_entry()
  rel = FILENAME
  if (index(rel, root) == 1) rel = substr(rel, length(root) + 1)
  fm = 0; fence = 0; title = ""
  # 檔案有 `##` 就以 `##` 為條目，否則用 `###`（略過 frontmatter 與程式碼區塊）
  level = "### "; n = 0; pfm = 0; pfence = 0
  while ((getline l < FILENAME) > 0) {
    n++
    if (n == 1 && l == "---") { pfm = 1; continue }
    if (pfm) { if (l == "---") pfm = 0; continue }
    if (l ~ /^[ \t]*```/) { pfence = !pfence; continue }
    if (!pfence && l ~ /^## /) { level = "## "; break }
  }
  close(FILENAME)
}
FNR == 1 && $0 == "---" { fm = 1; next }
fm { if ($0 == "---") fm = 0; next }

/^[ \t]*```/ { fence = !fence; if (title != "") nlines++; next }
fence { if (title != "") nlines++; next }

index($0, level) == 1 {
  close_entry()
  title = substr($0, length(level) + 1)
  eline = FNR
  marked = (index(title, "<!-- 慣例 -->") || index(title, "<!-- 參考 -->"))
  has_symptom = has_cause = has_why = has_how = nlines = 0
  check_vague(title)
  next
}
/^##? / && level == "### " { close_entry(); next }
/^# / { close_entry(); next }

{
  if (title != "" && $0 != "") nlines++
  if (index($0, "**症狀")) has_symptom = 1
  if (index($0, "**根因")) has_cause = 1
  if (index($0, "**為什麼")) has_why = 1
  if (index($0, "**怎麼做")) has_how = 1
  check_vague($0)
}

END {
  close_entry()
  if (errors > 0) { printf "✗ %d 個問題（標準見 docs/rule-quality.md）\n", errors > "/dev/stderr"; exit 1 }
  print "✓ 守則內容檢查通過"
}
' "${files[@]}"
