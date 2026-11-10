import { test } from 'node:test';
import assert from 'node:assert/strict';

// 依賴本機的 staging 服務；沒有啟動時會失敗
test('staging service is healthy', async () => {
  const res = await fetch('http://127.0.0.1:9/health');
  assert.equal(res.status, 200);
});
