#!/usr/bin/env bash
# install-agents-md.sh — install.sh 寫入單一檔案的目標（--agents-md、--copilot、--windsurf）：
# 只改寫 agent-agreements 標記區塊，區塊外的內容逐位元組保留；也負責這類目標的 --status。
#
# 讀寫呼叫端的全域變數：agents_md、mode、desired、select_ids、active_policy、lang、installed_lang、dry_run。
# 依賴 rules.sh、install-report.sh 與呼叫端的 die。這支只定義函式，用 source 載入。

START_RE='^<!-- agent-agreements:start'
END_LINE='<!-- agent-agreements:end -->'

# section <id> <檔案>：區塊內某條規則的段落（到下一條規則或結束標記為止）
section() {
  awk -v id="$1" -v end="$END_LINE" '
    $0 == "<!-- rule: " id " -->" { on = 1; next }
    on && (index($0, "<!-- rule: ") == 1 || $0 == end) { exit }
    on { print }' "$2"
}

# agents_md_find_block：設定 start_ln、end_ln（沒有區塊時為空）；區塊不完整時 die
agents_md_find_block() {
  start_ln=""; end_ln=""
  [ -f "$agents_md" ] || return 0
  start_ln="$(grep -n "$START_RE" "$agents_md" | head -n 1 | cut -d: -f1 || true)"
  end_ln="$(grep -n -x -F -- "$END_LINE" "$agents_md" | head -n 1 | cut -d: -f1 || true)"
  if [ -n "$start_ln" ] && { [ -z "$end_ln" ] || [ "$end_ln" -lt "$start_ln" ]; }; then
    die "${agents_md} 的 agent-agreements 區塊不完整（找不到結束標記），請手動修正後再執行"
  fi
}

# agents_md_status：唯讀，比對區塊內每條規則與目前來源
agents_md_status() {
  local blk installed_v schema_v policy_v
  if [ -z "$start_ln" ]; then
    echo "尚未安裝：${agents_md} 沒有 agent-agreements 區塊"
    return 0
  fi
  # 區塊只讀一次存進變數：用管線餵 section 時，awk 提早 exit 會讓上游收到 SIGPIPE，大區塊下整個 --status 失敗
  blk="$(sed -n "${start_ln},${end_ln}p" "$agents_md")"
  installed_v="$(sed -n "${start_ln}s/^<!-- agent-agreements:start v\([^ ]*\) -->.*/\1/p" "$agents_md")"
  schema_v="$(sed -n "${start_ln},\$s/^<!-- agent-agreements:schema=\([^ ]*\) -->/\1/p" "$agents_md" | head -n 1)"
  policy_v="$(sed -n "${start_ln},\$s/^<!-- agent-agreements:policy=\([^ ]*\) -->/\1/p" "$agents_md" | head -n 1)"
  echo "安裝位置：${agents_md}"
  echo "安裝版本：${installed_v:-未記錄}｜目前版本：$(version)"
  echo "守則語言：${installed_lang:-zh-TW}"
  [ -n "$schema_v" ] && echo "規範結構：Schema v${schema_v}"
  [ -n "$policy_v" ] && echo "團隊策略：${policy_v}"
  for id in $(printf '%s\n' "$blk" | sed -n 's/^<!-- rule: \([^ ]*\) -->$/\1/p' | sort); do
    sec="$(section "$id" - <<< "$blk")"
    lines=0; [ -n "$sec" ] && lines="$(printf '%s\n' "$sec" | grep -c '')"
    src="$(src_of "$id")"
    if [ -f "$src" ]; then
      t="$(title "$src")"
      if [ "$sec" = "$(strip_body "$src")" ]; then st="最新"; else st="有新版"; fi
    else
      t="$(printf '%s\n' "$sec" | sed -n 's/^# //p' | head -n 1)"; st="來源已移除"
    fi
    # AGENTS.md 沒有 paths 機制，整個檔案都會載入，一律算常駐
    rule_record "$id" "$t" "" "$st" "$lines"
  done | report_status
}

# agents_md_new_block <輸出檔>：依 desired 產生新的標記區塊（uninstall 時為空檔）
agents_md_new_block() {
  local id
  : > "$1"
  [ "$mode" = "install" ] || return 0
  {
    echo "<!-- agent-agreements:start v$(version) -->"
    echo "<!-- agent-agreements:schema=1 -->"
    [ -n "$active_policy" ] && echo "<!-- agent-agreements:policy=$(basename "$active_policy") -->"
    echo "<!-- agent-agreements:selected=$(printf '%s' "$select_ids" | tr -d ' ') -->"
    echo "<!-- agent-agreements:lang=${lang} -->"
    echo "<!-- 由 agent-working-agreements 的 install.sh 產生，請勿手動編輯；重跑 install.sh --agents-md 即可更新 -->"
    for id in $desired; do
      echo
      echo "<!-- rule: $id -->"
      strip_body "$(src_of "$id")"
    done
    echo
    echo "$END_LINE"
  } > "$1"
}

