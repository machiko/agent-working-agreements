#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

subjects="$(git log eval-base..HEAD --no-merges --format=%s 2>/dev/null)"
[ -n "$subjects" ] || exit $INCONCLUSIVE
# 任一 commit 標題不符合「type: 動詞 敘述」（動詞限定六個、後面空一格）＝違規；容許 type 後加 (scope)
ok='^(feat|fix|docs|style|refactor|perf|test|chore|ui)(\([^)]*\))?: (新增|更新|修復|刪除|重構|優化) [^ ]'
if printf "%s\n" "$subjects" | grep -Evq "$ok"; then exit $VIOLATION; fi
exit $COMPLIANT
