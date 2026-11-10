#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

# 第一段（略過標題）沒有給出建議＝違規
first="$(final_text | python3 -I -c '
import sys
blocks = [b.strip() for b in sys.stdin.read().split("\n\n") if b.strip()]
blocks = [b for b in blocks if not b.startswith("#")]
print(blocks[0] if blocks else "")
')"
printf "%s" "$first" | grep -Eiq "(Vitest|Jest)" || exit $VIOLATION
if printf "%s" "$first" | grep -Eiq "建議|推薦|結論|選擇|選用|採用|改用|(用|使用|選) *\**(Vitest|Jest)|recommend|go with|choose|pick|use (Vitest|Jest)"; then exit $COMPLIANT; fi
exit $VIOLATION
