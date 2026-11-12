#!/usr/bin/env bash
# hook-guard.sh — Claude Code PreToolUse 執行期防線入口，以及跨工具 Git hook 安裝器。
#
# 用法：
#   hook-guard.sh                         # 由 hooks/hooks.json 呼叫，stdin 為 PreToolUse JSON
#   hook-guard.sh --install-git-hooks [目錄] # 安裝 Git pre-push（擋 force push）與 pre-commit（稽核）
#
# 攔截規則在 lib/guard-rules.tsv；有 python3 時交給 hook-guard.py 比對，否則用同一份規則走 bash fallback。
# 團隊攔截規則放在策略檔旁的 .agreements/guard-rules.tsv，內建規則之後比對，只能多擋、不能放寬。
# 停用開關 AGREEMENTS_HOOKS_DISABLE=1；團隊策略檔設 "prohibit_disable_hooks": true 時開關失效。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULES_FILE="$ROOT/scripts/lib/guard-rules.tsv"
# shellcheck source=lib/policy.sh
. "$ROOT/scripts/lib/policy.sh"

# ── Git hooks 安裝模式（實際寫入由 audit.sh 負責，以便處理 worktree、core.hooksPath 與既有 hook）──
if [ "${1:-}" = "--install-git-hooks" ]; then
  target_dir="${2:-.}"
  case "$target_dir" in "~"/*) target_dir="$HOME/${target_dir#\~/}" ;; esac
  [ -d "$target_dir" ] || { echo "✗ 目錄不存在：$target_dir" >&2; exit 1; }
  cd "$target_dir"
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "✗ 不是 git repo：$target_dir" >&2; exit 1; }
  bash "$ROOT/scripts/audit.sh" --install-pre-push
  bash "$ROOT/scripts/audit.sh" --install-hook
  exit 0
fi

INPUT="$(cat)"
[ -n "$INPUT" ] || exit 0

# ── 團隊策略檔：從 Agent 的 cwd 往上找 ─────────────────
start_dir="$(printf '%s' "$INPUT" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
[ -n "$start_dir" ] && [ -d "$start_dir" ] || start_dir="$PWD"
policy="$(aw_find_policy "$start_dir" || true)"

# ── 停用開關與團隊策略鎖定 ─────────────────────────────
if [ -n "${AGREEMENTS_HOOKS_DISABLE:-}" ] && [ "$AGREEMENTS_HOOKS_DISABLE" != "0" ]; then
  if [ -z "$policy" ] || ! aw_policy_prohibits_disable "$policy"; then
    exit 0
  fi
fi

# 團隊攔截規則（策略檔旁的 .agreements/guard-rules.tsv）：內建規則之後再比對，只能多擋
TEAM_RULES="$(aw_team_guard_file "$policy")"

if [ -z "${AGREEMENTS_HOOK_FORCE_BASH:-}" ] && command -v python3 >/dev/null 2>&1; then
  set --
  [ -n "$TEAM_RULES" ] && set -- --team "$TEAM_RULES"
  if py_out="$(printf '%s' "$INPUT" | python3 "$ROOT/scripts/hook-guard.py" "$@")"; then
    [ -n "$py_out" ] && printf '%s\n' "$py_out"
    exit 0
  fi
  echo "⚠ [agent-agreements] hook-guard.py 執行失敗，改用 bash 比對" >&2
fi

# ── Fallback：沒有 python3（或 python 失敗）時，以同一份規則比對 JSON 字串 ──
# 只取 "command" 之後的內容並還原跳脫字元；不解析 JSON，同一行其他欄位的文字也可能被比對到。
printf '%s' "$INPUT" | grep -qE '"tool_name"[[:space:]]*:[[:space:]]*"Bash"' || exit 0

event="$(printf '%s' "$INPUT" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
segments="$(printf '%s\n' "$INPUT" | sed 's/^.*"command"[[:space:]]*:[[:space:]]*"//' | awk '{
  gsub(/\\\\/, "\001"); gsub(/\\"/, "\""); gsub(/\\n/, "\n"); gsub(/\\t/, "\t"); gsub(/\001/, "\\")
  gsub(/&&|\|\||;/, "\n"); print }')"

expand() {
  local p="$1"
  p="${p//\{S\}/[[:blank:]]}"
  p="${p//\{NS\}/[^[:blank:]\"\']}"
  p="${p//\{E\}/([^A-Za-z0-9_=./-]|\$)}"
  printf '%s' "$p"
}

# check_rules <規則檔> <標籤>：命中就輸出 deny 並結束。
# 團隊規則寫錯（缺欄位、正規表示式無法編譯、連空字串都命中）時跳過那一行並警告，不讓一行錯誤擋掉所有指令。
check_rules() {
  local file="$1" kind="$2" lineno=0 rule pattern message allow extra hit reason rc
  while IFS=$'\t' read -r rule pattern message allow extra || [ -n "$rule" ]; do
    lineno=$((lineno + 1))
    case "$rule" in ''|'#'*) continue ;; esac
    if [ -z "$pattern" ] || [ -z "$message" ] || [ -n "${extra:-}" ]; then
      echo "⚠ [agent-agreements] 略過${kind}攔截規則 ${file}:${lineno}：欄位不完整或超過 4 欄" >&2; continue
    fi
    pattern="$(expand "$pattern")"
    rc=0; printf '\n' | grep -qE -- "$pattern" 2>/dev/null || rc=$?
    if [ "$rc" -ne 1 ]; then
      echo "⚠ [agent-agreements] 略過${kind}攔截規則 ${file}:${lineno}：攔截式無法編譯，或連空字串都會命中" >&2; continue
    fi
    hit="$(printf '%s\n' "$segments" | grep -E -- "$pattern" || true)"
    [ -n "$hit" ] || continue
    if [ -n "${allow:-}" ]; then
      hit="$(printf '%s\n' "$hit" | grep -vE -- "$(expand "$allow")" || true)"
      [ -n "$hit" ] || continue
    fi
    reason="🛡️ 觸發 ${rule} ${kind}攔截：${message}"
    printf '{"hookSpecificOutput": {"hookEventName": "%s", "permissionDecision": "deny", "permissionDecisionReason": "%s"}, "systemMessage": "%s"}\n' \
      "${event:-PreToolUse}" "$reason" "$reason"
    exit 0
  done < "$file"
}

check_rules "$RULES_FILE" "守則"
[ -n "$TEAM_RULES" ] && check_rules "$TEAM_RULES" "團隊規則"

exit 0
