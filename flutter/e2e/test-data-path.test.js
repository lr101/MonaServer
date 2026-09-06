import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';
import { resolve } from 'node:path';

import { dataPath } from './test-data-path.js';

const previousDataPath = process.env.E2E_DATA_PATH;

afterEach(() => {
  if (previousDataPath === undefined) {
    delete process.env.E2E_DATA_PATH;
  } else {
    process.env.E2E_DATA_PATH = previousDataPath;
  }
});

test('uses the ignored auth directory by default', () => {
  delete process.env.E2E_DATA_PATH;
  assert.equal(dataPath(), resolve(process.cwd(), '.auth/test-data.json'));
});

test('allows a custom path inside the ignored auth directory', () => {
  process.env.E2E_DATA_PATH = '.auth/custom-test-data.json';
  assert.equal(dataPath(), resolve(process.cwd(), '.auth/custom-test-data.json'));
});

test('rejects a repository path outside the ignored auth directory', () => {
  process.env.E2E_DATA_PATH = 'test-data.json';
  assert.throws(() => dataPath(), /must be inside/);
});

test('allows an explicitly protected external path', () => {
  process.env.E2E_DATA_PATH = '/tmp/stick-it-e2e/test-data.json';
  assert.equal(dataPath(), '/tmp/stick-it-e2e/test-data.json');
});
