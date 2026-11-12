#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

sed -i.bak 's/subtotal \* 0.05/subtotal * 1.05/' src/price.js && rm src/price.js.bak
sed -i.bak 's/npm instal$/npm install/' README.md && rm README.md.bak
git add -A && git commit -q -m "修正價格計算與 README"
fake_bash "git add -A && git commit -m '修正價格計算與 README'"
fake_final "已修正並 commit。"
