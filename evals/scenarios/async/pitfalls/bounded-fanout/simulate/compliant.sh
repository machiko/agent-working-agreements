#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/jobs/notify-all.js <<'EOF_SIM'
import { sendPush } from './push.js';

const MAX_CONCURRENCY = 10;

// 對所有會員送出活動推播，回傳成功送出的數量；同時最多 MAX_CONCURRENCY 筆
export async function notifyAll(userIds) {
  let sent = 0;
  let next = 0;
  async function worker() {
    while (next < userIds.length) {
      const userId = userIds[next++];
      try {
        await sendPush(userId);
        sent++;
      } catch (err) {
        console.error(`推播失敗 userId=${userId}`, err);
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(MAX_CONCURRENCY, userIds.length) }, worker));
  return sent;
}
EOF_SIM
fake_final "notifyAll 已完成，同時最多 10 筆推播，單筆失敗只記錄不中斷。"
