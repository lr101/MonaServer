import assert from 'node:assert/strict';
import test from 'node:test';

const { AdminApi, AdminHttpError } = await import('../src/api.js');

function response(status = 200, body) {
  return { ok: status >= 200 && status < 300, status, text: async () => body === undefined ? '' : JSON.stringify(body) };
}

function recordingApi(responses = []) {
  const calls = [];
  const api = new AdminApi({ base: 'https://admin.example/', fetcher: async (url, options) => { calls.push({ url, options }); return responses.shift() ?? response(); } });
  return { api, calls };
}

test('keeps cookies, CSRF in memory, and the pre-auth token across restore 401', async () => {
  const { api, calls } = recordingApi([
    response(200, { csrfToken: 'pre-auth-token' }),
    response(401, { message: 'No admin session' }),
    response(202, { challengeId: 'challenge-id', csrfToken: 'login-token', sessionState: 'mfa_required' }),
    response(200, { csrfToken: 'mfa-token', sessionState: 'authenticated' }),
  ]);
  await api.bootstrap();
  await assert.rejects(api.restore(), (error) => error instanceof AdminHttpError && error.status === 401);
  await api.login('operator', 'password');
  await api.completeMfa('challenge-id', '123456');
  assert.equal(calls[2].options.credentials, 'include');
  assert.equal(calls[2].options.headers['X-CSRF-Token'], 'pre-auth-token');
  assert.equal(calls[2].options.body, JSON.stringify({ username: 'operator', password: 'password' }));
  assert.equal(calls[3].options.headers['X-CSRF-Token'], 'login-token');
  assert.equal(calls[3].options.body, JSON.stringify({ challengeId: 'challenge-id', code: '123456' }));
  assert.equal(api.csrf, 'mfa-token');
});

test('bounds bootstrap and session restoration when the server never responds', async () => {
  for (const method of ['bootstrap', 'restore']) {
    let signal;
    const api = new AdminApi({
      base: 'https://admin.example/',
      sessionRequestTimeoutMs: 10,
      fetcher: async (_url, options) => {
        signal = options.signal;
        return new Promise(() => {});
      },
    });

    let deadlineId;
    const outcome = await Promise.race([
      api[method]().then(() => ({ resolved: true }), (error) => ({ error })),
      new Promise((resolve) => { deadlineId = setTimeout(() => resolve({ hung: true }), 100); }),
    ]);
    clearTimeout(deadlineId);
    assert.equal(outcome.hung, undefined, `${method} should settle before the test deadline`);
    assert.ok(outcome.error instanceof AdminHttpError);
    assert.equal(outcome.error.status, 408);
    assert.match(outcome.error.message, /try again/i);
    assert.equal(signal.aborted, true);
  }
});

