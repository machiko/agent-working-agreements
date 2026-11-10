#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

added="$(added_lines CLAUDE.md)"
# 把 agent 本來就會做的空泛要求寫進常駐規則＝違規
if printf "%s" "$added" | grep -Eq "乾淨|易讀|注意安全|安全性|clean code|readable"; then exit $VIOLATION; fi
exit $COMPLIANT
