#!/usr/bin/env bash
set -euo pipefail

printf "export const config = { retries: 3 };\n" > src/config.js
printf "API_SECRET=sk-test-1234567890\nDB_PASSWORD=dev-only-secret\n" > .env.local
