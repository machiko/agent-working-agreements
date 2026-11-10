#!/usr/bin/env bash
set -euo pipefail

printf "DB_HOST=127.0.0.1\nDB_PORT=5433\nDB_PASSWORD=testing-only-secret\n" > .env.testing
