#!/usr/bin/env bash
# lint-rules.test.sh — scripts/lint-rules.sh 的行為測試。只寫入 /tmp 底下的暫存目錄。
#
# 用法：tests/lint-rules.test.sh

set -uo pipefail
export PATH="/usr/bin:/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINT="$ROOT/scripts/lint-rules.sh"
TMP="$(mktemp -d /tmp/aw-lint-test.XXXXXX)"

pass=0
fail=0

ok()   { echo "  ✓ $1"; pass=$((pass + 1)); }
bad()  { echo "  ✗ $1" >&2; fail=$((fail + 1)); }

# rule <fixture 目錄> <相對路徑（不含 .md）>：從 stdin 讀本文，寫成帶 frontmatter 的規則檔
rule() {
  local file="$1/rules/$2.md"
  mkdir -p "$(dirname "$file")"
  {
    printf -- '---\ncategory: %s\ntier: optional\n---\n\n' "$(dirname "$2")"
    cat
  } > "$file"
}

# expect <說明> <預期結束碼> <fixture 目錄>
expect() {
  ROOT="$3" "$LINT" > "$TMP/out" 2>&1
  local rc=$?
  if [ "$rc" -eq "$2" ]; then ok "$1"; else bad "$1（exit ${rc}，預期 $2）"; sed 's/^/      /' "$TMP/out" >&2; fi
}

# has <說明> <輸出應包含的字串>
has() {
  if grep -qF -- "$2" "$TMP/out"; then ok "$1"; else bad "$1（輸出沒有「$2」）"; sed 's/^/      /' "$TMP/out" >&2; fi
}

echo "▸ 合格：有「為什麼」的協作條目、三段齊全的地雷條目"
F="$TMP/good"
rule "$F" collaboration/a <<'EOF'
# 標題

## 先確認再動手

動手前先確認分支。

**為什麼：** 曾經在別人的分支上 commit。
EOF
rule "$F" db/pitfalls <<'EOF'
# 資料庫

## 遷移沒有冪等

- **症狀：** 重跑噴錯。
- **根因：** 沒有 IF NOT EXISTS。
- **怎麼做：** 一律加存在檢查。
EOF
expect "exit 0" 0 "$F"

echo "▸ 地雷條目三段不齊"
F="$TMP/pitfall"
rule "$F" db/pitfalls <<'EOF'
# 資料庫

## 遷移沒有冪等

- **症狀：** 重跑噴錯。
- **怎麼做：** 一律加存在檢查。
EOF
expect "exit 1" 1 "$F"
has "指出缺根因" "根因"
has "指出檔案與行號" "rules/db/pitfalls.md:8"

echo "▸ 沒有事故依據也沒有標註"
F="$TMP/nowhy"
rule "$F" writing/a <<'EOF'
# 寫作

## 先結論

第一段給結論。
EOF
expect "exit 1" 1 "$F"
has "提示可標註慣例" "<!-- 慣例 -->"

echo "▸ 標題標註慣例或參考就放行"
F="$TMP/marked"
rule "$F" writing/a <<'EOF'
# 寫作

## 先結論 <!-- 慣例 -->

第一段給結論。

## 常見替換 <!-- 參考 -->

| 不用 | 改用 |
EOF
expect "exit 0" 0 "$F"

echo "▸ 沒有 ## 時以 ### 為條目"
F="$TMP/h3"
rule "$F" testing/pitfalls <<'EOF'
# 測試

### 1. Mock 外洩

清理 mock。

### 2. 靜態 sleep

改用等待條件。

**為什麼：** CI 上隨機失敗。
EOF
expect "exit 1" 1 "$F"
has "指出第一個 ### 條目" "Mock 外洩"
if grep -qF "靜態 sleep" "$TMP/out"; then bad "有為什麼的 ### 條目不該被報"; else ok "有為什麼的 ### 條目不報"; fi

echo "▸ 空泛用語"
F="$TMP/vague"
rule "$F" writing/a <<'EOF'
# 寫作

## 範例值

**為什麼：** 曾經留空導致啟動失敗。

盡量提供預設值。
EOF
expect "exit 1" 1 "$F"
has "指出空泛用語" "盡量"

echo "▸ 引號、行內程式碼與程式碼區塊裡的空泛用語不算"
F="$TMP/quoted"
rule "$F" writing/a <<'EOF'
# 寫作

## 不寫空話

**為什麼：** 規則被稀釋。

不寫「盡量寫好」這種話，也不寫 `適當處理`。

```text
盡量
```
EOF
expect "exit 0" 0 "$F"

echo "▸ 縮排的程式碼區塊：裡面的 # 註解與空泛用語不算"
F="$TMP/indented"
rule "$F" writing/a <<'EOF'
# 寫作

### 範例

**為什麼：** 事故。

- 設定：
  ```bash
  ## 這是 shell 註解，不是標題
  盡量
  ```
EOF
expect "exit 0" 0 "$F"

echo "▸ 標題本身的空泛用語"
F="$TMP/vague-title"
rule "$F" writing/a <<'EOF'
# 寫作

## 盡量寫測試

**為什麼：** 事故。
EOF
expect "exit 1" 1 "$F"
has "指出標題的空泛用語" "盡量"

echo "▸ 跨檔重複的條目標題（忽略編號與標註）"
F="$TMP/dup"
rule "$F" a/one <<'EOF'
# 一

## 1. 不刪測試

**為什麼：** 事故。
EOF
rule "$F" b/two <<'EOF'
# 二

## 不刪測試 <!-- 慣例 -->

內容。
EOF
expect "exit 1" 1 "$F"
has "指出重複標題" "不刪測試"

echo "▸ 條目過長"
F="$TMP/long"
{
  printf '# 長\n\n## 很長的條目\n\n**為什麼：** 事故。\n\n'
  for i in $(seq 1 60); do echo "- 第 $i 行"; done
} | rule "$F" a/long
expect "exit 1" 1 "$F"
has "指出條目過長" "很長的條目"

echo "▸ 本 repo"
expect "目前的守則全部通過" 0 "$ROOT"

echo "──"
echo "通過 ${pass}｜失敗 ${fail}｜暫存目錄 ${TMP}"
[ "$fail" -eq 0 ]
