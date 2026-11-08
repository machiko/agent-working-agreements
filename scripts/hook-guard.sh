#!/usr/bin/env bash
# hook-guard.sh — Claude Code PreToolUse runtime hook entrypoint & Universal Git Hook installer.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── Universal Git Hooks 安裝模式 ────────────────────────
if [ "${1:-}" = "--install-git-hooks" ]; then
  target_dir="${2:-.}"
  case "$target_dir" in "~"/*) target_dir="$HOME/${target_dir#\~/}" ;; esac
  git_dir="$(cd "$target_dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || echo "$target_dir")"
  HOOK_DIR="$git_dir/.git/hooks"
  [ -d "$HOOK_DIR" ] || { echo "✗ 找不到 .git/hooks 目錄：$HOOK_DIR" >&2; exit 1; }

  # 1. 安裝 pre-push (防 Force Push)
  PRE_PUSH="$HOOK_DIR/pre-push"
  cat <<'EOF' > "$PRE_PUSH"
#!/usr/bin/env bash
# 由 agent-working-agreements 安裝的 pre-push 守門防線
# 嚴禁對任何遠端分支進行非 fast-forward 的 force push
set -euo pipefail

if [ -n "${AGREEMENTS_HOOKS_DISABLE:-}" ] && [ "$AGREEMENTS_HOOKS_DISABLE" != "0" ]; then
  exit 0
fi

while read -r local_ref local_sha remote_ref remote_sha || [ -n "${local_ref:-}" ]; do
  [ -z "${local_ref:-}" ] && continue
  [ "${local_sha:-}" = "0000000000000000000000000000000000000000" ] && continue

  if [ -n "${remote_sha:-}" ] && [ "$remote_sha" != "0000000000000000000000000000000000000000" ]; then
    if ! git merge-base --is-ancestor "$remote_sha" "$local_sha" 2>/dev/null; then
      echo "🛑 [agent-agreements] 觸發 git-safety 守則攔截：偵測到非快進 (Force Push) 覆蓋遠端分支 ${remote_ref:-}！" >&2
      echo "💡 如確需覆蓋請確認團隊協議或設定 AGREEMENTS_HOOKS_DISABLE=1 後再重試。" >&2
      exit 1
    fi
  fi
done

exit 0
EOF
  chmod +x "$PRE_PUSH"
  echo "✓ 已成功安裝 pre-push hook (防 Force Push)：$PRE_PUSH"

  # 2. 同步安裝 pre-commit 主動稽核防線
  if [ -f "$ROOT/scripts/audit.sh" ]; then
    (cd "$git_dir" && bash "$ROOT/scripts/audit.sh" --install-hook >/dev/null 2>&1) || true
    echo "✓ 已成功安裝 pre-commit hook (程式碼稽核)：$HOOK_DIR/pre-commit"
  fi

  exit 0
fi

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
