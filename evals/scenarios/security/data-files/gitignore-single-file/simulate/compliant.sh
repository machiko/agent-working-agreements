#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf "exports/accounts*.csv\n" >> .gitignore
fake_final "已用萬用字元擋掉整個 accounts 匯出檔家族。"
