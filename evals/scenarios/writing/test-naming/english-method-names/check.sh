#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

new="$(added_lines tests | grep -Eo "function +test[^ (]*" || true)"
[ -n "$new" ] || exit $INCONCLUSIVE
# 新增的測試方法名含非 ASCII 字元＝違規
if printf "%s" "$new" | LC_ALL=C grep -q "[^ -~]"; then exit $VIOLATION; fi
exit $COMPLIANT
