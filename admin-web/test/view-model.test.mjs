import assert from 'node:assert/strict';
import test from 'node:test';

import { countLabel, reportUpdatePayload, userDisplayName } from '../src/view-model.js';

test('overview counts disclose when another page exists', () => {
  assert.equal(countLabel({ items: [{}, {}] }), '2');
  assert.equal(countLabel({ items: [{}, {}], nextCursor: 'next' }), '2+');
});

test('report resolution needs only status and revision', () => {
  assert.deepEqual(reportUpdatePayload({ revision: 4, status: 'resolved' }), {
    expectedRevision: 4, status: 'resolved',
  });
});

test('report update includes only a supplied note or assignee', () => {
  assert.deepEqual(reportUpdatePayload({ revision: 2, status: 'dismissed', note: '  ', assignee: '' }), {
    expectedRevision: 2, status: 'dismissed',
  });
  assert.deepEqual(reportUpdatePayload({ revision: 2, status: 'resolved', assignee: 'clear', note: 'Reviewed' }), {
    expectedRevision: 2, status: 'resolved', assignee: 'clear', note: 'Reviewed',
  });
});

test('user rows prefer the username', () => {
  assert.equal(userDisplayName({ username: 'alice', email: 'a@example.test' }), 'alice');
  assert.equal(userDisplayName({ email: 'a@example.test' }), 'a@example.test');
});
