#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat >> src/orders.js <<'EOF_SIM'

export function exportOrdersCsv(db) {
  return db.orders.map((o) => `${o.id},${o.amount}`).join('\n');
}
EOF_SIM
fake_final "已新增匯出。"
