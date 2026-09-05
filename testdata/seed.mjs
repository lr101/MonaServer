import { chmod, mkdir, writeFile } from 'node:fs/promises';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scenarioFile = new URL('./scenarios.json', import.meta.url);
const tinyPng =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

export function loadScenario() {
  return JSON.parse(readFileSync(scenarioFile, 'utf8'));
}

function indexByKey(items, label) {
  if (!Array.isArray(items)) {
    throw new Error(`${label} must be an array`);
  }
  const result = {};
  for (const item of items) {
    if (!item || typeof item.key !== 'string' || item.key.length === 0) {
      throw new Error(`every ${label} entry needs a non-empty key`);
    }
    if (result[item.key]) {
      throw new Error(`duplicate ${label} key: ${item.key}`);
    }
    result[item.key] = item;
  }
  return result;
}

export function buildSeedPlan(scenario) {
  const users = indexByKey(scenario.users, 'user');
  const groups = indexByKey(scenario.groups, 'group');
  const pins = Array.isArray(scenario.pins) ? scenario.pins : [];
  const likes = Array.isArray(scenario.likes) ? scenario.likes : [];
  const pinKeys = new Set();

  if (!users[scenario.defaultUser]) {
    throw new Error(`unknown default user: ${scenario.defaultUser}`);
  }
  for (const [key, user] of Object.entries(users)) {
    if (typeof user.username !== 'string' || user.username.length === 0) {
      throw new Error(`user ${key} needs a username`);
    }
  }
  for (const [key, group] of Object.entries(groups)) {
    if (!users[group.admin]) {
      throw new Error(`group ${key} has unknown admin: ${group.admin}`);
    }
    if (![0, 1].includes(group.visibility)) {
      throw new Error(`group ${key} has invalid visibility: ${group.visibility}`);
    }
    if (!Array.isArray(group.members)) {
      throw new Error(`group ${key} members must be an array`);
    }
    for (const member of group.members) {
      if (!users[member]) {
        throw new Error(`group ${key} has unknown member: ${member}`);
      }
    }
  }
  for (const pin of pins) {
    if (!pin || typeof pin.key !== 'string' || pinKeys.has(pin.key)) {
      throw new Error(`pins need unique non-empty keys`);
    }
    pinKeys.add(pin.key);
    if (!groups[pin.group]) {
      throw new Error(`pin ${pin.key} has unknown group: ${pin.group}`);
    }
    if (!users[pin.creator]) {
      throw new Error(`pin ${pin.key} has unknown creator: ${pin.creator}`);
    }
    const group = groups[pin.group];
    if (pin.creator !== group.admin && !group.members.includes(pin.creator)) {
      throw new Error(`pin ${pin.key} creator is not a member of ${pin.group}`);
    }
    if (!Number.isFinite(pin.latitude) || !Number.isFinite(pin.longitude)) {
      throw new Error(`pin ${pin.key} needs numeric coordinates`);
    }
    if (Number.isNaN(Date.parse(pin.creationDate))) {
      throw new Error(`pin ${pin.key} needs a valid creationDate`);
    }
  }
  for (const like of likes) {
    if (!pinKeys.has(like.pin)) {
      throw new Error(`like references unknown pin: ${like.pin}`);
    }
    if (!users[like.user]) {
      throw new Error(`like references unknown user: ${like.user}`);
    }
  }

  return { ...scenario, users, groups, pins, likes };
}

function normalizeApiUrl(raw) {
  return raw.replace(/\/+$/, '');
}

function assertSafeApiTarget(apiUrl) {
  const hostname = new URL(apiUrl).hostname;
  const loopback = hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1';
  if (!loopback && process.env.TESTDATA_ALLOW_REMOTE_API !== '1') {
    throw new Error(
      `Refusing to seed non-loopback API ${hostname}; set TESTDATA_ALLOW_REMOTE_API=1 deliberately for a disposable remote API`,
    );
  }
}

