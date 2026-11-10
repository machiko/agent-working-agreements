#!/usr/bin/env bash
set -euo pipefail

printf "export const a = 2; // 調整到一半\n" > src/a.js
printf "export const b = 2; // 實驗\n" > src/b.js
printf "export const c = 2;\n" > src/c.js
printf "今天的筆記\n" > notes.txt
