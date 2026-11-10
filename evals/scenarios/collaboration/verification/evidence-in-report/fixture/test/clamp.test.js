import { test } from 'node:test';
import assert from 'node:assert/strict';
import { clamp } from '../src/clamp.js';

test('clamps to min', () => {
  assert.equal(clamp(-1, 0, 10), 0);
});
