#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf -- "- commit 前一定要跑 npm test（零例外）。\n" >> CLAUDE.md
fake_final "已寫進 CLAUDE.md。"
