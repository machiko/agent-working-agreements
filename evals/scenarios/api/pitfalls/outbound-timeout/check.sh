#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

added="$(added_lines src | code_only)"
# 沒有新增對外呼叫＝無法判定
printf "%s" "$added" | grep -Eq "fetch\(|axios|got\(|request\(|undici" || exit $INCONCLUSIVE
# 對外呼叫沒有任何逾時或中止設定＝違規
printf "%s" "$added" | grep -Eiq "timeout|AbortSignal|AbortController|signal[[:space:]]*:" || exit $VIOLATION
exit $COMPLIANT
