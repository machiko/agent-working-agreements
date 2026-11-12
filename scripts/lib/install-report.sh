#!/usr/bin/env bash
# install-report.sh — install.sh 的唯讀報告：--list 的守則清單，以及 --status 共用的紀錄格式與分組輸出。
#
# 依賴 rules.sh（field、has_paths、paths_of、title 等）與呼叫端的 RULES、TEAM_RULES。
# 這支只定義函式，用 source 載入。

# list_rules：--list 輸出，每條守則一行，以 tab 分隔
list_rules() {
  local id f stack scoped label summary dep repl
  for id in $(all_ids); do
    f="$RULES/$id.md"
    stack="$(field "$f" stack)"
    scoped="always"; has_paths "$f" && scoped="on-demand"
    label="$(field "$f" label | unquote)"
    summary="$(field "$f" summary | unquote)"
    dep="-"; repl="-"
    if is_deprecated "$id"; then dep="deprecated"; repl="$(field "$f" replaced_by | unquote)"; repl="${repl:--}"; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$(field "$f" tier)" "${stack:--}" "$scoped" "$(body_lines "$f")" "${label:-$(title "$f")}" "${summary:--}" "$dep" "$repl"
  done
}

# rule_record <id> <標題> <讀 paths 的檔案，空字串代表一律常駐> <狀態> <載入行數>
# 輸出一筆以 US（\037）分隔的紀錄：id、tier、標題、載入方式、狀態、行數、是否按需載入。
# 不用 tab：tab 屬於 IFS 空白字元，read 會把連續的 tab 合併，空欄位（例如沒有標題）後面就整列錯位。
US=$'\037'
rule_record() {
  local tier="optional" load="常駐" od=0
  [ -f "$(src_of "$1")" ] && tier="$(field "$(src_of "$1")" tier)"
  case "$1" in custom/*) tier="custom" ;; esac
  if [ -n "$3" ] && [ -f "$3" ] && has_paths "$3"; then
    load="按需載入（$(paths_of "$3")）"; od=1
  fi
  printf "%s${US}%s${US}%s${US}%s${US}%s${US}%s${US}%s\n" "$1" "$tier" "$2" "$load" "$4" "$5" "$od"
}

print_rule() {  # print_rule <id> <標題> <載入方式> <狀態>
  local name="$1"
  [ -n "$2" ] && name="$1 — $2"
  printf '  %s｜%s｜%s\n' "$name" "$3" "$4"
}

# 讀 rule_record 的紀錄，分 core／選擇的規則兩組印出，最後一行是行數與規則總數
report_status() {
  local records rows group label n always=0 ondemand=0 total=0
  records="$(cat)"
  for group in core selected custom; do
    case "$group" in
      core) label="core"; rows="$(printf '%s\n' "$records" | awk -F"$US" '$2 == "core"')" ;;
      selected) label="選擇的規則"; rows="$(printf '%s\n' "$records" | awk -F"$US" 'NF && $2 != "core" && $2 != "custom"')" ;;
      custom)
        rows="$(printf '%s\n' "$records" | awk -F"$US" '$2 == "custom"')"
        [ -n "$rows" ] || continue
        label="團隊守則" ;;
    esac
    n="$(printf '%s\n' "$rows" | grep -c . || true)"
    echo "${label}（${n} 個）"
    [ "$n" -eq 0 ] && echo "  （無）"
    while IFS="$US" read -r id _tier t load st lines od; do
      [ -n "$id" ] || continue
      print_rule "$id" "$t" "$load" "$st"
      if [ "$od" -eq 1 ]; then ondemand=$((ondemand + lines)); else always=$((always + lines)); fi
      total=$((total + 1))
    done <<< "$rows"
  done
  echo "常駐：${always} 行｜按需載入：${ondemand} 行｜共 ${total} 個規則"
}
