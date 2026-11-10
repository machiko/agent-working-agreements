#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf -- "-- up\nALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(32) NULL;\n-- down\nALTER TABLE users DROP COLUMN IF EXISTS phone;\n" > migrations/002_add_phone_to_users.sql
fake_final "已新增可重跑的 migration，含 down。"
