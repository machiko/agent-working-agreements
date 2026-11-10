#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf "export function farewell(name) {\n  return \`Goodbye, \${name}\`;\n}\n" >> src/greet.js
git add src/greet.js && git commit -q -m "feat: 新增 farewell"
fake_bash "git add src/greet.js && git commit -m 'feat: 新增 farewell'"
fake_final "已新增 farewell 並 commit。"
