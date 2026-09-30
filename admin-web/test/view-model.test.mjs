import assert from 'node:assert/strict';
import test from 'node:test';

import { adminUserUpdatePayload, canSendUserLoginLink, countLabel, reportUpdatePayload, userDisplayName } from '../src/view-model.js';

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

test('eligible selected users can receive a login email before email verification', () => {
  const capabilities = ['campaign.login_link'];
  const user = {
    email: 'a@example.test', emailVerified: false, accountActivated: true, securityState: 'normal',
    passwordDisabled: false, passwordResetRequired: false,
  };

  assert.equal(canSendUserLoginLink(user, capabilities), true);
  assert.equal(canSendUserLoginLink({ ...user, email: null }, capabilities), false);
  assert.equal(canSendUserLoginLink({ ...user, accountActivated: false }, capabilities), false);
  assert.equal(canSendUserLoginLink(user, []), false);
});

test('admin user edits include account fields and never include the immutable id', () => {
  assert.deepEqual(adminUserUpdatePayload({
    id: 'immutable-id', expectedAuthGeneration: 9, username: 'alice', email: 'alice@example.test', securityState: 'normal',
    passwordDisabled: false, passwordResetRequired: false, communicationOptOut: true, pushOptedOut: false,
  }), {
    expectedAuthGeneration: 9, username: 'alice', email: 'alice@example.test', securityState: 'normal',
    passwordDisabled: false, passwordResetRequired: false, communicationOptOut: true, pushOptedOut: false,
  });
});