async function parseBody(response) {
  const text = await response.text();
  if (!text) return undefined;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function bodyDescription(body) {
  if (body === undefined) return 'empty response';
  return typeof body === 'string' ? body : JSON.stringify(body);
}

async function request(apiUrl, path, { token, method = 'GET', body } = {}) {
  const headers = { Accept: 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const response = await fetch(`${apiUrl}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { response, body: await parseBody(response) };
}

function requireStatus(result, expected, action) {
  if (result.response.status !== expected) {
    throw new Error(`${action} failed (${result.response.status}): ${bodyDescription(result.body)}`);
  }
  return result.body;
}

async function login(apiUrl, username, password) {
  const result = await request(apiUrl, '/api/v2/public/login', {
    method: 'POST',
    body: { username, password },
  });
  if (result.response.status === 400 || result.response.status === 403) return undefined;
  return requireStatus(result, 200, `login for ${username}`);
}

export function signupPayload(user, password) {
  return {
    name: user.username,
    password,
    email: user.email ?? `${user.username}@example.invalid`,
  };
}

async function ensureUser(apiUrl, user, password) {
  const existing = await login(apiUrl, user.username, password);
  if (existing) return existing;

  const created = await request(apiUrl, '/api/v2/public/signup', {
    method: 'POST',
    body: signupPayload(user, password),
  });
  if (created.response.status === 201) return created.body;
  if (created.response.status === 409) {
    const retry = await login(apiUrl, user.username, password);
    if (retry) return retry;
    throw new Error(
      `user ${user.username} exists but the supplied TESTDATA_PASSWORD does not match; reset the test database or reuse the original password`,
    );
  }
  return requireStatus(created, 201, `signup for ${user.username}`);
}

async function findGroup(apiUrl, token, name) {
  const query = new URLSearchParams({
    search: name,
    withImages: 'false',
    page: '0',
    size: '100',
  });
  const result = await request(apiUrl, `/api/v2/groups?${query}`, { token });
  const body = requireStatus(result, 200, `find group ${name}`);
  return (body.items ?? []).find((group) => group.name === name);
}

async function ensureGroup(apiUrl, owner, group) {
  const existing = await findGroup(apiUrl, owner.accessToken, group.name);
  if (existing) return existing;

  const created = await request(apiUrl, '/api/v2/groups', {
    method: 'POST',
    token: owner.accessToken,
    body: {
      name: group.name,
      description: group.description,
      visibility: group.visibility,
      groupAdmin: owner.userId,
      profileImage: tinyPng,
    },
  });
  if (created.response.status === 409) {
    const retry = await findGroup(apiUrl, owner.accessToken, group.name);
    if (retry) return retry;
  }
  return requireStatus(created, 201, `create group ${group.name}`);
}

export function memberJoinPath(groupId, userId, inviteUrl) {
  const query = new URLSearchParams({ userId });
  if (inviteUrl) query.set('inviteUrl', inviteUrl);
  return `/api/v2/groups/${groupId}/members?${query}`;
}

async function getGroupInviteUrl(apiUrl, owner, group) {
  const result = await request(apiUrl, `/api/v2/groups/${group.id}/invite_url`, {
    token: owner.accessToken,
  });
  return requireStatus(result, 200, `get invite URL for ${group.name}`);
}

async function ensureMember(apiUrl, owner, group, userId) {
  let inviteUrl = group.invite_url;
  if (group.visibility === 1 && !inviteUrl) {
    inviteUrl = await getGroupInviteUrl(apiUrl, owner, group);
  }
  const result = await request(apiUrl, memberJoinPath(group.id, userId, inviteUrl), {
    method: 'POST',
    token: owner.accessToken,
  });
  if (![201, 409].includes(result.response.status)) {
    requireStatus(result, 201, `add member to ${group.name}`);
  }
}

async function findPin(apiUrl, token, groupId, description) {
  const query = new URLSearchParams({
    groupId,
    withImage: 'false',
    page: '0',
    size: '100',
  });
  const result = await request(apiUrl, `/api/v2/pins?${query}`, { token });
  const body = requireStatus(result, 200, `find pins in ${groupId}`);
  return (body.items ?? []).find((pin) => pin.description === description);
}

async function ensurePin(apiUrl, creator, group, pin) {
  const existing = await findPin(apiUrl, creator.accessToken, group.id, pin.description);
  if (existing) return existing;

  const created = await request(apiUrl, '/api/v2/pins', {
    method: 'POST',
    token: creator.accessToken,
    body: {
      image: tinyPng,
      latitude: pin.latitude,
      longitude: pin.longitude,
      userId: creator.userId,
      groupId: group.id,
      creationDate: pin.creationDate,
      description: pin.description,
    },
  });
  if (created.response.status === 409) {
    const retry = await findPin(apiUrl, creator.accessToken, group.id, pin.description);
    if (retry) return retry;
  }
  return requireStatus(created, 201, `create pin ${pin.key}`);
}

async function ensureLike(apiUrl, user, pin, like) {
  const body = { userId: user.userId };
  for (const field of ['like', 'likeLocation', 'likePhotography', 'likeArt']) {
    if (like[field] !== undefined) body[field] = like[field];
  }
  const result = await request(apiUrl, `/api/v2/pins/${pin.id}/likes`, {
    method: 'POST',
    token: user.accessToken,
    body,
  });
  if (![200, 201].includes(result.response.status)) {
    requireStatus(result, 201, `create like for ${pin.id}`);
  }
}

function shellQuote(value) {
  return `'${String(value).replaceAll("'", "'\\''")}'`;
}

async function writeProtected(filePath, content) {
  await mkdir(dirname(filePath), { recursive: true, mode: 0o700 });
  await writeFile(filePath, content, { mode: 0o600 });
  await chmod(filePath, 0o600);
}

async function seed() {
  const password = process.env.TESTDATA_PASSWORD;
  if (!password || /[\r\n]/.test(password)) {
    throw new Error('TESTDATA_PASSWORD is required and must be a single line; it is never printed or committed');
  }
  const apiUrl = normalizeApiUrl(process.env.TEST_API_URL ?? 'http://127.0.0.1:8081');
  assertSafeApiTarget(apiUrl);
  const plan = buildSeedPlan(loadScenario());
  const users = {};

  for (const [key, user] of Object.entries(plan.users)) {
    const token = await ensureUser(apiUrl, user, password);
    users[key] = { ...token, username: user.username };
  }

  const groups = {};
  for (const [key, fixture] of Object.entries(plan.groups)) {
    const owner = users[fixture.admin];
    const group = await ensureGroup(apiUrl, owner, fixture);
    groups[key] = group;
    for (const member of fixture.members) {
      await ensureMember(apiUrl, owner, group, users[member].userId);
    }
  }

  const pins = {};
  for (const fixture of plan.pins) {
    const pin = await ensurePin(apiUrl, users[fixture.creator], groups[fixture.group], fixture);
    pins[fixture.key] = pin;
  }
  for (const like of plan.likes) {
    await ensureLike(apiUrl, users[like.user], pins[like.pin], like);
  }

  const statePath = resolve('testdata/.seed-state.json');
  const envPath = resolve('testdata/.env.test');
  const state = {
    scenarioVersion: plan.version,
    apiUrl,
    defaultUser: plan.defaultUser,
    users: Object.fromEntries(
      Object.entries(users).map(([key, user]) => [key, { username: user.username, userId: user.userId }]),
    ),
    groups: Object.fromEntries(
      Object.entries(groups).map(([key, group]) => [
        key,
        {
          id: group.id,
          name: group.name,
          visibility: group.visibility,
          inviteUrl: group.invite_url ?? null,
        },
      ]),
    ),
    pins: Object.fromEntries(
      Object.entries(pins).map(([key, pin]) => [key, { id: pin.id, groupId: pin.groupId }]),
    ),
  };
  await writeProtected(statePath, `${JSON.stringify(state, null, 2)}\n`);
  await writeProtected(
    envPath,
    [
      '# Generated by mise run testdata-seed. This file is ignored and contains local test credentials.',
      `TEST_API_URL=${shellQuote(apiUrl)}`,
      `E2E_API_URL=${shellQuote(apiUrl)}`,
      `E2E_TEST_USERNAME=${shellQuote(users[plan.defaultUser].username)}`,
      `E2E_TEST_PASSWORD=${shellQuote(password)}`,
      `E2E_TEST_GROUP=${shellQuote(groups['member-public'].name)}`,
      `E2E_TEST_PUBLIC_UNJOINED_GROUP=${shellQuote(groups['public-unjoined'].name)}`,
      `E2E_TEST_PUBLIC_UNJOINED_GROUP_ID=${shellQuote(groups['public-unjoined'].id)}`,
      '',
    ].join('\n'),
  );

  console.log(`Seeded ${Object.keys(users).length} users, ${Object.keys(groups).length} groups, ${Object.keys(pins).length} pins, and ${plan.likes.length} likes at ${apiUrl}.`);
  console.log(`Wrote ${statePath} and ${envPath}; source ${envPath} for the Flutter web session.`);
}

const entrypoint = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (entrypoint) {
  seed().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}
