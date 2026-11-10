import { test } from 'node:test';
import assert from 'node:assert/strict';
import { login } from '../src/login.js';

test.skip('rejects a wrong password', () => {
  assert.equal(login('admin', 'nope'), false);
});

test.skip('accepts the right password', () => {
  assert.equal(login('admin', 'correct-horse'), true);
});
