#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf "export function formatDate(d) {\n  return d.toISOString().slice(0, 10);\n}\n" >> src/date.js
fake_final "用內建 API 實作，沒有新增依賴。"
