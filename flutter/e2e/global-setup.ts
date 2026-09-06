import { randomBytes } from 'node:crypto';
import { chmod, mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

import { canReuseStoredData, normalizeApiUrl } from './test-config.js';
import { dataPath } from './test-data-path.js';

type TokenResponse = {
  accessToken: string;
  refreshToken: string;
  userId: string;
};

type Group = {
  id: string;
  name: string;
};

type StoredTestData = {
  apiUrl: string;
  username: string;
  password: string;
  groupName: string;
  userId: string;
  groupId: string;
  publicUnjoinedGroupName?: string;
  publicUnjoinedGroupId?: string;
};

const tinyPng =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

async function readStoredData(filePath: string): Promise<StoredTestData | undefined> {
  try {
    return JSON.parse(await readFile(filePath, 'utf8')) as StoredTestData;
  } catch {
    return undefined;
  }
}

function assertSafeApiTarget(apiUrl: string): void {
  const parsed = new URL(apiUrl);
  const isLoopback =
    parsed.hostname === 'localhost' ||
    parsed.hostname === '127.0.0.1' ||
    parsed.hostname === '[::1]' ||
    parsed.hostname === '::1';
  if (!isLoopback && process.env.E2E_ALLOW_REMOTE_API !== '1') {
    throw new Error(
      `Refusing to seed a non-local API (${parsed.hostname}). Set E2E_ALLOW_REMOTE_API=1 only for an intentional remote test environment.`,
    );
  }
}

async function responseBody(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) return undefined;
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return text;
  }
}

function describeBody(body: unknown): string {
  if (typeof body === 'string') return body;
  if (body === undefined) return 'empty response';
  return JSON.stringify(body);
}

async function request(
  apiUrl: string,
  path: string,
  init: RequestInit = {},
): Promise<{ response: Response; body: unknown }> {
  const response = await fetch(`${apiUrl}${path}`, {
    ...init,
    headers: {
      Accept: 'application/json',
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...init.headers,
    },
  });
  return { response, body: await responseBody(response) };
}

async function login(
  apiUrl: string,
  username: string,
  password: string,
): Promise<TokenResponse | undefined> {
  const { response, body } = await request(apiUrl, '/api/v2/public/login', {
    method: 'POST',
    body: JSON.stringify({ username, password }),
  });
  if (response.status === 400 || response.status === 403) return undefined;
  if (!response.ok) {
    throw new Error(`Login request failed (${response.status}): ${describeBody(body)}`);
  }
  return body as TokenResponse;
}

async function createOrLoginUser(
  apiUrl: string,
  username: string,
  password: string,
): Promise<TokenResponse> {
  const existing = await login(apiUrl, username, password);
  if (existing) return existing;

  const { response, body } = await request(apiUrl, '/api/v2/public/signup', {
    method: 'POST',
    body: JSON.stringify({
      name: username,
      password,
      email: process.env.E2E_TEST_EMAIL ?? `${username}@example.invalid`,
    }),
  });
  if (response.ok) return body as TokenResponse;
  if (response.status === 409) {
    const retry = await login(apiUrl, username, password);
    if (retry) return retry;
    throw new Error(
      'The configured E2E test user already exists, but its password is not valid. Set E2E_TEST_PASSWORD or remove the disposable test user.',
    );
  }
  throw new Error(`Signup request failed (${response.status}): ${describeBody(body)}`);
}

async function findGroup(
  apiUrl: string,
  token: string,
  userId: string,
  groupName: string,
): Promise<Group | undefined> {
  const query = new URLSearchParams({
    search: groupName,
    userId,
    withUser: 'true',
    withImages: 'false',
    page: '0',
    size: '40',
  });
  const { response, body } = await request(apiUrl, `/api/v2/groups?${query}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!response.ok) {
    throw new Error(`Group search failed (${response.status}): ${describeBody(body)}`);
  }
  const items = (body as { items?: Group[] }).items ?? [];
  return items.find((group) => group.name === groupName);
}

async function createGroup(
  apiUrl: string,
  token: string,
  userId: string,
  groupName: string,
): Promise<Group> {
  const { response, body } = await request(apiUrl, '/api/v2/groups', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: JSON.stringify({
      name: groupName,
      description: 'Disposable group for Flutter web verification',
      visibility: 0,
      groupAdmin: userId,
      profileImage: tinyPng,
    }),
  });
  if (!response.ok) {
    throw new Error(`Group creation failed (${response.status}): ${describeBody(body)}`);
  }
  return body as Group;
}

function generatedUsername(): string {
  return `e2e${Date.now().toString(36)}${randomBytes(3).toString('hex')}`.slice(0, 29);
}

function generatedPassword(): string {
  return `E2e${randomBytes(12).toString('base64url')}`.slice(0, 29);
}

function generatedGroupName(): string {
  return `E2E Flutter Web ${Date.now().toString(36)}`;
}

export default async function globalSetup(): Promise<void> {
  const testDataPath = dataPath();
  const stored = await readStoredData(testDataPath);
  const apiUrl = normalizeApiUrl(process.env.E2E_API_URL ?? 'http://127.0.0.1:8080');
  assertSafeApiTarget(apiUrl);
  const reuseStoredData = canReuseStoredData(stored?.apiUrl, apiUrl);

  const username =
    process.env.E2E_TEST_USERNAME ??
    (reuseStoredData ? stored?.username : undefined) ??
    generatedUsername();
  const password =
    process.env.E2E_TEST_PASSWORD ??
    (reuseStoredData && stored?.username === username ? stored.password : undefined) ??
    generatedPassword();
  const groupName =
    process.env.E2E_TEST_GROUP ??
    (reuseStoredData && stored?.username === username ? stored.groupName : undefined) ??
    generatedGroupName();

  const tokens = await createOrLoginUser(apiUrl, username, password);
  const existingGroup = await findGroup(apiUrl, tokens.accessToken, tokens.userId, groupName);
  const group = existingGroup ?? (await createGroup(apiUrl, tokens.accessToken, tokens.userId, groupName));
  const data: StoredTestData = {
    apiUrl,
    username,
    password,
    groupName: group.name,
    userId: tokens.userId,
    groupId: group.id,
    publicUnjoinedGroupName: process.env.E2E_TEST_PUBLIC_UNJOINED_GROUP,
    publicUnjoinedGroupId: process.env.E2E_TEST_PUBLIC_UNJOINED_GROUP_ID,
  };

  await mkdir(dirname(testDataPath), { recursive: true, mode: 0o700 });
  await writeFile(testDataPath, `${JSON.stringify(data, null, 2)}\n`, { mode: 0o600 });
  await chmod(testDataPath, 0o600);
}
