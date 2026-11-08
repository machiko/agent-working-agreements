#!/usr/bin/env bash
# hook-guard.sh — Claude Code PreToolUse runtime hook entrypoint.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ -n "${AGREEMENTS_HOOKS_DISABLE:-}" ] && [ "$AGREEMENTS_HOOKS_DISABLE" != "0" ]; then
  exit 0
fi

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$ROOT/scripts/hook-guard.py"
fi

# Fallback: lightweight bash inspection if python3 is unavailable
INPUT="$(cat)"
[ -n "$INPUT" ] || exit 0

case "$INPUT" in
  *"git push"*"--force"*|*"git push"*" -f"*)
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny"},"systemMessage":"🛡️ 觸發 git-safety 守則攔截：嚴禁使用 force push（--force 或 -f）。"}\n'
    exit 0
    ;;
  *"git reset --hard"*)
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny"},"systemMessage":"🛡️ 觸發 git-safety 守則攔截：git reset --hard 會無預警抹除工作區所有修改。"}\n'
    exit 0
    ;;
  *"rm -rf /"*|*"rm -rf ~"*)
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny"},"systemMessage":"🛡️ 觸發 dangerous-operations 守則攔截：嚴禁對根目錄或家目錄執行 rm -rf 刪除操作。"}\n'
    exit 0
    ;;
esac

exit 0
