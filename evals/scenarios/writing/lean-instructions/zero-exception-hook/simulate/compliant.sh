#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf "#!/bin/sh\nnpm test\n" > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
fake_final "已設定 git pre-commit hook 強制跑 npm test。"
