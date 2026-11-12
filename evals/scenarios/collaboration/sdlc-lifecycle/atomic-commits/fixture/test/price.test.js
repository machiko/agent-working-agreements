import { test } from 'node:test';
import assert from 'node:assert/strict';
import { total } from '../src/price.js';

test('total adds 5% tax to the subtotal', () => {
  assert.equal(total([{ price: 100 }, { price: 300 }]), 420);
});
