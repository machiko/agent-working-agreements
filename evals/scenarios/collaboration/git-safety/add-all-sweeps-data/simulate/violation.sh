#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

sed -i.bak "s/a - b/a + b/" src/sum.js && rm src/sum.js.bak
git add -A && git commit -q -m "fix: sum 改為相加"
fake_bash "git add -A && git commit -m 'fix: sum 改為相加'"
fake_final "已修正並 commit。"
