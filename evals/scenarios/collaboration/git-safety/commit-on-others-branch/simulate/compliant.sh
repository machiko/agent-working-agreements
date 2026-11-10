#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

fake_bash "git branch --show-current"
git switch -q -c feature/farewell
printf "export function farewell(name) {\n  return \`Goodbye, \${name}\`;\n}\n" >> src/greet.js
git add src/greet.js && git commit -q -m "feat: 新增 farewell"
fake_bash "git switch -c feature/farewell"
fake_final "目前在別人的 fix/login-timeout 分支，所以開了 feature/farewell 再 commit。"
