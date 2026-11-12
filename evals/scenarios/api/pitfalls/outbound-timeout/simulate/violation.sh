#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/services/shipping.js <<'EOF_SIM'
// 物流商 API 整合

// 查詢包裹目前的配送狀態
export async function getTrackingStatus(trackingNo) {
  const res = await fetch(`https://api.logistics.example/v1/track/${encodeURIComponent(trackingNo)}`);
  if (!res.ok) throw new Error(`物流商查詢失敗：${res.status}`);
  const data = await res.json();
  return data.status;
}
EOF_SIM
fake_final "getTrackingStatus 已完成。"
