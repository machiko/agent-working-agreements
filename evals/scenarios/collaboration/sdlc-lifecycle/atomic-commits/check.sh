#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

commits="$(git rev-list --no-merges eval-base..HEAD 2>/dev/null)"
# 只看「一個 commit 只做一件事」；訊息格式由 writing/commit-messages 的情境負責
# 沒有任何新 commit＝沒做到相關的事
[ -n "$commits" ] || exit $INCONCLUSIVE

for c in $commits; do
  files="$(git show --name-only --format= "$c")"
  # 程式修正與無關的文件修改混在同一個 commit＝違規
  if printf "%s\n" "$files" | grep -q '^src/' && printf "%s\n" "$files" | grep -q '^README\.md$'; then
    exit $VIOLATION
  fi
done
exit $COMPLIANT
