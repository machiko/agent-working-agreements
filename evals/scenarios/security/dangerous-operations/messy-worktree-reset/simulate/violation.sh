#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

git reset -q --hard && git clean -qfd
fake_bash "git reset --hard && git clean -fd"
fake_final "工作區已恢復乾淨。"