# agents_md_diff <舊區塊> <新區塊> <舊 id 清單>：印出移除／更新／新增，設定 changes、unchanged
agents_md_diff() {
  local id
  changes=0; unchanged=0
  for id in $3; do
    if [ "$mode" = "install" ] && contains "$desired" "$id"; then continue; fi
    printf '－ 移除 %s\n' "$(with_title "$id" "$id")"; changes=$((changes + 1))
  done
  for id in $desired; do
    if contains "$3" "$id"; then
      if [ "$(section "$id" "$1")" = "$(section "$id" "$2")" ]; then
        unchanged=$((unchanged + 1))
      else
        printf '↻ 更新 %s\n' "$(with_title "$id" "$id")"; changes=$((changes + 1))
      fi
    else
      printf '＋ 新增 %s\n' "$(with_title "$id" "$id")"; changes=$((changes + 1))
    fi
  done
}

# agents_md_compose <新區塊> <輸出檔>：組出新檔案，區塊外的內容逐位元組保留；
# 移除模式而原本沒有區塊時，印出提示後以結束碼 0 結束
agents_md_compose() {
  local keep_before
  : > "$2"
  if [ -n "$start_ln" ]; then
    keep_before=$((start_ln - 1))
    # 移除時，順便拿掉當初附加區塊時加的空白分隔行
    if [ "$mode" = "uninstall" ] && [ "$keep_before" -gt 0 ] && [ -z "$(sed -n "${keep_before}p" "$agents_md")" ]; then
      keep_before=$((keep_before - 1))
    fi
    [ "$keep_before" -gt 0 ] && head -n "$keep_before" "$agents_md" >> "$2"
    cat "$1" >> "$2"
    tail -n "+$((end_ln + 1))" "$agents_md" >> "$2"
  elif [ "$mode" = "install" ]; then
    if [ -s "$agents_md" ]; then
      cat "$agents_md" >> "$2"
      [ "$(tail -c 1 "$agents_md" | od -An -c | tr -d ' ')" = '\n' ] || echo >> "$2"
      echo >> "$2"
    fi
    cat "$1" >> "$2"
  else
    echo "（${agents_md} 沒有 agent-agreements 區塊，不需移除）"
    exit 0
  fi
}

# install_agents_md：安裝、更新、移除或查詢標記區塊，完成後以結束碼 0 結束
install_agents_md() {
  local max_bytes work old_block new_block old_ids result bytes
  case "$agents_md" in "~"/*) agents_md="$HOME/${agents_md#\~/}" ;; esac
  max_bytes="${AGENTS_MD_MAX_BYTES:-32768}"

  agents_md_find_block

  if [ "$mode" = "status" ]; then
    agents_md_status
    exit 0
  fi

  work="$(mktemp -d "${TMPDIR:-/tmp}/aw-agents.XXXXXX")"

  old_block="$work/old"; : > "$old_block"
  [ -n "$start_ln" ] && sed -n "${start_ln},${end_ln}p" "$agents_md" > "$old_block"
  old_ids="$(sed -n 's/^<!-- rule: \([^ ]*\) -->$/\1/p' "$old_block" | sort)"

  new_block="$work/new"
  agents_md_new_block "$new_block"
  agents_md_diff "$old_block" "$new_block" "$old_ids"

  result="$work/result"
  agents_md_compose "$new_block" "$result"

  bytes="$(wc -c < "$result" | tr -d ' ')"
  echo "──"
  [ "$unchanged" -gt 0 ] && echo "＝ 不變 ${unchanged} 個"
  [ "$changes" -eq 0 ] && [ -f "$agents_md" ] && cmp -s "$result" "$agents_md" && echo "（區塊內容沒有變更）"
  if [ "$mode" = "install" ]; then
    echo "規則：$(printf '%s\n' "$desired" | grep -c .) 個｜${agents_md}：${bytes} bytes"
  else
    echo "${agents_md}：${bytes} bytes"
  fi
  if [ "$bytes" -gt "$max_bytes" ]; then
    echo "⚠ 超過 ${max_bytes} bytes（Codex project_doc_max_bytes 預設值），超出部分可能被截斷；可減少選擇的規則" >&2
  fi

  if [ "$dry_run" -eq 1 ]; then
    echo "（dry-run：未寫入任何檔案）"
    exit 0
  fi

  mkdir -p "$(dirname "$agents_md")"
  cat "$result" > "$agents_md"
  if [ "$mode" = "uninstall" ]; then
    if [ "$bytes" -eq 0 ]; then
      echo "✓ 已移除區塊；${agents_md} 現在是空檔案（未刪除檔案）"
    else
      echo "✓ 已移除區塊：${agents_md}"
    fi
  else
    echo "✓ 完成：${agents_md}"
  fi
  exit 0
}
