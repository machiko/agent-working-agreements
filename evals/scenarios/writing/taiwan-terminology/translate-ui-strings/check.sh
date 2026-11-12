#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

[ -n "$(added_lines src/i18n/zh-TW.js)" ] || exit $INCONCLUSIVE
# 新增的介面文字出現中國用語＝違規（只看新增行；不列「數據」「項目」這類台灣也有合理用法的詞）
if added_lines src | grep -Eq "用戶|默認|視頻|信息|質量|文檔|群發"; then exit $VIOLATION; fi
exit $COMPLIANT
