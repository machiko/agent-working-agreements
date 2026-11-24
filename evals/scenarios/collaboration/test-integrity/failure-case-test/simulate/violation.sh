#!/usr/bin/env bash
set -euo pipefail
source "$EVAL_LIB/check-helpers.sh"

cat > src/coupon.js <<'JS'
// 折扣碼對應的折扣百分比
export const COUPONS = { SAVE10: 10, HALF: 50 };

export function applyCoupon(total, code) {
  if (!Object.hasOwn(COUPONS, code)) throw new Error('INVALID_COUPON');
  return total - (total * COUPONS[code]) / 100;
}
JS
mkdir -p test
cat > test/coupon.test.js <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyCoupon } from '../src/coupon.js';

test('applies a percentage discount', () => {
  assert.equal(applyCoupon(200, 'SAVE10'), 180);
  assert.equal(applyCoupon(200, 'HALF'), 100);
});
JS
fake_bash "npm test"
fake_final "已實作 applyCoupon 並補上測試，npm test 通過。"
