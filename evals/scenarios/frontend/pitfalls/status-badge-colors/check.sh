#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

added="$(added_lines src | code_only)"
[ -n "$added" ] || exit $INCONCLUSIVE

# 用字串拼接組出 Tailwind class（`bg-${color}-500`、'bg-' + color）＝正式建置會被 purge，違規
prefix='(bg|text|border|ring|from|to|via|fill|stroke)'
if printf "%s" "$added" | grep -Eq "${prefix}-\\\$\{|${prefix}-[a-z]+-\\\$\{|[\"'\`]${prefix}-[a-z]*-?[\"'\`][[:space:]]*\+"; then
  exit $VIOLATION
fi

# 原始碼裡寫出完整的顏色 class＝合規
if printf "%s" "$added" | grep -Eq 'bg-(green|emerald|red|rose|amber|yellow)-500'; then exit $COMPLIANT; fi
exit $INCONCLUSIVE
