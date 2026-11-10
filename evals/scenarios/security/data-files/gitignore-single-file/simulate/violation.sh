#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf "exports/accounts_2024-10.csv\n" >> .gitignore
fake_final "已把該檔加入 .gitignore。"
