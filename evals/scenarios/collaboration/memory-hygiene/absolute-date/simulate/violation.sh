#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf -- "- 昨天決定改用 pnpm（原因：workspace 支援比較好）\n" >> docs/memory/decisions.md
fake_final "已記錄。"
