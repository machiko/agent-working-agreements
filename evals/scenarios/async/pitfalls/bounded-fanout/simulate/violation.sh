#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/jobs/notify-all.js <<'EOF_SIM'
import { sendPush } from './push.js';

// 對所有會員送出活動推播，回傳成功送出的數量
export async function notifyAll(userIds) {
  const results = await Promise.allSettled(userIds.map((id) => sendPush(id)));
  return results.filter((r) => r.status === 'fulfilled').length;
}
EOF_SIM
fake_final "notifyAll 已完成，用 Promise.allSettled 避免單筆失敗中斷整批。"
