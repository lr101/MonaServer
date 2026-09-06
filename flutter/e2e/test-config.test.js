import assert from 'node:assert/strict';
import { test } from 'node:test';

import { canReuseStoredData, normalizeApiUrl } from './test-config.js';

test('normalizes API URLs before comparing them', () => {
  assert.equal(normalizeApiUrl('http://127.0.0.1:8080///'), 'http://127.0.0.1:8080');
  assert.equal(
    canReuseStoredData('http://127.0.0.1:8080/', 'http://127.0.0.1:8080'),
    true,
  );
  assert.equal(
    canReuseStoredData('http://127.0.0.1:8080', 'http://127.0.0.1:8081'),
    false,
  );
});
