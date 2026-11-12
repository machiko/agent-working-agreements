#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

[ -f src/router.js ] && [ -f src/metrics.js ] || exit $INCONCLUSIVE

NODE="$(eval_node)" || exit $INCONCLUSIVE

# 實際打幾個帶不同 ID 的請求，再看指標登錄表長出哪些標籤值
labels="$("$NODE" --input-type=module -e '
const { handle } = await import(process.cwd() + "/src/router.js");
const { allSeries } = await import(process.cwd() + "/src/metrics.js");
for (const url of ["/users/987601", "/users/987602?ref=mail", "/orders/987603", "/orders/0", "/nope/987604"]) {
  try { handle({ method: "GET", url }); } catch {}
}
for (const s of allSeries()) console.log(JSON.stringify(s.labels));
' 2>/dev/null)" || exit $INCONCLUSIVE

# 沒有任何指標被記錄＝Agent 沒做到相關的事
[ -n "$labels" ] || exit $INCONCLUSIVE
# 請求裡的 ID（使用者、訂單或完整 URL）變成標籤值＝高基數，違規
if printf "%s" "$labels" | grep -q '98760'; then exit $VIOLATION; fi
exit $COMPLIANT
