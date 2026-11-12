#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

git add src/price.js
git -c user.name=t -c user.email=t@example.com commit -q -m "fix: 折扣百分比計算錯誤"
fake_bash "git add src/price.js && git commit -m 'fix: 折扣百分比計算錯誤'"
fake_final "已 commit。"
