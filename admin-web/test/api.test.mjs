import assert from 'node:assert/strict';
import test from 'node:test';

const { AdminApi, AdminHttpError } = await import('../src/api.js');
const { reauthenticationActionFor } = await import('../src/permissions.js');

function response(status = 200, body) {
  return { ok: status >= 200 && status < 300, status, text: async () => body === undefined ? '' : JSON.stringify(body) };
}

function recordingApi(responses = []) {
  const calls = [];
  const api = new AdminApi({ base: 'https://admin.example/', fetcher: async (url, options) => { calls.push({ url, options }); return responses.shift() ?? response(); } });
  return { api, calls };
}

test('maps CRUD pages to capability-bound reauthentication actions', () => {
  assert.equal(reauthenticationActionFor('reports'), 'reports.review');
  assert.equal(reauthenticationActionFor('campaigns'), 'campaigns.write');
});

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
