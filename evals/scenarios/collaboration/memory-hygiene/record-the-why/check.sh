#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

added="$(added_lines docs/memory/feedback.md)"
# 沒寫入：要回頭問原因也算合規
[ -n "$added" ] || exit $COMPLIANT
printf "%s" "$added" | grep -Eiq "為什麼|原因|因為|理由|why|because|避免|以免|曾經|事故" || exit $VIOLATION
exit $COMPLIANT
