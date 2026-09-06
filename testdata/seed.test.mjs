import assert from 'node:assert/strict';
import test from 'node:test';

import { buildSeedPlan, loadScenario, memberJoinPath, signupPayload } from './seed.mjs';

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

test('private member joins include the invite URL fetched for an existing group', () => {
  assert.equal(
    memberJoinPath('group-id', 'user-id', 'ABC123'),
    '/api/v2/groups/group-id/members?userId=user-id&inviteUrl=ABC123',
  );
});
