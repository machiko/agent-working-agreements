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

# aw_ancestors <起點>：由近到遠印出要搜尋的目錄，到 git root 為止；
# 不在 git repo 內時不含 $HOME 與 /
aw_ancestors() {
  local cur git_root home_abs
  cur="$(aw_nearest_existing_dir "${1:-.}")" || return 0
  [ -n "$cur" ] || return 0
  git_root="$(cd "$cur" && git rev-parse --show-toplevel 2>/dev/null || true)"
  home_abs="$(cd "$HOME" 2>/dev/null && pwd -P || echo "$HOME")"
  while [ -n "$cur" ]; do
    if [ -z "$git_root" ] && { [ "$cur" = "$home_abs" ] || [ "$cur" = "/" ]; }; then
      return 0
    fi
    echo "$cur" || return 0
    [ "$cur" = "$git_root" ] && return 0
    [ "$cur" = "/" ] && return 0
    cur="$(dirname "$cur")"
  done
}

# aw_find_policy <起點>：找到就印出策略檔路徑並回傳 0，否則回傳 1
aw_find_policy() {
  local d dirs
  # 先收齊再比對，不用 < <(aw_ancestors)：找到就 return 會關掉讀取端，寫入端再 echo 就遇到 Broken pipe。
  # GitHub macOS runner 忽略 SIGPIPE，寫入端因此停不下來、持續洗版，CI 整個卡住。
  dirs="$(aw_ancestors "${1:-.}")"
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    if [ -f "$d/.agreements.json" ]; then echo "$d/.agreements.json"; return 0; fi
    if [ -f "$d/.agreementsrc" ]; then echo "$d/.agreementsrc"; return 0; fi
  done <<< "$dirs"
  return 1
}

# aw_team_rules_dir <策略檔>：印出團隊守則目錄（策略檔旁的 .agreements/rules）；不存在就不印
aw_team_rules_dir() {
  local d
  [ -n "${1:-}" ] || return 0
  d="$(dirname "$1")/.agreements/rules"
  [ -d "$d" ] && (cd "$d" && pwd -P)
  return 0
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

# aw_policy_get <策略檔> <欄位>：通用讀取。字串直接印；布林印 true／false；字串陣列每行印一個。
# 沒有 python3 時只支援字串、布林與單層字串陣列。
aw_policy_get() {
  local pfile="$1" key="$2" flat
  [ -f "$pfile" ] || return 0
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$pfile" "$key" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        d = json.load(f)
except Exception:
    sys.exit(0)
v = d.get(sys.argv[2]) if isinstance(d, dict) else None
if isinstance(v, bool):
    print("true" if v else "false")
elif isinstance(v, str):
    print(v.strip())
elif isinstance(v, list):
    for x in v:
        if isinstance(x, str) and x.strip():
            print(x.strip())
PY
  else
    flat="$({ tr '\n' ' ' < "$pfile"; echo; })"
    if printf '%s\n' "$flat" | grep -qE "\"$key\"[[:space:]]*:[[:space:]]*\["; then
      printf '%s\n' "$flat" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p" \
        | tr ',' '\n' | sed -n 's/^[[:space:]]*"\([^"]*\)"[[:space:]]*$/\1/p'
    else
      printf '%s\n' "$flat" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p;s/.*\"$key\"[[:space:]]*:[[:space:]]*true.*/true/p;s/.*\"$key\"[[:space:]]*:[[:space:]]*false.*/false/p" | sed -n 1p
    fi
  fi
}

# aw_policy_targets <策略檔>：每行印一個合法的安裝目標（claude、cursor、agents-md、copilot、windsurf）
aw_policy_targets() {
  aw_policy_get "$1" targets | while IFS= read -r t; do
    case "$t" in claude|cursor|agents-md|copilot|windsurf) echo "$t" ;; esac
  done
}

# aw_target_path <目標>：安裝目標相對於專案根目錄的路徑
aw_target_path() {
  case "$1" in
    claude) echo ".claude/rules/agent-agreements" ;;
    cursor) echo ".cursor/rules" ;;
    agents-md) echo "AGENTS.md" ;;
    copilot) echo ".github/copilot-instructions.md" ;;
    windsurf) echo ".windsurfrules" ;;
  esac
}

# aw_target_flag <目標>：install.sh 對應的參數
aw_target_flag() {
  case "$1" in
    claude) echo "--target" ;;
    *) echo "--$1" ;;
  esac
}

# aw_is_team_name <name>：團隊守則名稱只能是小寫英數與連字號（防止 custom/../.. 之類的路徑穿越）
aw_is_team_name() {
  printf '%s' "$1" | grep -Eq '^[a-z0-9][a-z0-9-]*$'
}

# aw_team_rule_ids <團隊守則目錄>：每行印一個 custom/<name>（排序）；README.md 略過，不合法的檔名警告後略過
aw_team_rule_ids() {
  local f n
  [ -n "${1:-}" ] && [ -d "$1" ] || return 0
  for f in "$1"/*.md; do
    [ -f "$f" ] || continue
    n="$(basename "$f" .md)"
    case "$n" in README|readme|Readme) continue ;; esac
    if aw_is_team_name "$n"; then
      echo "custom/$n"
    else
      echo "⚠️ 略過團隊守則 ${f}：檔名只能用小寫英數與連字號" >&2
    fi
  done | sort
}
