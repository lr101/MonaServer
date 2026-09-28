import assert from 'node:assert/strict';
import test from 'node:test';

import { buildSeedPlan, loadScenario, memberJoinPath, outputPaths, signupPayload } from './seed.mjs';

test('fixture includes a public unjoined group with visible pins', () => {
  const plan = buildSeedPlan(loadScenario());
  const group = plan.groups['public-unjoined'];

  assert.equal(group.visibility, 0);
  assert.equal(group.members.includes('viewer'), false);
  assert.ok(plan.pins.some((pin) => pin.group === 'public-unjoined'));
});

test('fixture references only declared users, groups, and pins', () => {
  const plan = buildSeedPlan(loadScenario());
  const users = new Set(Object.keys(plan.users));
  const groups = new Set(Object.keys(plan.groups));
  const pins = new Set(plan.pins.map((pin) => pin.key));

  for (const group of Object.values(plan.groups)) {
    assert.ok(users.has(group.admin), `unknown group admin: ${group.admin}`);
    for (const member of group.members) {
      assert.ok(users.has(member), `unknown group member: ${member}`);
    }
  }
  for (const pin of plan.pins) {
    assert.ok(groups.has(pin.group), `unknown pin group: ${pin.group}`);
    assert.ok(users.has(pin.creator), `unknown pin creator: ${pin.creator}`);
  }
  for (const like of plan.likes) {
    assert.ok(pins.has(like.pin), `unknown liked pin: ${like.pin}`);
    assert.ok(users.has(like.user), `unknown like user: ${like.user}`);
  }
});

test('fixture usernames satisfy the Flutter login validator', () => {
  const plan = buildSeedPlan(loadScenario());

  for (const user of Object.values(plan.users)) {
    assert.match(user.username, /^[a-zA-Z0-9!@#$%^&*]{2,29}$/);
  }
});

test('signup payload uses a non-deliverable email when a fixture omits one', () => {
  assert.deepEqual(signupPayload({ username: 'fixture-user' }, 'secret'), {
    name: 'fixture-user',
    password: 'secret',
    email: 'fixture-user@example.invalid',
  });
});

test('fixture outputs can be isolated outside the repository', () => {
  assert.deepEqual(outputPaths('/tmp/preview-fixture-a'), {
    statePath: '/tmp/preview-fixture-a/.seed-state.json',
    envPath: '/tmp/preview-fixture-a/.env.test',
  });
});

test('fixture output environment variable selects private output paths', () => {
  const previous = process.env.TESTDATA_OUTPUT_DIR;
  process.env.TESTDATA_OUTPUT_DIR = '/tmp/preview-fixture-from-env';
  try {
    assert.deepEqual(outputPaths(), {
      statePath: '/tmp/preview-fixture-from-env/.seed-state.json',
      envPath: '/tmp/preview-fixture-from-env/.env.test',
    });
  } finally {
    if (previous === undefined) delete process.env.TESTDATA_OUTPUT_DIR;
    else process.env.TESTDATA_OUTPUT_DIR = previous;
  }
});

test('configured fixture output directories must be absolute', () => {
  const previous = process.env.TESTDATA_OUTPUT_DIR;
  process.env.TESTDATA_OUTPUT_DIR = 'relative-preview-fixtures';
  try {
    assert.throws(outputPaths, /TESTDATA_OUTPUT_DIR must be an absolute path/);
  } finally {
    if (previous === undefined) delete process.env.TESTDATA_OUTPUT_DIR;
    else process.env.TESTDATA_OUTPUT_DIR = previous;
  }
});

test('private member joins include the invite URL fetched for an existing group', () => {
  assert.equal(
    memberJoinPath('group-id', 'user-id', 'ABC123'),
    '/api/v2/groups/group-id/members?userId=user-id&inviteUrl=ABC123',
  );
});
