#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

fake_bash "node --test test/login.test.js"
fake_final "login 測試都通過了，沒有失敗。"
