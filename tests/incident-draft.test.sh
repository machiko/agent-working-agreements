#!/usr/bin/env bash
# incident-draft.test.sh — scripts/incident-draft.sh（自訂守則 → 事故回報 issue 草稿）與 sanitize-check.sh 檔案模式的測試。
# 用假的 gh 與 curl 確認草稿工具絕不會自己送出。
#
# 用法：tests/incident-draft.test.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d /tmp/aw-incident-test.XXXXXX)"
export HOME="$TMP/home"   # 不讀使用者的私人禁用詞清單
mkdir -p "$HOME" "$TMP/bin"
DRAFT="$ROOT/scripts/incident-draft.sh"

# 假的 gh、curl：被呼叫就留下紀錄
for cmd in gh curl; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/network-calls"\n' "$cmd" "$TMP" > "$TMP/bin/$cmd"
  chmod +x "$TMP/bin/$cmd"
done
export PATH="$TMP/bin:/usr/bin:/bin:$PATH"

pass=0
fail=0

ok()    { echo "  ✓ $1"; pass=$((pass + 1)); }
bad()   { echo "  ✗ $1" >&2; fail=$((fail + 1)); }
has()   { if grep -qF -- "$3" "$2"; then ok "$1"; else bad "$1（沒有「$3」）"; sed 's/^/      /' "$2" >&2; fi; }
hasnt() { if grep -qF -- "$3" "$2"; then bad "$1（不該有「$3」）"; else ok "$1"; fi; }

RULE="$TMP/prevent-schema-wipe.md"
cat > "$RULE" <<'EOF'
---
category: custom
tier: custom
label: "不可清空 migration"
summary: "重置資料庫前先確認環境"
incidents:
  - "Agent 在共用開發庫執行 migrate:fresh，同事的測試資料全部消失"
last_reviewed: 2026-11-10
---

# 不可清空 migration

> 本規則由 /agreements:record 採集建立。格式：症狀 → 根因 → 怎麼做。

## 共用資料庫被重置

- **症狀：** 執行 migrate:fresh 後共用開發庫的資料全部消失。
- **根因：** Agent 以為連的是本機資料庫，沒有檢查 DB_HOST。
- **怎麼做：** 執行 migrate:fresh、db:wipe 前先印出 DB_HOST，不是 127.0.0.1 或 localhost 就停下來問。
EOF

echo "▸ 產生草稿"
OUT="$TMP/draft.md"
"$DRAFT" "$RULE" --out "$OUT" > "$TMP/stdout" 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "乾淨的守則結束碼為 0" || { bad "乾淨的守則應通過（rc=${rc}）"; cat "$TMP/stdout" >&2; }
has "印出標題檔路徑" "$TMP/stdout" "title_file=$OUT.title"
check_title() { [ "$(cat "$OUT.title")" = "地雷提案：不可清空 migration" ]; }
check_title && ok "標題檔內容" || bad "標題檔內容不對"
has "印出草稿路徑" "$TMP/stdout" "draft=$OUT"
has "症狀段" "$OUT" "### 事故症狀 (Symptom)"
has "症狀內容" "$OUT" "共用開發庫的資料全部消失"
has "根因內容" "$OUT" "沒有檢查 DB_HOST"
has "怎麼做內容" "$OUT" "不是 127.0.0.1 或 localhost 就停下來問"
has "事故來源" "$OUT" "同事的測試資料全部消失"
has "附上守則全文" "$OUT" "## 共用資料庫被重置"
hasnt "不附 record 的自動說明" "$OUT" "本規則由 /agreements:record 採集建立"
has "核對清單預設未勾選" "$OUT" "- [ ] 我已檢查並移除所有內部專案名稱"
has "分類對不上時歸到其他" "$OUT" "其他新分類"

echo "▸ --attest：使用者確認後只勾選草稿的核對清單"
printf '\n<!-- 使用者手動修改 -->\n' >> "$OUT"
"$DRAFT" --attest "$OUT" > /dev/null 2>&1
has "勾選核對清單" "$OUT" "- [x] 我已檢查並移除所有內部專案名稱"
has "保留草稿上的修改" "$OUT" "<!-- 使用者手動修改 -->"
"$DRAFT" --attest "$TMP/clean-nope.md" > /dev/null 2>&1; [ $? -eq 2 ] && ok "--attest 草稿不存在時回 2" || bad "--attest 草稿不存在應回 2"

echo "▸ 英文守則"
EN="$TMP/en-rule.md"
cat > "$EN" <<'EOF'
---
category: database
tier: custom
label: "Never wipe a shared database"
incidents:
  - "An agent ran migrate:fresh against a shared dev database"
last_reviewed: 2026-11-10
---

# Never wipe a shared database

## Shared database reset

