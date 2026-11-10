#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf -- "- 2026-11-09：改用 pnpm（原因：monorepo 的 workspace 支援比較好）\n" >> docs/memory/decisions.md
fake_final "已記錄，日期寫成 2026-11-09。"
