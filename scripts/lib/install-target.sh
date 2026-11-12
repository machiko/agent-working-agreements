#!/usr/bin/env bash
# install-target.sh — install.sh 寫入規則目錄的目標（--target 的 .md、--cursor 的 .mdc）：
# 依 profile（.agreements-profile）記錄的雜湊新增、更新、移除檔案，也負責這類目標的 --status。
#
# 讀寫呼叫端的全域變數：target、cursor_dir、PROFILE_NAME、mode、desired、installed_lang、select_ids、
# active_policy、lang、dry_run、force。
# 依賴 rules.sh、install-report.sh。這支只定義函式，用 source 載入。

# 產出 Cursor IDE 規範的 .mdc 規則內容
cursor_content() {
  local src="$1" desc
  desc="$(field "$src" label | unquote)"
  [ -z "$desc" ] && desc="$(title "$src")"
  echo "---"
  echo "description: \"$desc\""
  if has_paths "$src"; then
    echo "globs:"
    awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit }
         /^(paths|globs):/ { on = 1; next } on && /^[ ]+- / { print; next }
         on { on = 0 }' "$src"
    echo "alwaysApply: false"
  else
    echo "alwaysApply: true"
  fi
  echo "---"
  echo
  strip_body "$src"
}

# target_setup：決定 target、profile、is_cursor、ext 與已安裝的規則（installed）
target_setup() {
  is_cursor=0
  ext="md"
  if [ -n "$cursor_dir" ]; then
    target="$cursor_dir"
    is_cursor=1
    ext="mdc"
  fi

  case "$target" in "~"/*) target="$HOME/${target#\~/}" ;; esac
  profile="$target/$PROFILE_NAME"

  if [ -f "$profile" ] && grep -q '^format=cursor$' "$profile"; then
    is_cursor=1
    ext="mdc"
  fi

  # 已安裝的規則與記錄的雜湊（profile 每行：file=<id> sha256=<hash>）
  installed=""
  [ -f "$profile" ] && installed="$(sed -n 's/^file=\([^ ]*\) sha256=.*/\1/p' "$profile" | sort)"
  return 0
}

recorded_sha() { sed -n "s#^file=$1 sha256=\\(.*\\)#\\1#p" "$profile" 2>/dev/null; }

is_modified() {
  local dest="$target/$1.$ext" rec
  [ -f "$dest" ] || return 1
  rec="$(recorded_sha "$1")"
  [ -n "$rec" ] && [ "$(sha "$dest")" != "$rec" ]
}

# expected_sha <來源>：安裝後檔案應有的雜湊（Cursor 要先轉成 .mdc 內容）
expected_sha() {
  if [ "$is_cursor" -eq 1 ]; then
    cursor_content "$1" | sha
  else
    sha "$1"
  fi
}

# target_status：唯讀，比對 profile 記錄、目標檔案與目前來源
target_status() {
  local installed_v schema_v policy_v
  if [ ! -f "$profile" ]; then
    echo "尚未安裝：${target} 沒有 ${PROFILE_NAME}"
    return 0
  fi
  installed_v="$(sed -n 's/^version=//p' "$profile" | head -n 1)"
  schema_v="$(sed -n 's/^schema_version=//p' "$profile" | head -n 1)"
  policy_v="$(sed -n 's/^policy=//p' "$profile" | head -n 1)"
  echo "安裝位置：${target}"
  echo "安裝版本：${installed_v:-未記錄}｜目前版本：$(version)"
  echo "守則語言：${installed_lang:-zh-TW}"
  [ -n "$schema_v" ] && echo "規範結構：Schema v${schema_v}"
  [ -n "$policy_v" ] && echo "團隊策略：${policy_v}"
  for id in $installed; do
    src="$(src_of "$id")"; dest="$target/$id.$ext"; rec="$(recorded_sha "$id")"
    if [ ! -f "$dest" ]; then st="檔案遺失"
    elif [ "$(sha "$dest")" != "$rec" ]; then st="已手動修改"
    elif [ ! -f "$src" ]; then st="來源已移除"
    else
      if [ "$rec" != "$(expected_sha "$src")" ]; then st="有新版"
      else st="最新"; fi
    fi
    # 標題與 paths 以實際載入的檔案為準；檔案遺失時退回來源，且不計入行數
    info="$dest"; lines=0
    if [ -f "$dest" ]; then lines="$(body_lines "$dest")"; else info="$src"; fi
    t=""; [ -f "$info" ] && t="$(title "$info")"
    rule_record "$id" "$t" "$info" "$st" "$lines"
  done | report_status
}

record() { new_profile="${new_profile}file=$1 sha256=$2"$'\n'; }

act() {  # act <符號> <動作> <id>
  printf '%s %s %s\n' "$1" "$2" "$(with_title "$3" "$3.$ext")"
  changes=$((changes + 1))
}

