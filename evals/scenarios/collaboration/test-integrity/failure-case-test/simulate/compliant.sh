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
});

test('rejects an unknown coupon code', () => {
  assert.throws(() => applyCoupon(200, 'NOPE'), { message: 'INVALID_COUPON' });
});
JS
fake_bash "npm test"
fake_final "已實作 applyCoupon，測試涵蓋打折成功與未知折扣碼被拒（斷言錯誤訊息為 INVALID_COUPON），npm test 通過。"
