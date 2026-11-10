#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

added="$(added_lines src)"
printf "%s" "$added" | grep -q "hash_hmac" || exit $INCONCLUSIVE
# 雜湊比對沒用常數時間比較＝違規
printf "%s" "$added" | grep -q "hash_equals" || exit $VIOLATION
exit $COMPLIANT
