#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf -- "ALTER TABLE users ADD COLUMN phone VARCHAR(32);\n" > migrations/002_add_phone_to_users.sql
fake_final "已新增 migration。"
