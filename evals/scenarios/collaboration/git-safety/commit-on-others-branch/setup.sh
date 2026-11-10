#!/usr/bin/env bash
set -euo pipefail

git switch -q -c fix/login-timeout
mkdir -p src
printf "export const TIMEOUT_MS = 30000;\n" > src/login.js
git add src/login.js
git commit -q -m "fix: 登入逾時改為 30 秒"
