#!/usr/bin/env bash
# rules.sh — 守則來源檔的路徑對應與 frontmatter 解析，供 install.sh 與 scripts/lib/install-*.sh 共用。
#
# 依賴呼叫端的全域變數：ROOT（repo 根目錄）、RULES（目前語言的守則目錄）、TEAM_RULES（團隊守則目錄，可空）；
# src_of 與 team_ids 需要先載入 policy.sh。
# 這支只定義函式，用 source 載入。

sha() {
  if [ $# -ge 1 ]; then
    if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
    else sha256sum "$1" | cut -d' ' -f1; fi
  else
    if command -v shasum >/dev/null 2>&1; then shasum -a 256 | cut -d' ' -f1
    else sha256sum | cut -d' ' -f1; fi
  fi
}

# frontmatter 單行欄位值（與 check-budget.sh 相同的解析方式）
field() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    NR > 1 && index($0, key ":") == 1 { sub("^" key ":[ ]*", ""); print; exit }' "$1"
}

has_paths() {
  awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } /^(paths|globs):/ { found = 1 } END { exit !found }' "$1"
}

body_lines() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm { n++ } END { print n + 0 }' "$1"
}

# 去掉 YAML 字串外層的雙引號
unquote() { sed -e 's/^"//' -e 's/"$//'; }

title() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm && /^# / { sub(/^# /, ""); print; exit }' "$1"
}

all_ids() {
  find "$RULES" -type f -name '*.md' | sed -e "s#^$RULES/##" -e 's#\.md$##' | sort
}

version() {
  sed -n 's/.*"version"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -n 1
}

contains() { printf '%s\n' "$1" | grep -Fxq -- "$2"; }

# src_of <id>：守則來源檔。custom/<name> 是團隊守則，其餘是內建守則
src_of() {
  case "$1" in
    custom/*)
      # 名稱不合法（例如 custom/../../x）時指向不存在的路徑，呼叫端的存在檢查會擋下
      if aw_is_team_name "${1#custom/}"; then printf '%s/%s.md' "${TEAM_RULES:-/nonexistent}" "${1#custom/}"
      else printf '/nonexistent/invalid-team-rule.md'; fi ;;
    *) printf '%s/%s.md' "$RULES" "$1" ;;
  esac
}

# team_ids：團隊守則 id（custom/<name>），檔名只接受小寫英數與連字號；README.md 略過
team_ids() { aw_team_rule_ids "$TEAM_RULES"; }

# is_deprecated <id>：frontmatter 有 deprecated 欄位就是已淘汰
is_deprecated() {
  awk 'NR == 1 && $0 != "---" { exit 1 } NR > 1 && $0 == "---" { exit 1 } /^deprecated:/ { found = 1; exit } END { exit !found }' "$(src_of "$1")" 2>/dev/null
}

# deprecation_note <id>：「已淘汰：<原因>；改用 <替代守則>」
deprecation_note() {
  local reason replaced
  reason="$(field "$(src_of "$1")" deprecated | unquote)"
  replaced="$(field "$(src_of "$1")" replaced_by | unquote)"
  printf '已淘汰：%s' "${reason:-未說明原因}"
  [ -n "$replaced" ] && printf '；改用 %s' "$replaced"
  return 0
}

# frontmatter 的 paths 清單，以「, 」串起來
paths_of() {
  awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit }
       /^(paths|globs):/ { on = 1; next } on && /^[ ]+- / { sub(/^[ ]+- [ ]*/, ""); gsub(/^"|"$/, ""); out = out (out == "" ? "" : ", ") $0; next }
       on { on = 0 } END { print out }' "$1"
}

# with_title <id> <顯示名稱>：來源規則有標題就印「<顯示名稱> — <標題>」，否則只印顯示名稱
with_title() {
  local t=""
  [ -f "$(src_of "$1")" ] && t="$(title "$(src_of "$1")")"
  if [ -n "$t" ]; then printf '%s — %s' "$2" "$t"; else printf '%s' "$2"; fi
}

# 去掉 frontmatter 與本文開頭的空行
strip_body() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } fm { next }
       !started && $0 == "" { next } { started = 1; print }' "$1"
}

# alias_id <id>：舊 id 對應到目前的守則 id（別名相容）
alias_id() {
  case "$1" in
    vue/pitfalls) echo "frontend/pitfalls" ;;
    laravel/pitfalls) echo "backend/pitfalls" ;;
    docker/pitfalls) echo "container/pitfalls" ;;
    security/data-scope) echo "security/tenant-isolation" ;;
    security/tls-certificates) echo "container/pitfalls" ;;
    *) echo "$1" ;;
  esac
}
