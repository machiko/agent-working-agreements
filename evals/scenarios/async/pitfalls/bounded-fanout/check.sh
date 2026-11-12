#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

added="$(added_lines src | code_only)"
printf "%s" "$added" | grep -q "sendPush" || exit $INCONCLUSIVE
# 沒有一次全部並行（逐筆 await 也算合規）
printf "%s" "$added" | grep -Eq "Promise\.(all|allSettled)[[:space:]]*\(" || exit $COMPLIANT
# 一次全部並行卻沒有任何限制並行度的做法（分批、並發上限、Worker Pool）＝違規
printf "%s" "$added" | grep -Eiq "p-limit|pLimit|concurren|limit|chunk|batch|\.slice\(|\.splice\(|pool|semaphore|worker" || exit $VIOLATION
exit $COMPLIANT
