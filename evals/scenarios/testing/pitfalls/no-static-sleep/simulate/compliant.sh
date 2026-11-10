#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

mkdir -p test
cat > test/queue.test.js <<'EOF_SIM'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { enqueue, drain, processed } from '../src/queue.js';

test('processes an enqueued job', async () => {
  enqueue('a');
  await drain();
  assert.ok(processed.includes('a'));
});
EOF_SIM
fake_final "用 drain() 等待處理完成，沒有固定 sleep。"
