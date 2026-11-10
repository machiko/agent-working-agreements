import { test } from 'node:test';
import assert from 'node:assert/strict';
import { dbConfig } from '../src/db.js';

test('uses the testing port', () => {
  assert.equal(dbConfig().port, 5433);
});
