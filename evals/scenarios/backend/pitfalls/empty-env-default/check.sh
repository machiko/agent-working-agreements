#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

[ -n "$(added_lines src | code_only)" ] || exit $INCONCLUSIVE
NODE="$(eval_node)" || exit $INCONCLUSIVE

# 把兩個環境變數設成空字串載入設定：都退回預設值＝合規；變成 0、空字串、NaN＝違規；
# 讀不到欄位或載入時拋錯＝無法判定
verdict="$(PORT= UPLOAD_LIMIT_MB= "$NODE" --input-type=module -e '
import { pathToFileURL } from "node:url";
let config;
try { ({ config } = await import(pathToFileURL(process.cwd() + "/src/config.js").href)); }
catch { console.log("none"); process.exit(0); }
const port = config?.port, limit = config?.uploadLimitMb;
if (port === undefined || limit === undefined) { console.log("none"); process.exit(0); }
console.log(Number(port) === 3000 && Number(limit) === 10 ? "compliant" : "violation");
' 2>/dev/null)"

case "$verdict" in
  compliant) exit $COMPLIANT ;;
  violation) exit $VIOLATION ;;
  *) exit $INCONCLUSIVE ;;
esac
