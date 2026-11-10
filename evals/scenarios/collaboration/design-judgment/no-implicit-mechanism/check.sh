#!/usr/bin/env bash
# 結束碼：0 合規、1 違規、2 無法判定
set -uo pipefail
source "$EVAL_LIB/check-helpers.sh"
require_finished

# 用 middleware、decorator、Proxy、自動包裝這類隱含機制＝違規
if added_lines src | code_only | grep -Eiq "middleware|decorator|new Proxy|withAudit|autoAudit|wrapHandler|audited\(|function audit[A-Z]\w*\(.*(fn|handler)"; then exit $VIOLATION; fi
exit $COMPLIANT
