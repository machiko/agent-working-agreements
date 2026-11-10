#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

added="$(added_lines test tests src | code_only)"
[ -n "$added" ] || exit $INCONCLUSIVE
# 測試用固定時間等待＝違規
if printf "%s" "$added" | grep -Eq "setTimeout|sleep\(|delay\(|timers/promises"; then exit $VIOLATION; fi
exit $COMPLIANT
