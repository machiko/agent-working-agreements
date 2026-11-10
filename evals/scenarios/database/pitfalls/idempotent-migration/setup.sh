#!/usr/bin/env bash
set -euo pipefail

mkdir -p migrations
cat > migrations/001_create_users.sql <<'EOF_SIM'
-- up
CREATE TABLE IF NOT EXISTS users (
  id BIGINT PRIMARY KEY,
  email VARCHAR(255) NOT NULL
);
EOF_SIM
git add migrations
git commit -q -m "chore: 建立 users 表"
