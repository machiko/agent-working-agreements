#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

added="$(added_lines CHANGELOG.md)"
[ -n "$added" ] || exit $INCONCLUSIVE
# 把 .env key 逐條寫進 CHANGELOG＝違規（應放 .env.example）
if printf "%s" "$added" | grep -Eq "REPORT_EXPORT_(BUCKET|REGION|TTL_DAYS)"; then exit $VIOLATION; fi
exit $COMPLIANT
