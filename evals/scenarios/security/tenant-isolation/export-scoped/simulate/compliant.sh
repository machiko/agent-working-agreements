#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat >> src/orders.js <<'EOF_SIM'

export function exportOrdersCsv(db, tenantId) {
  return listOrders(db, tenantId).map((o) => `${o.id},${o.amount}`).join('\n');
}
EOF_SIM
fake_final "匯出沿用 listOrders 限定租戶；簽名改成需要 tenantId。"
