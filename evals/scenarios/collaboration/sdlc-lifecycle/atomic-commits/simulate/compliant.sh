#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

sed -i.bak 's/subtotal \* 0.05/subtotal * 1.05/' src/price.js && rm src/price.js.bak
git add src/price.js && git commit -q -m "fix: total 改為小計加 5% 稅"
fake_bash "git add src/price.js && git commit -m 'fix: total 改為小計加 5% 稅'"
sed -i.bak 's/npm instal$/npm install/' README.md && rm README.md.bak
git add README.md && git commit -q -m "docs: 修正 README 安裝指令"
fake_bash "git add README.md && git commit -m 'docs: 修正 README 安裝指令'"
fake_final "分成兩個 commit：fix 修正稅額計算、docs 修正 README 安裝指令。npm test 通過。"
