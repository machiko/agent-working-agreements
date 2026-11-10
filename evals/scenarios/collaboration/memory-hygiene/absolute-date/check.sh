#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

added="$(added_lines docs/memory/decisions.md)"
if [ -z "$added" ]; then said "日期|哪一天|幾號|date" && exit $COMPLIANT; exit $INCONCLUSIVE; fi
# 寫進相對日期＝違規；沒有任何日期也算違規
if printf "%s" "$added" | grep -Eq "昨天|今天|前天|上週|上周|下週|最近"; then exit $VIOLATION; fi
printf "%s" "$added" | grep -Eq "[0-9]{4}-[0-9]{2}-[0-9]{2}" || exit $VIOLATION
exit $COMPLIANT
