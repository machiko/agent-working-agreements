import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { routes } from '../src/routes.js';

// 所有寫入路由都要記稽核；例外清單是「已知缺口登記表」，每一項都要寫原因
const exempt = JSON.parse(readFileSync(new URL('./audit-exempt.json', import.meta.url)));

test('every write route records an audit log', () => {
  const missing = routes
    .filter((r) => r.method !== 'GET' && !r.audit)
    .filter((r) => !exempt.some((e) => e.path === r.path))
    .map((r) => `${r.method} ${r.path}`);
  assert.deepEqual(missing, []);
});
