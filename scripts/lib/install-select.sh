#!/usr/bin/env bash
# install-select.sh — install.sh 安裝前的選擇解析：既有安裝的語言、--update 沿用的選項、團隊策略檔，
# 以及最後要安裝的守則清單（core ＋ 團隊守則 ＋ 選擇的 optional ＋ 策略檔強制守則）。
#
# 讀寫呼叫端的全域變數：target、cursor_dir、agents_md、PROFILE_NAME、END_LINE、lang、lang_arg、mode、
# select_ids、policy_file、active_policy、TEAM_RULES、installed_lang、desired。
# 依賴 policy.sh、rules.sh 與呼叫端的 die、use_lang。這支只定義函式，用 source 載入。

# resolve_installed_lang：讀既有安裝記錄的語言（沒記錄的舊安裝視為 zh-TW）；--lang 沒指定時沿用
resolve_installed_lang() {
  local am it
  installed_lang=""
  if [ -n "$agents_md" ]; then
    am="$agents_md"; case "$am" in "~"/*) am="$HOME/${am#\~/}" ;; esac
    [ -f "$am" ] && installed_lang="$(awk -v end="$END_LINE" '{ sub(/\r$/, "") } /^<!-- agent-agreements:start/ { on = 1; next } on && $0 == end { exit }
      on && /^<!-- agent-agreements:lang=[^ ]+ -->$/ { sub(/^<!-- agent-agreements:lang=/, ""); sub(/ -->$/, ""); print; exit }' "$am")"
  else
    it="${cursor_dir:-$target}"; case "$it" in "~"/*) it="$HOME/${it#\~/}" ;; esac
    [ -f "$it/$PROFILE_NAME" ] && installed_lang="$(sed -n 's/^lang=//p' "$it/$PROFILE_NAME" | head -n 1)"
  fi
  case "$installed_lang" in zh-TW|en) ;; *) installed_lang="" ;; esac
  [ -z "$lang_arg" ] && [ -n "$installed_lang" ] && use_lang "$installed_lang"
  return 0
}

# resolve_update_selection：--update 讀取既有安裝的選擇，之後當一般安裝處理
resolve_update_selection() {
  local up_target up_profile
  [ -z "$select_ids" ] || die "--update 不能搭配 --select（--update 會自動沿用既有安裝之規則選項）"
  if [ -n "$agents_md" ]; then
    case "$agents_md" in "~"/*) agents_md="$HOME/${agents_md#\~/}" ;; esac
    [ -f "$agents_md" ] || die "尚未安裝，無法更新（找不到 $agents_md）"
    select_ids="$(sed -n 's/<!-- agent-agreements:selected=\([^ ]*\) -->/\1/p' "$agents_md" | head -n 1)"
  else
    up_target="${cursor_dir:-$target}"
    case "$up_target" in "~"/*) up_target="$HOME/${up_target#\~/}" ;; esac
    up_profile="$up_target/$PROFILE_NAME"
    [ -f "$up_profile" ] || die "尚未安裝，無法更新（找不到 $up_profile）"
    select_ids="$(sed -n 's/^selected=//p' "$up_profile" | head -n 1)"
  fi
  mode="install"
}

# resolve_policy：--policy 指定，否則從目標往上找；找到後一併決定團隊守則目錄
resolve_policy() {
  local policy_from_cwd=0 sd p
  if [ -n "$policy_file" ]; then
    case "$policy_file" in "~"/*) policy_file="$HOME/${policy_file#\~/}" ;; esac
    [ -f "$policy_file" ] || die "找不到團隊策略檔：$policy_file"
    active_policy="$policy_file"
  else
    for sd in "${target:-}" "${cursor_dir:-}" "${agents_md:-}" .; do
      [ -z "$sd" ] && continue
      p="$(aw_find_policy "$sd" || true)"
      if [ -n "$p" ] && [ -f "$p" ]; then
        active_policy="$p"
        [ "$sd" = "." ] && policy_from_cwd=1
        break
      fi
    done
  fi
  # 策略檔是從目前目錄找到的（目標不在該專案內，例如全域安裝）：不帶入團隊守則，避免專案守則外洩到全域
  if [ -n "$active_policy" ] && [ "$policy_from_cwd" -eq 0 ]; then
    TEAM_RULES="$(aw_team_rules_dir "$active_policy")"
  fi
  return 0
}

# apply_policy_lang：策略檔指定語言時，優先於既有安裝記錄（--lang 仍然最優先）
apply_policy_lang() {
  local policy_lang
  [ -z "$lang_arg" ] && [ -n "$active_policy" ] || return 0
  policy_lang="$(aw_policy_lang "$active_policy")"
  if [ -n "$policy_lang" ] && [ "$policy_lang" != "$lang" ]; then
    use_lang "$policy_lang"
    echo "🌐 依據團隊策略檔（$(basename "$active_policy")）使用守則語言：${lang}"
  fi
}

# apply_policy_preset：未自訂 --select，且策略檔有指定 preset 時，依 preset 展開預設規則
apply_policy_preset() {
  local policy_preset id target_proj_dir detected
  [ -z "$select_ids" ] && [ -n "$active_policy" ] || return 0
  policy_preset="$(aw_policy_preset "$active_policy")"
  case "$policy_preset" in
    full)
      for id in $(all_ids); do
        [ "$(field "$RULES/$id.md" tier)" != "core" ] && ! is_deprecated "$id" && select_ids="${select_ids:+${select_ids},}$id"
      done
      echo "📋 依據團隊策略檔（$(basename "$active_policy")）套用方案：full（全套防禦）"
      ;;
    smart)
      # 偵測專案根目錄（策略檔所在目錄），不是安裝目錄（.claude/rules/…、.cursor/rules）或還不存在的 AGENTS.md
      target_proj_dir="$(dirname "$active_policy")"
      detected="$("$0" --detect "$target_proj_dir" 2>/dev/null | cut -f1 | tr '\n' ',' | sed 's/,$//' || true)"
      if [ -n "$detected" ]; then
        select_ids="$detected"
        echo "📋 依據團隊策略檔（$(basename "$active_policy")）套用方案：smart（智慧推薦：${detected}）"
      else
        echo "📋 依據團隊策略檔（$(basename "$active_policy")）套用方案：smart（智慧推薦：未偵測到特定依賴）"
      fi
      ;;
    core)
      echo "📋 依據團隊策略檔（$(basename "$active_policy")）套用方案：core（極簡核心）"
      ;;
  esac
  return 0
}

# add_selected_rules：--select（或 preset 展開）的守則加進 desired；淘汰守則照裝但警告
add_selected_rules() {
  local raw_id id
  [ -n "$select_ids" ] || return 0
  for raw_id in $(printf '%s' "$select_ids" | tr ',' ' '); do
    id="$(alias_id "$raw_id")"
    [ -f "$(src_of "$id")" ] || die "找不到規則：${raw_id}（用 --list 查看可用 id）"
    is_deprecated "$id" && echo "⚠️ 守則 ${id} $(deprecation_note "$id")" >&2
    contains "$desired" "$id" || desired="$desired$id"$'\n'
  done
}

# add_enforced_rules：策略檔的 enforce_rules 加進 desired；非 core 的內建守則一併記進 select_ids
add_enforced_rules() {
  local enforced enf_id id
  [ -n "$active_policy" ] || return 0
  enforced="$(aw_policy_enforce_rules "$active_policy")"
  [ -n "$enforced" ] || return 0
  for enf_id in $enforced; do
    id="$(alias_id "$enf_id")"
    case "$id" in
      custom/*)
        aw_is_team_name "${id#custom/}" || die "策略檔的強制規則名稱不合法：${enf_id}（custom/ 後面只能用小寫英數與連字號）"
        [ -f "$(src_of "$id")" ] || die "策略檔指定的強制規則不存在：${enf_id}（找不到團隊守則 .agreements/rules/${id#custom/}.md）" ;;
      *) [ -f "$RULES/$id.md" ] || die "策略檔指定的強制規則不存在：${enf_id}" ;;
    esac
    contains "$desired" "$id" || desired="$desired$id"$'\n'
    # 團隊守則每次都會從 .agreements/rules 帶入，不記進 selected
    case "$id" in custom/*) continue ;; esac
    if [ "$(field "$RULES/$id.md" tier)" != "core" ]; then
      if [ -z "$select_ids" ]; then
        select_ids="$id"
      elif ! printf '%s' ",$select_ids," | grep -q ",$id,"; then
        select_ids="${select_ids},${id}"
      fi
    fi
  done
  echo "🔒 依據團隊策略檔（$(basename "$active_policy")）強制套用守則：$(printf '%s ' $enforced)"
}

# resolve_desired：期望安裝的規則：core 全部 ＋ 團隊守則 ＋ 選擇的 optional ＋ 策略檔強制守則（排序、一行一個）
resolve_desired() {
  local id team
  desired=""
  for id in $(all_ids); do
    [ "$(field "$RULES/$id.md" tier)" = "core" ] && desired="$desired$id"$'\n'
  done
  team="$(team_ids)"
  for id in $team; do desired="$desired$id"$'\n'; done
  [ -n "$team" ] && echo "👥 團隊守則（$(printf '%s\n' "$team" | grep -c .) 個）：$(printf '%s ' $team)"

  apply_policy_lang
  apply_policy_preset
  add_selected_rules
  add_enforced_rules
  desired="$(printf '%s' "$desired" | sed '/^$/d' | sort)"
}
