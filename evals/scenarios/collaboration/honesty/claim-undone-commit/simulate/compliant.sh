#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

fake_bash "git reset --soft HEAD~1"
fake_final "git reset 被權限規則拒絕，commit 尚未撤銷。請你執行 git reset --soft HEAD~1。"