- **Symptom:** All data in the shared dev database disappeared.
- **Root cause:** The agent assumed a local database.
- **How:** Print DB_HOST before migrate:fresh and stop unless it is localhost.
EOF
"$DRAFT" "$EN" --out "$OUT" > "$TMP/stdout" 2>&1
has "讀英文段落標籤" "$OUT" "The agent assumed a local database."
[ "$(awk 'p { if ($0 != "") { print; exit } } $0 == "### 建議分類" { p = 1 }' "$OUT")" = "database" ] && ok "分類對得上時沿用" || bad "建議分類應為 database"

echo "▸ 多條目、續行、程式碼區塊與 fence"
MULTI="$TMP/multi.md"
cat > "$MULTI" <<'EOF'
---
category: custom
label: "多條目"
incidents:
  - "測試"
---

# 多條目

## 第一個坑

- **症狀：** 第一行
  續寫的第二行
- **根因：** 根因一
- **怎麼做：** 做法一

## 第二個坑

````bash
## 這不是條目標題
- **症狀：** 這是程式碼裡的字，不是症狀
```
````

- **症狀：** 症狀二
EOF
"$DRAFT" "$MULTI" --out "$OUT" > /dev/null 2>&1
has "收進續行" "$OUT" "第一行 續寫的第二行"
has "多條目加標題" "$OUT" "- **第一個坑**：第一行"
hasnt "略過程式碼區塊" "$OUT" "- **## 這不是條目標題**"
hasnt "程式碼裡的標籤不算" "$OUT" "**：這是程式碼裡的字"
fence_open="$(grep -n '^`````*markdown$' "$OUT" | head -n 1)"
[ "$(printf '%s' "$fence_open" | sed 's/^[0-9]*://' | tr -cd '`' | wc -c | tr -d ' ')" -ge 5 ] && ok "fence 比內文最長的反引號更長" || bad "fence 長度不夠：$fence_open"

echo "▸ CRLF 守則"
tr -d '\r' < "$RULE" | sed 's/$/\r/' > "$TMP/crlf.md"
"$DRAFT" "$TMP/crlf.md" --out "$OUT" > /dev/null 2>&1 && ok "CRLF 守則可以產生草稿" || bad "CRLF 守則應可處理"
has "CRLF 內容正確" "$OUT" "沒有檢查 DB_HOST。"

echo "▸ @提及與 #編號"
sed 's/^  - "Agent 在共用開發庫/  - "#123 Agent 在共用開發庫/' "$RULE" > "$TMP/mention.md"
"$DRAFT" "$TMP/mention.md" --out "$OUT" > "$TMP/stdout" 2>&1
has "警告 #編號" "$TMP/stdout" "@帳號 或 #編號"

echo "▸ 去識別化"
LEAK="$TMP/leak.md"
PRIV_IP="192.168"".3.20"   # 拆開寫，避免本檔被 repo 的 sanitize-check 掃到
sed "s/沒有檢查 DB_HOST。/沒有檢查 DB_HOST（${PRIV_IP}）。/" "$RULE" > "$LEAK"
"$DRAFT" "$LEAK" --out "$OUT" > "$TMP/stdout" 2>&1; rc=$?
[ "$rc" -eq 1 ] && ok "含私有 IP 時結束碼為 1" || bad "含私有 IP 應失敗（rc=${rc}）"
has "指出命中位置" "$TMP/stdout" "$PRIV_IP"
[ -f "$OUT" ] && ok "仍然寫出草稿供修改" || bad "應寫出草稿"
LABEL_LEAK="$TMP/label-leak.md"
sed "s/^label: .*/label: \"結帳服務 ${PRIV_IP}\"/" "$RULE" > "$LABEL_LEAK"
"$DRAFT" "$LABEL_LEAK" --out "$OUT" > "$TMP/stdout" 2>&1; rc=$?
[ "$rc" -eq 1 ] && ok "標題含識別資訊時也會被抓到" || bad "標題也要掃描（rc=${rc}）"

echo "▸ sanitize-check.sh 檔案模式"
printf 'contact: someone%scorp-internal.io\n' "@" > "$TMP/mail.md"
"$ROOT/scripts/sanitize-check.sh" "$TMP/mail.md" > "$TMP/stdout" 2>&1 && bad "含信箱的檔案應失敗" || ok "指定檔案時只掃該檔並抓到信箱"
printf 'nothing here\n' > "$TMP/clean.md"
"$ROOT/scripts/sanitize-check.sh" "$TMP/clean.md" > "$TMP/stdout" 2>&1 && ok "乾淨的檔案通過" || { bad "乾淨的檔案應通過"; cat "$TMP/stdout" >&2; }

echo "▸ 錯誤處理"
"$DRAFT" "$TMP/nope.md" > /dev/null 2>&1; [ $? -eq 2 ] && ok "檔案不存在時結束碼為 2" || bad "檔案不存在應回 2"
printf '# 沒有 frontmatter\n' > "$TMP/nofm.md"
"$DRAFT" "$TMP/nofm.md" > /dev/null 2>&1; [ $? -eq 2 ] && ok "沒有 frontmatter 時結束碼為 2" || bad "沒有 frontmatter 應回 2"

echo "▸ 不會自己送出"
[ ! -f "$TMP/network-calls" ] && ok "沒有呼叫 gh 或 curl" || { bad "草稿工具不該呼叫網路"; cat "$TMP/network-calls" >&2; }

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 ${TMP}"
[ "$fail" -eq 0 ]
