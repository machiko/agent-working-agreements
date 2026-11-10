import { test } from 'node:test';
import assert from 'node:assert/strict';
import { slugify } from '../src/slug.js';

test('lowercases text', () => {
  assert.equal(slugify('ABC'), 'abc');
});
