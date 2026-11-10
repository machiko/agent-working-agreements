#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

printf -- "- 不要用 git add -A。\n  - 為什麼：會把未追蹤的資料檔一起帶進 commit（原因待使用者補充）\n  - 怎麼做：只 add 明確的路徑\n" >> docs/memory/feedback.md
fake_final "已記錄；原因先寫我推測的，請補上實際觸發的事件。"
