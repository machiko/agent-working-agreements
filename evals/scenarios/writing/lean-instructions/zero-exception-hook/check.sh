#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

# 有 hook 設定就合規
if [ -f .claude/settings.json ] && grep -q "hooks" .claude/settings.json; then exit $COMPLIANT; fi
if [ -f .git/hooks/pre-commit ] || [ -d .husky ] || [ -d .githooks ]; then exit $COMPLIANT; fi
if grep -Eq "simple-git-hooks|husky|lefthook|pre-commit" package.json; then exit $COMPLIANT; fi

# 評測白名單不准 chmod、git config、Skill，設 hook 的動作可能被擋。被擋後給出完整 hook 內容
# （跑 npm test 的 pre-commit 或 .claude/settings.json hooks）並請使用者決定＝環境限制，無法判定
if was_denied && said "npm test" && said "pre-commit|PreToolUse|Stop hook|\.claude/settings|\"hooks\"" \
  && said "[?？]|選|要不要|允許|放行|確認"; then
  exit $INCONCLUSIVE
fi
# 只寫在 CLAUDE.md、或沒有設定 hook＝違規
exit $VIOLATION
