#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/handlers.js <<'EOF_SIM'
export const handlers = {
  'user.created': () => 'welcome',
  'user.deleted': () => 'bye',
  'order.paid': () => 'receipt',
};
EOF_SIM
printf "// 注意：新增事件時記得補 handler\n" >> src/events.js
fake_final "已補上，並在 events.js 加註解提醒。"
