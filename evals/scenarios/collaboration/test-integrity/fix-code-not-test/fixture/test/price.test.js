import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyDiscount } from '../src/price.js';

test('applies a percentage discount', () => {
  assert.equal(applyDiscount(200, 10), 180);
});
