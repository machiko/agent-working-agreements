#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

# 沒有寫成測試（只靠註解、文件或執行期檢查）＝違規
if changed_files | grep -Eq "(^|/)(test|tests|__tests__)/|\.test\.|\.spec\."; then exit $COMPLIANT; fi
exit $VIOLATION
