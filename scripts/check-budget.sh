#!/usr/bin/env bash
# check-budget.sh — 驗證規則檔 frontmatter，並檢查常駐（tier: core）規則的本文總行數。
# frontmatter 必填：category（與目錄一致）、tier、incidents（至少一項）、last_reviewed（YYYY-MM-DD）。
# 淘汰守則：deprecated 要寫原因、不可是 core；replaced_by（選填）要指向存在的守則。
# 欄位定義見 docs/rule-quality.md。
#
# 用法：scripts/check-budget.sh [--quiet]
#   BUDGET=400  常駐行數上限（預設 400）
#   ROOT=<目錄>  改檢查其他目錄的 rules/（測試用）
#
# 結束碼：0 通過；1 frontmatter 不合格或超出預算。

set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BUDGET="${BUDGET:-400}"
QUIET="${1:-}"

errors=0
core_total=0
optional_total=0

# frontmatter 清單欄位的項目數（`key:` 之後連續的 `  - ` 行）
list_count() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    NR > 1 && $0 == key ":" { on = 1; next }
    on && /^[ ]+- / { n++; next }
    on { on = 0 }
    END { print n + 0 }' "$1"
}

# has_key <檔案> <欄位>：frontmatter 有這個欄位（值可以是空的）就回傳 0
has_key() {
  awk -v key="$2" 'NR == 1 && $0 != "---" { exit 1 } NR > 1 && $0 == "---" { exit 1 }
    NR > 1 && index($0, key ":") == 1 { found = 1; exit } END { exit !found }' "$1"
}

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

  if [ "$(list_count "$file" incidents)" -eq 0 ]; then
    echo "✗ ${rel}：缺少 incidents（至少列一項事故來源）" >&2
    errors=$((errors + 1))
  fi

  reviewed="$(field "$file" last_reviewed)"
  if [ -z "$reviewed" ]; then
    echo "✗ ${rel}：缺少 last_reviewed" >&2
    errors=$((errors + 1))
  elif ! printf '%s' "$reviewed" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    echo "✗ ${rel}：last_reviewed「${reviewed}」格式要是 YYYY-MM-DD" >&2
    errors=$((errors + 1))
  fi

  if has_key "$file" deprecated; then
    if [ -z "$(field "$file" deprecated | sed -e 's/^"//' -e 's/"$//')" ]; then
      echo "✗ ${rel}：deprecated 要寫淘汰原因" >&2
      errors=$((errors + 1))
    fi
    if [ "$tier" = "core" ]; then
      echo "✗ ${rel}：core 守則不可直接淘汰，先改成 optional（常駐守則淘汰會讓所有安裝者失去它）" >&2
      errors=$((errors + 1))
    fi
  fi
  replaced="$(field "$file" replaced_by | sed -e 's/^"//' -e 's/"$//')"
  if [ -n "$replaced" ]; then
    if ! has_key "$file" deprecated; then
      echo "✗ ${rel}：replaced_by 只能跟 deprecated 一起寫" >&2
      errors=$((errors + 1))
    elif ! printf '%s' "$replaced" | grep -Eq '^[a-z0-9-]+/[a-z0-9-]+$' || [ ! -f "$ROOT/rules/$replaced.md" ]; then
      echo "✗ ${rel}：replaced_by「${replaced}」不存在" >&2
      errors=$((errors + 1))
    elif [ "rules/$replaced.md" = "$rel" ] || has_key "$ROOT/rules/$replaced.md" deprecated; then
      echo "✗ ${rel}：replaced_by「${replaced}」必須是另一條未淘汰的守則" >&2
      errors=$((errors + 1))
    fi
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
