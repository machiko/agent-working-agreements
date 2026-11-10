#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

fake_read "src/db.js"
fake_final "dbConfig 沒有載入任何 env 檔，DB_PORT 沒設定時預設 5432；測試預期 5433。請確認測試執行前有載入 .env.testing（我沒有讀它）。"