# target_remove_stale：移除不再需要的（uninstall 時全部移除）；手動修改過的沒有 --force 就保留
target_remove_stale() {
  local id
  for id in $installed; do
    if [ "$mode" = "install" ] && contains "$desired" "$id"; then continue; fi
    if is_modified "$id" && [ "$force" -eq 0 ]; then
      echo "！ 保留（已被手動修改，加 --force 才移除）$(with_title "$id" "$id.$ext")"
      record "$id" "$(recorded_sha "$id")"
      continue
    fi
    act "－" "移除" "$id"
    if [ "$dry_run" -eq 0 ]; then
      rm -f "$target/$id.$ext"
      rmdir "$(dirname "$target/$id.$ext")" 2>/dev/null || true
    fi
  done
}

# target_write_rule <id> <來源> <目的地> <來源雜湊>：記錄並（非 dry-run 時）寫入一條規則
target_write_rule() {
  if [ "$dry_run" -eq 0 ]; then
    mkdir -p "$(dirname "$3")"
    if [ "$is_cursor" -eq 1 ]; then
      rm -f "$3"
      cursor_content "$2" > "$3"
    else
      # 不用 cp：來源唯讀（例如唯讀的 plugin 快取）時 cp 會連權限一起複製，之後就無法更新
      rm -f "$3"
      cat "$2" > "$3"
    fi
  fi
  record "$1" "$4"
}

# target_add_or_update：新增或更新 desired 的規則，設定 unchanged、kept_modified
target_add_or_update() {
  local id src dest src_sha
  unchanged=0
  kept_modified=0
  for id in $desired; do
    src="$(src_of "$id")"
    dest="$target/$id.$ext"
    src_sha="$(expected_sha "$src")"

    if contains "$installed" "$id"; then
      if is_modified "$id" && [ "$force" -eq 0 ]; then
        echo "！ 保留（已被手動修改，加 --force 才覆蓋）$(with_title "$id" "$id.$ext")"
        kept_modified=$((kept_modified + 1))
        record "$id" "$(recorded_sha "$id")"
        continue
      fi
      if [ -f "$dest" ] && [ "$(sha "$dest")" = "$src_sha" ]; then
        unchanged=$((unchanged + 1))
        record "$id" "$src_sha"
        continue
      fi
      act "↻" "更新" "$id"
    else
      if [ -f "$dest" ] && [ "$force" -eq 0 ] && [ "$(sha "$dest")" != "$src_sha" ]; then
        echo "！ 略過（目標已有同名檔案且非本工具安裝，加 --force 才覆蓋）$(with_title "$id" "$id.$ext")"
        continue
      fi
      act "＋" "新增" "$id"
    fi
    target_write_rule "$id" "$src" "$dest" "$src_sha"
  done
}

# target_summary：印出變更摘要與常駐（沒有 paths）／按需載入的本文行數
target_summary() {
  local id n always=0 ondemand=0
  for id in $desired; do
    n="$(body_lines "$(src_of "$id")")"
    if has_paths "$(src_of "$id")"; then ondemand=$((ondemand + n)); else always=$((always + n)); fi
  done

  echo "──"
  [ "$unchanged" -gt 0 ] && echo "＝ 不變 $unchanged 個"
  [ "$changes" -eq 0 ] && echo "（沒有需要變更的檔案）"
  if [ "$mode" = "install" ]; then
    echo "常駐：${always} 行｜按需載入：${ondemand} 行｜共 $(printf '%s\n' "$desired" | grep -c .) 個規則"
  fi
  return 0
}

# target_write_profile：寫入 profile；沒有任何記錄時移除 profile 與空的目標目錄
target_write_profile() {
  if [ -z "$new_profile" ]; then
    rm -f "$profile"
    rmdir "$target" 2>/dev/null || true
    echo "✓ 已移除"
    return 0
  fi
  mkdir -p "$target"
  {
    echo "# agent-working-agreements 安裝紀錄（由 install.sh 維護，請勿手動編輯）"
    echo "schema_version=1"
    echo "version=$(version)"
    [ "$is_cursor" -eq 1 ] && echo "format=cursor"
    [ -n "$active_policy" ] && echo "policy=$(basename "$active_policy")"
    echo "selected=$(printf '%s' "$select_ids" | tr -d ' ')"
    echo "lang=${lang}"
    printf '%s' "$new_profile"
  } > "$profile"
  echo "✓ 完成：$target"
}

# install_target：安裝、更新、移除或查詢規則目錄，完成後以結束碼 0 結束
install_target() {
  target_setup

  if [ "$mode" = "status" ]; then
    target_status
    exit 0
  fi

  new_profile=""
  changes=0
  target_remove_stale
  target_add_or_update
  target_summary

  if [ "$dry_run" -eq 1 ]; then
    echo "（dry-run：未寫入任何檔案）"
    exit 0
  fi

  if [ "$kept_modified" -gt 0 ] && [ -n "$installed" ] && [ "${installed_lang:-zh-TW}" != "$lang" ]; then
    echo "⚠️ 守則語言從 ${installed_lang:-zh-TW} 換成 ${lang}，但有 ${kept_modified} 個手動修改過的檔案保留原語言；要一起換成 ${lang} 請加 --force" >&2
  fi

  target_write_profile
  exit 0
}
