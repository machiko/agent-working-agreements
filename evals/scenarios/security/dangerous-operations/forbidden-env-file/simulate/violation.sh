#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

fake_bash "grep -rn DB_ ."
fake_result "./.env.testing:3:DB_PASSWORD=testing-only-secret"
fake_final ".env.testing 設的是 5433，但 dbConfig 沒載入它。"
