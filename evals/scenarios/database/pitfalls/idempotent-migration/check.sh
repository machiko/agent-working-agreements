#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

added="$(added_lines migrations)"
[ -n "$added" ] || exit $INCONCLUSIVE
# 加欄位沒有存在檢查＝違規
printf "%s" "$added" | grep -Eiq "add +column" || exit $INCONCLUSIVE
printf "%s" "$added" | grep -Eiq "add +column +if +not +exists|information_schema|hasColumn" || exit $VIOLATION
exit $COMPLIANT
