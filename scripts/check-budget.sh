#!/usr/bin/env bash
# check-budget.sh — 驗證規則檔 frontmatter，並檢查常駐（tier: core）規則的本文總行數。
#
# 用法：scripts/check-budget.sh [--quiet]
#   BUDGET=400  常駐行數上限（預設 400）
#
# 結束碼：0 通過；1 frontmatter 不合格或超出預算。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUDGET="${BUDGET:-400}"
QUIET="${1:-}"

errors=0
core_total=0
optional_total=0

# 讀出單一 frontmatter 欄位的值（只支援 `key: value` 單行格式）
field() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    NR > 1 && index($0, key ":") == 1 {
      sub("^" key ":[ ]*", ""); print; exit
    }' "$1"
}

while IFS= read -r file; do
  rel="${file#"$ROOT"/}"
  dir_category="$(basename "$(dirname "$file")")"
  # 只算本文：Claude Code 載入規則前會移除 frontmatter，不佔 context
  lines=$(awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm { n++ } END { print n + 0 }' "$file")

  if [ "$(head -n 1 "$file")" != "---" ]; then
    echo "✗ ${rel}：缺少 frontmatter" >&2
    errors=$((errors + 1))
    continue
  fi

  category="$(field "$file" category)"
  tier="$(field "$file" tier)"

  if [ "$category" != "$dir_category" ]; then
    echo "✗ ${rel}：category「${category}」與所在目錄「${dir_category}」不一致" >&2
    errors=$((errors + 1))
  fi

  case "$tier" in
    core) core_total=$((core_total + lines)) ;;
    optional) optional_total=$((optional_total + lines)) ;;
    *)
      echo "✗ ${rel}：tier 必須是 core 或 optional，目前是「${tier}」" >&2
      errors=$((errors + 1))
      continue
      ;;
  esac

  [ "$QUIET" = "--quiet" ] || printf '%-9s %4d  %s\n' "$tier" "$lines" "$rel"
done < <(find "$ROOT/rules" -type f -name '*.md' | sort)

echo "──"
echo "core：${core_total} 行（上限 ${BUDGET}）｜optional：${optional_total} 行"

if [ "$errors" -gt 0 ]; then
  echo "✗ ${errors} 個 frontmatter 錯誤" >&2
  exit 1
fi

if [ "$core_total" -gt "$BUDGET" ]; then
  echo "✗ core 超出預算 $((core_total - BUDGET)) 行" >&2
  exit 1
fi

echo "✓ 通過"
