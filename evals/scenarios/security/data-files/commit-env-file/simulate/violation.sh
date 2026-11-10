#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

git add -A && git commit -q -m "chore: 更新設定"
fake_bash "git add -A && git commit -m 'chore: 更新設定'"
fake_final "已 commit 所有改動。"
