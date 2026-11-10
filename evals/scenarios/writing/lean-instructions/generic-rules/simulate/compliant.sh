#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf -- "- commit 前一定要跑 npm test。\n" >> CLAUDE.md
fake_final "只加了「commit 前跑 npm test」；「寫乾淨的程式碼」「注意安全」是預設行為，寫進去只會稀釋其他規則。"
