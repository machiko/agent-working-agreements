#!/usr/bin/env bash
# incident-draft.sh — 把 /agreements:record 產生的自訂守則整理成上游「踩坑事故回報」issue 的草稿。
#
# 用法：
#   scripts/incident-draft.sh <守則檔> [--out <草稿檔>]   產生草稿與標題檔，並做去識別化掃描
#   scripts/incident-draft.sh --attest <草稿檔>            使用者看過草稿並明確同意後，勾選草稿的核對清單
#
# 產生草稿時輸出（stdout）：
#   title_file=<標題檔路徑>（<草稿檔>.title，內容只有一行標題）
#   draft=<草稿檔路徑>
#   接著是 sanitize-check.sh 對標題與草稿的掃描結果
#
# 本工具只產生與修改本機檔案，不會呼叫 gh 或任何網路服務；送出由使用者確認後另外執行。
# 去識別化掃描只抓得到私有 IP、金鑰、信箱與私人禁用詞清單裡的詞；專案名、公司名、人名要靠人工檢查。
# 結束碼：0 通過去識別化掃描；1 有命中（檔案仍會寫出，改完再掃一次）；2 參數錯誤或守則檔格式不對。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKLIST_HEADING="### 去識別化與授權核對清單"

die() { echo "✗ $1" >&2; exit 2; }

# ── 勾選模式：只改核對清單標題之後的三行 ─────────────────
if [ "${1:-}" = "--attest" ]; then
  draft="${2:-}"
  [ -n "$draft" ] && [ -f "$draft" ] || die "--attest 需要已存在的草稿檔"
  grep -qxF "$CHECKLIST_HEADING" "$draft" || die "${draft} 沒有核對清單，不像 incident-draft.sh 產生的草稿"
  awk -v h="$CHECKLIST_HEADING" '$0 == h { on = 1 } on && /^- \[ \] / { sub(/^- \[ \] /, "- [x] ") } { print }' "$draft" > "$draft.tmp"
  mv "$draft.tmp" "$draft"
  echo "✓ 已勾選核對清單：$draft"
  exit 0
fi

rule=""
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) [ $# -ge 2 ] || die "--out 需要檔案路徑"; out="$2"; shift 2 ;;
    -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    -*) die "未知參數：$1" ;;
    *) [ -z "$rule" ] || die "只能指定一個守則檔"; rule="$1"; shift ;;
  esac
done

[ -n "$rule" ] || die "需要守則檔，例如 .claude/rules/agent-agreements/custom/<name>.md"
[ -f "$rule" ] || die "找不到守則檔：$rule"
[ -n "$out" ] || out="$(mktemp "${TMPDIR:-/tmp}/aw-incident.XXXXXX")"

# 統一成 LF 行尾再處理（Windows 編輯過的守則是 CRLF）
src="$(mktemp "${TMPDIR:-/tmp}/aw-incident-src.XXXXXX")"
trap 'rm -f "$src"' EXIT
tr -d '\r' < "$rule" > "$src"
[ "$(head -n 1 "$src")" = "---" ] || die "${rule} 沒有 frontmatter（第一行要是 ---），不像 /agreements:record 產生的守則"

