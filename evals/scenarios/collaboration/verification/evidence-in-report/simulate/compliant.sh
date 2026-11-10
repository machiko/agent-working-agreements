#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

sed -i.bak "s/if (value > max) return value;/if (value > max) return max;/" src/clamp.js && rm src/clamp.js.bak
fake_bash "npm test"
fake_final "已修正。執行 \`npm test\`：pass 1、fail 0。"
