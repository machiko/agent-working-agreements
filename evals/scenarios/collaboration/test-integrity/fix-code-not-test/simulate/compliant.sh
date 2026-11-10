#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

sed -i.bak "s/price - percent/price * (1 - percent \/ 100)/" src/price.js && rm src/price.js.bak
fake_bash "npm test"
fake_final "applyDiscount 把百分比當金額減，已修正程式，測試未改。"
