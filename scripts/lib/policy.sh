#!/usr/bin/env bash
# policy.sh — 團隊策略檔（.agreements.json／.agreementsrc）的搜尋與解析，供 install.sh、doctor.sh、hook-guard.sh 共用。
#
# 搜尋規則：從起點（不存在就往上取最近一層存在的目錄）逐層往上找，
# 找到 git root 就停；不在 git repo 內時，不讀 $HOME 與 / 本身，避免全域安裝誤讀家目錄的策略檔。
# 這支只定義函式，用 source 載入。

# aw_nearest_existing_dir <path>：印出 path 本身或最近一層存在的父目錄（絕對路徑）
aw_nearest_existing_dir() {
  local p="$1"
  case "$p" in "~") p="$HOME" ;; "~"/*) p="$HOME/${p#\~/}" ;; esac
  [ -f "$p" ] && p="$(dirname "$p")"
  while [ -n "$p" ] && [ ! -d "$p" ]; do
    p="$(dirname "$p")"
  done
  (cd "$p" 2>/dev/null && pwd -P)
}

# aw_find_policy <起點>：找到就印出策略檔路徑並回傳 0，否則回傳 1
aw_find_policy() {
  local cur git_root home_abs
  cur="$(aw_nearest_existing_dir "${1:-.}")" || return 1
  [ -n "$cur" ] || return 1
  git_root="$(cd "$cur" && git rev-parse --show-toplevel 2>/dev/null || true)"
  home_abs="$(cd "$HOME" 2>/dev/null && pwd -P || echo "$HOME")"
  while [ -n "$cur" ]; do
    if [ -z "$git_root" ] && { [ "$cur" = "$home_abs" ] || [ "$cur" = "/" ]; }; then
      return 1
    fi
    if [ -f "$cur/.agreements.json" ]; then echo "$cur/.agreements.json"; return 0; fi
    if [ -f "$cur/.agreementsrc" ]; then echo "$cur/.agreementsrc"; return 0; fi
    [ "$cur" = "$git_root" ] && return 1
    [ "$cur" = "/" ] && return 1
    cur="$(dirname "$cur")"
  done
  return 1
}

# aw_policy_preset <策略檔>：印出 preset 值（smart、full、core 之一），無或非合法值則回傳空字串
aw_policy_preset() {
  local pfile="$1"
  [ -f "$pfile" ] || return 0
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$pfile" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        d = json.load(f)
except Exception:
    sys.exit(0)
preset = d.get("preset", "") if isinstance(d, dict) else ""
if preset in ("smart", "full", "core"):
    print(preset)
PY
  else
    local val
    val="$(sed -n 's/.*"preset"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p;q' "$pfile")"
    case "$val" in
      smart|full|core) echo "$val" ;;
    esac
  fi
}

# aw_policy_lang <策略檔>：印出 lang 值（en、zh-TW 之一），無或非合法值則回傳空字串
aw_policy_lang() {
  local pfile="$1" val
  [ -f "$pfile" ] || return 0
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$pfile" <<'PY2'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        d = json.load(f)
except Exception:
    sys.exit(0)
lang = d.get("lang", "") if isinstance(d, dict) else ""
if lang in ("en", "zh-TW"):
    print(lang)
PY2
  else
    val="$({ tr '\n' ' ' < "$pfile"; echo; } | sed -n 's/.*"lang"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
    case "$val" in
      en|zh-TW) echo "$val" ;;
    esac
  fi
}

# aw_policy_enforce_rules <策略檔>：每行印一個 enforce_rules 的規則 id
aw_policy_enforce_rules() {
  local pfile="$1"
  [ -f "$pfile" ] || return 0
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$pfile" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        d = json.load(f)
except Exception:
    sys.exit(0)
rules = d.get("enforce_rules", []) if isinstance(d, dict) else []
for r in rules if isinstance(rules, list) else []:
    if isinstance(r, str) and r.strip():
        print(r.strip())
PY
  else
    # 沒有 python3：取出 enforce_rules 陣列（可跨行）後逐一拆出字串
    { tr '\n' ' ' < "$pfile"; echo; } \
      | sed -n 's/.*"enforce_rules"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' \
      | tr ',' '\n' \
      | sed -n 's/^[[:space:]]*"\([^"]*\)"[[:space:]]*$/\1/p'
  fi
}

# aw_policy_prohibits_disable <策略檔>：策略要求鎖定停用開關就回傳 0。
# 只有 JSON 的 true 才算鎖定；檔案存在卻無法解析成物件時，採安全預設（視為鎖定）並警告。
aw_policy_prohibits_disable() {
  local pfile="$1" verdict
  [ -f "$pfile" ] || return 1
  if command -v python3 >/dev/null 2>&1; then
    verdict="$(python3 - "$pfile" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        d = json.load(f)
except Exception:
    print("invalid"); sys.exit(0)
if not isinstance(d, dict):
    print("invalid")
elif d.get("prohibit_disable_hooks") is True:
    print("lock")
else:
    print("open")
PY
)"
  else
    # 沒有 python3 只能粗判：最外層不是 { 開頭就視為無法解析
    if [ "$(tr -d ' \t\r\n' < "$pfile" | cut -c1)" != "{" ]; then
      verdict="invalid"
    elif tr '\n' ' ' < "$pfile" | grep -qE '"prohibit_disable_hooks"[[:space:]]*:[[:space:]]*true([^A-Za-z0-9_]|$)'; then
      verdict="lock"
    else
      verdict="open"
    fi
  fi
  case "$verdict" in
    lock) return 0 ;;
    invalid)
      echo "⚠ [agent-agreements] 策略檔無法解析為 JSON 物件：${pfile}；為安全起見忽略 AGREEMENTS_HOOKS_DISABLE" >&2
      return 0 ;;
    *) return 1 ;;
  esac
}
