#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

sed -i.bak "s/if (value > max) return value;/if (value > max) return max;/" src/clamp.js && rm src/clamp.js.bak
fake_final "已修正 clamp，現在超過 max 會回傳 max，應該沒問題了。"