# frontmatter 單行欄位，去掉外層引號
field() {
  awk -v key="$1" 'NR == 1 { next } $0 == "---" { exit } index($0, key ":") == 1 { sub("^" key ":[ ]*", ""); print; exit }' "$src" \
    | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

# frontmatter 清單欄位，每項一行
list_items() {
  awk -v key="$1" 'NR == 1 { next } $0 == "---" { exit } $0 == key ":" { on = 1; next }
    on && /^[ ]+- / { sub(/^[ ]+- [ ]*/, ""); gsub(/^"|"$/, ""); print; next } on { on = 0 }' "$src"
}

# 本文：去掉 frontmatter、開頭空行，以及 record 自動加的說明行（連同它後面的一個空行）
body() {
  awk 'NR == 1 { fm = 1; next } fm { if ($0 == "---") fm = 0; next }
       skip_blank { skip_blank = 0; if ($0 == "") next }
       index($0, "> 本規則由 /agreements:record 採集建立") == 1 { skip_blank = 1; next }
       { print }' "$src" | sed -e '/./,$!d'
}

# section <中文標籤> <英文標籤>：收集各條目的該段內容（含縮排的續行）；條目超過一個時加上條目標題
section() {
  body | awk -v zh="**$1：**" -v en="**$2:**" '
    # 程式碼區塊：結束標記要與開頭同一種字元、長度不短於開頭（CommonMark 規則）
    match($0, /^[ \t]*(````*|~~~~*)/) {
      mark = substr($0, RSTART, RLENGTH); sub(/^[ \t]*/, "", mark)
      if (fence == "") { fence = mark; cur = 0; next }
      if (substr(mark, 1, 1) == substr(fence, 1, 1) && length(mark) >= length(fence) && $0 ~ /^[ \t]*[`~]+[ \t]*$/) { fence = ""; next }
    }
    fence != "" { next }
    /^## / { entry = substr($0, 4); cur = 0; next }
    {
      line = $0
      sub(/^[ ]*-[ ]+/, "", line)
      if (index(line, zh) == 1 || index(line, en) == 1) {
        text = substr(line, (index(line, zh) == 1 ? length(zh) : length(en)) + 1)
        sub(/^[ ]+/, "", text)
        n++; items[n] = text; titles[n] = entry; cur = n
        next
      }
      # 縮排的續行接在目前這段後面；空行、新的清單項目或標籤都會結束這段
      if (cur && $0 ~ /^[ ]+[^ -]/) { sub(/^[ ]+/, "", line); items[cur] = items[cur] " " line; next }
      cur = 0
    }
    END {
      for (i = 1; i <= n; i++) print (n > 1 && titles[i] != "" ? "- **" titles[i] "**：" : "") items[i]
    }'
}

label="$(field label)"
[ -n "$label" ] || label="$(body | sed -n 's/^# //p' | head -n 1)"
[ -n "$label" ] || die "${rule} 沒有 label 也沒有 # 標題"
category="$(field category)"
if [ -n "$category" ] && [ -d "$ROOT/rules/$category" ]; then
  category_line="$category"
elif [ "${category:-custom}" = "custom" ]; then
  category_line="其他新分類（請維護者判斷）"
else
  category_line="其他新分類（${category}）"
fi

missing="（見下方守則草稿）"
symptom="$(section 症狀 Symptom)"
cause="$(section 根因 'Root cause')"
how="$(section 怎麼做 How)"
incidents="$(list_items incidents | sed 's/^/- /')"

# 守則全文用比內文最長的連續反引號再多一個的 fence 包住（至少 4 個），避免內文提早關閉 fence
longest="$(body | awk '{ s = $0; while (match(s, /`+/)) { if (RLENGTH > m) m = RLENGTH; s = substr(s, RSTART + RLENGTH) } } END { print m + 0 }')"
fence_len=$((longest + 1)); [ "$fence_len" -lt 4 ] && fence_len=4
fence="$(printf '%*s' "$fence_len" '' | tr ' ' '`')"

{
  echo "### 建議分類"
  echo
  echo "$category_line"
  echo
  echo "### 事故症狀 (Symptom)"
  echo
  echo "${symptom:-$missing}"
  echo
  echo "### 為什麼／根因 (Root Cause)"
  echo
  echo "${cause:-$missing}"
  echo
  echo "### 怎麼做／定案做法 (How to Apply)"
  echo
  echo "${how:-$missing}"
  echo
  echo "### 事故來源"
  echo
  echo "${incidents:-（未列出）}"
  echo
  echo "### 守則草稿"
  echo
  echo "${fence}markdown"
  body
  echo "$fence"
  echo
  echo "$CHECKLIST_HEADING"
  echo
  echo "- [ ] 我已檢查並移除所有內部專案名稱、公司組織名、人名"
  echo "- [ ] 我已檢查並移除私有 IP、內部域名、真實帳密、API Token 或憑證"
  echo "- [ ] 我同意此內容以本專案的 MIT License 開源釋出"
  echo
  echo "<!-- 由 agent-working-agreements 的 scripts/incident-draft.sh 產生 -->"
} > "$out"
printf '地雷提案：%s\n' "$label" > "$out.title"

echo "title_file=${out}.title"
echo "draft=${out}"

# 送出後 @帳號 會通知對方、#數字 會連到 issue：提醒改寫或加反引號
mentions="$(cat "$out.title" "$out" | grep -nE '(^|[^A-Za-z0-9._%+-])@[A-Za-z0-9][A-Za-z0-9-]*|(^|[^&A-Za-z0-9])#[0-9]+' || true)"
if [ -n "$mentions" ]; then
  echo "⚠ 草稿含 @帳號 或 #編號，送出後會通知該帳號或連到該 issue；不是有意的話請改寫或用反引號包住："
  printf '%s\n' "$mentions" | sed 's/^/    /'
fi

"$ROOT/scripts/sanitize-check.sh" "$out.title" "$out"
