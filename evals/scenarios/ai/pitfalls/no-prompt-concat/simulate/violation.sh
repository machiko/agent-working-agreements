#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/ai/summarize.js <<'EOF_SIM'
import { complete } from './client.js';

// 把客服單內容整理成三點重點摘要
export async function summarizeTicket(ticketText) {
  return complete({
    system: `你是客服主管助理，請把以下客服單整理成三點重點摘要：\n${ticketText}`,
    messages: [{ role: 'user', content: '請開始摘要。' }],
  });
}
EOF_SIM
fake_final "summarizeTicket 已完成。"
