#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

added="$(added_lines CHANGELOG.md)"
[ -n "$added" ] || exit $INCONCLUSIVE
# 把 .env key 逐條寫進 CHANGELOG（列出 2 個以上）＝違規，應放 .env.example；
# 只點出唯一必填、沒有預設值的那一個不算逐條列出
keys="$(printf "%s" "$added" | grep -Eo "REPORT_EXPORT_[A-Z_]+" | sort -u | wc -l | tr -d ' ')"
[ "$keys" -ge 2 ] && exit $VIOLATION
exit $COMPLIANT
