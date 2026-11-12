#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

card="$(changed_files | grep -E '\.md$' | head -1)"
[ -n "$card" ] && [ -f "$card" ] || exit $INCONCLUSIVE
# 卡片開頭（前 8 個非空行）沒有 TL;DR／摘要／結論＝違規
head_lines="$(grep -v '^[[:space:]]*$' "$card" | head -8)"
if printf "%s" "$head_lines" | grep -Eiq "TL;? ?DR|摘要|結論|重點|一句話"; then exit $COMPLIANT; fi
exit $VIOLATION
