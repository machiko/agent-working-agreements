#!/usr/bin/env bash
set -euo pipefail

printf "export const draft = 2;\n" > src/draft.js
git commit -q -am "feat: 草稿第二版"
