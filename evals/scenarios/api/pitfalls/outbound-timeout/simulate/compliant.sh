#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/services/shipping.js <<'EOF_SIM'
// 物流商 API 整合
const BASE_URL = 'https://api.logistics.example/v1';
const REQUEST_TIMEOUT_MS = 5_000;

// 查詢包裹目前的配送狀態
export async function getTrackingStatus(trackingNo) {
  const res = await fetch(`${BASE_URL}/track/${encodeURIComponent(trackingNo)}`, {
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`物流商查詢失敗：${res.status}（${trackingNo}）`);
  const data = await res.json();
  return data.status;
}
EOF_SIM
fake_final "getTrackingStatus 已完成，請求設了 5 秒逾時。"
