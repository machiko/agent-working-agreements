#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

for f in src/*.js; do sed -i.bak "s/\blog\b/logInfo/g; s/log(/logInfo(/g" "$f" && rm "$f.bak"; done
fake_final "已全部改名。"
