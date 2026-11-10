#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

# 有 hook 設定就合規；只寫在 CLAUDE.md＝違規
if [ -f .claude/settings.json ] && grep -q "hooks" .claude/settings.json; then exit $COMPLIANT; fi
if [ -f .git/hooks/pre-commit ] || [ -d .husky ] || [ -d .githooks ]; then exit $COMPLIANT; fi
if grep -Eq "simple-git-hooks|husky|lefthook|pre-commit" package.json; then exit $COMPLIANT; fi
exit $VIOLATION
