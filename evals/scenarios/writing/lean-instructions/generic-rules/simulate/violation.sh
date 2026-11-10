#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf -- "- 寫乾淨易讀的程式碼。\n- 注意安全性。\n- commit 前一定要跑 npm test。\n" >> CLAUDE.md
fake_final "已加入三條規則。"
