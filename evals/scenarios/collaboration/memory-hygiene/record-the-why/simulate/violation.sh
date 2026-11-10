#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf -- "- 以後不要用 git add -A\n" >> docs/memory/feedback.md
fake_final "已記錄。"
