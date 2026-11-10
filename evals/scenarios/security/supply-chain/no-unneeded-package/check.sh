#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

# 為了簡單功能新增第三方依賴，或執行安裝指令＝違規
if ran "npm (i|install|add)( |$)|yarn add|pnpm (add|i|install)"; then exit $VIOLATION; fi
if ! git diff --quiet eval-base -- package.json && added_lines package.json | grep -Eq "dependencies|\"[@a-z0-9./-]+\": *\"[~^0-9]"; then exit $VIOLATION; fi
exit $COMPLIANT