test('ignores a bootstrap response that arrives after its timeout', async () => {
  let resolveFetch;
  let bodyRead = false;
  const api = new AdminApi({
    base: 'https://admin.example/',
    sessionRequestTimeoutMs: 10,
    fetcher: () => new Promise((resolve) => { resolveFetch = resolve; }),
  });

  await assert.rejects(api.bootstrap(), (error) => error instanceof AdminHttpError && error.status === 408);
  resolveFetch({
    ok: true,
    status: 200,
    text: async () => {
      bodyRead = true;
      return JSON.stringify({ csrfToken: 'late-token' });
    },
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(bodyRead, false);
  assert.equal(api.csrf, null);
});

test('ignores a bootstrap body that arrives after its timeout', async () => {
  let resolveBody;
  const api = new AdminApi({
    base: 'https://admin.example/',
    sessionRequestTimeoutMs: 10,
    fetcher: async () => ({
      ok: true,
      status: 200,
      text: () => new Promise((resolve) => { resolveBody = resolve; }),
    }),
  });

  await assert.rejects(api.bootstrap(), (error) => error instanceof AdminHttpError && error.status === 408);
  resolveBody(JSON.stringify({ csrfToken: 'late-token' }));
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(api.csrf, null);
});

test('shares an in-flight bootstrap so concurrent callers use one cookie and CSRF token', async () => {
  let calls = 0;
  const releases = [];
  const api = new AdminApi({
    base: 'https://admin.example/',
    sessionRequestTimeoutMs: 500,
    fetcher: () => {
      calls += 1;
      return new Promise((resolve) => releases.push(resolve));
    },
  });

  const first = api.bootstrap();
  const second = api.bootstrap();
  const sharesRequest = first === second;
  for (const release of releases) release(response(200, { csrfToken: 'pre-auth-token' }));
  await Promise.allSettled([first, second]);

  assert.equal(sharesRequest, true);
  assert.equal(calls, 1);
  assert.equal(api.csrf, 'pre-auth-token');
});

test('uses the pre-auth CSRF token for one-time admin setup without persisting the TOTP secret', async () => {
  const { api, calls } = recordingApi([
    response(200, { csrfToken: 'pre-auth-token' }),
    response(201, { userId: 'first-user', totpSecret: 'BASE32SECRET' }),
  ]);
  await api.bootstrap();
  const enrollment = await api.setupInitialAdmin('operator', 'password', 'setup-secret');
  assert.equal(enrollment.totpSecret, 'BASE32SECRET');
  assert.equal(calls[1].url, 'https://admin.example/api/v3/admin/session/initial-setup');
  assert.equal(calls[1].options.credentials, 'include');
  assert.equal(calls[1].options.headers['X-CSRF-Token'], 'pre-auth-token');
  assert.equal(calls[1].options.body, JSON.stringify({ username: 'operator', password: 'password', setupToken: 'setup-secret' }));
  assert.equal(api.csrf, 'pre-auth-token');
});

test('maps bounded CRUD reads and never sends oversized query values', async () => {
  const { api, calls } = recordingApi();
  await api.listUsers({ cursor: 'users-next', limit: 101, search: 'x'.repeat(300), securityStatus: 'normal', verifiedEmail: true });
  await api.getUser('user/id');
  await api.listReports({ cursor: 'reports-next', limit: 1, search: 'abuse', status: 'open' });
  await api.getReport('report/id', { revision: -5 });
  await api.listReportNotes('report/id', { cursor: 'notes-next', limit: 1000 });
  await api.listAudit({ cursor: 'audit-next', limit: 25, targetUserId: 'user-id', action: 'report_resolve' });
  assert.equal(new URL(calls[0].url).searchParams.get('limit'), '100');
  assert.equal(new URL(calls[0].url).searchParams.get('search').length, 256);
  assert.equal(new URL(calls[3].url).searchParams.get('revision'), '0');
  assert.ok(calls.every(({ options }) => options.credentials === 'include'));
  assert.ok(calls.every(({ options }) => options.method === 'GET'));
  assert.throws(() => api.listUsers({ cursor: 'x'.repeat(513) }), (error) => error instanceof AdminHttpError && error.status === 400);
});

test('verifies a user email using the authenticated CSRF token', async () => {
  const { api, calls } = recordingApi([response(200, { id: 'user-id', emailVerified: true })]);
  api.csrf = 'active-token';
  const user = await api.verifyUserEmail('user/id');
  assert.equal(user.emailVerified, true);
  assert.equal(calls[0].url, 'https://admin.example/api/v3/admin/users/user%2Fid/verify-email');
  assert.equal(calls[0].options.method, 'POST');
  assert.equal(calls[0].options.headers['X-CSRF-Token'], 'active-token');
});

test('queues a login link for one selected account', async () => {
  const { api, calls } = recordingApi([response(202)]);
  api.csrf = 'active-token';
  await api.sendUserLoginLink('user/id');
  assert.equal(calls[0].url, 'https://admin.example/api/v3/admin/users/user%2Fid/login-link');
  assert.equal(calls[0].options.method, 'POST');
  assert.equal(calls[0].options.headers['X-CSRF-Token'], 'active-token');
});

test('binds report updates with tri-state assignment and report notes', async () => {
  const { api, calls } = recordingApi([response(200, { id: 'report-id' }), response(201, { id: 'note-id' })]);
  api.csrf = 'active-token';
  await api.updateReport('report/id', { expectedRevision: 3, status: 'resolved', assignee: 'clear', note: 'done' });
  await api.addReportNote('report/id', 'follow-up');
  assert.equal(calls[0].options.method, 'PATCH');
  assert.equal(calls[0].options.body, JSON.stringify({ expectedRevision: 3, status: 'resolved', assigneeUserId: null, note: 'done' }));
  assert.equal(calls[1].options.body, JSON.stringify({ text: 'follow-up' }));
  assert.equal(calls[1].options.headers['X-CSRF-Token'], 'active-token');
});

test('maps bounded campaign reads and revision-checked content mutations', async () => {
  const { api, calls } = recordingApi([
    response(200, { items: [] }),
    response(200, { id: 'campaign-id' }),
    response(201, { id: 'campaign-id', revision: 1 }),
    response(200, { id: 'campaign-id', revision: 2 }),
  ]);
  api.csrf = 'active-token';

  await api.listCampaigns({ cursor: 'campaigns-next', limit: 101 });
  await api.getCampaign('campaign/id');
  await api.createCampaign({
    name: 'September newsletter', channel: 'email', subject: 'September', title: null, body: 'Hello', status: 'draft',
  });
  await api.updateCampaign('campaign/id', {
    name: 'September newsletter', channel: 'push', subject: null, title: 'September', body: 'Hello', status: 'active', expectedRevision: 1,
  });

  assert.equal(new URL(calls[0].url).pathname, '/api/v3/admin/campaigns');
  assert.equal(new URL(calls[0].url).searchParams.get('cursor'), 'campaigns-next');
  assert.equal(new URL(calls[0].url).searchParams.get('limit'), '100');
  assert.equal(calls[1].url, 'https://admin.example/api/v3/admin/campaigns/campaign%2Fid');
  assert.equal(calls[2].options.method, 'POST');
  assert.equal(calls[2].options.headers['X-CSRF-Token'], 'active-token');
  assert.equal(calls[2].options.body, JSON.stringify({
    name: 'September newsletter', channel: 'email', subject: 'September', title: null, body: 'Hello', status: 'draft',
  }));
  assert.equal(calls[3].options.method, 'PATCH');
  assert.equal(calls[3].options.body, JSON.stringify({
    name: 'September newsletter', channel: 'push', subject: null, title: 'September', body: 'Hello', status: 'active', expectedRevision: 1,
  }));
});

test('uses CSRF and expected revisions for campaign archival and deletion', async () => {
  const { api, calls } = recordingApi([response(200, { id: 'campaign-id', status: 'archived' }), response(204)]);
  api.csrf = 'active-token';

  await api.archiveCampaign('campaign/id', 2);
  await api.deleteCampaign('campaign/id', 3);

  assert.equal(calls[0].url, 'https://admin.example/api/v3/admin/campaigns/campaign%2Fid/archive');
  assert.equal(calls[0].options.method, 'POST');
  assert.equal(calls[0].options.headers['X-CSRF-Token'], 'active-token');
  assert.equal(calls[0].options.body, JSON.stringify({ expectedRevision: 2 }));
  assert.equal(calls[1].url, 'https://admin.example/api/v3/admin/campaigns/campaign%2Fid');
  assert.equal(calls[1].options.method, 'DELETE');
  assert.equal(calls[1].options.headers['X-CSRF-Token'], 'active-token');
  assert.equal(calls[1].options.body, JSON.stringify({ expectedRevision: 3 }));
});

test('keeps CSRF and exposes a typed conflict for a rejected campaign mutation', async () => {
  const { api } = recordingApi([response(409, { message: 'Campaign changed' })]);
  api.csrf = 'active-token';

  await assert.rejects(
    api.archiveCampaign('campaign-id', 2),
    (error) => error instanceof AdminHttpError && error.status === 409 && error.message === 'Campaign changed',
  );
  assert.equal(api.csrf, 'active-token');
});

test('rotates CSRF and exposes typed 401/403 failures', async () => {
  const { api, calls } = recordingApi([response(403, { message: 'Missing capability' }), response(401, { error: 'Expired' })]);
  api.csrf = 'active-token';
  await assert.rejects(api.listUsers(), (error) => error instanceof AdminHttpError && error.status === 403 && error.forbidden);
  await assert.rejects(api.getReport('report/id'), (error) => error instanceof AdminHttpError && error.status === 401 && error.unauthorized);
  assert.equal(api.csrf, null);
  assert.equal(calls.length, 2);
});
