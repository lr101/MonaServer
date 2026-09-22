import assert from 'node:assert/strict';
import test from 'node:test';

const { AdminApi, AdminHttpError } = await import('../src/api.js');

function response(status = 200, body) {
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async () => body === undefined ? '' : JSON.stringify(body),
  };
}

function recordingApi(responses = []) {
  const calls = [];
  const api = new AdminApi({
    base: 'https://admin.example/',
    fetcher: async (url, options) => {
      calls.push({ url, options });
      return responses.shift() ?? response();
    },
  });
  return { api, calls };
}

test('transport module can load in Node when a fetcher is supplied', async () => {
  await assert.doesNotReject(() => import('../src/api.js'));
});

test('maps the missing v3 operation paths, request bodies, and mutation headers', async () => {
  const { api, calls } = recordingApi([
    response(200, { csrfToken: 'rotated-token' }),
    response(200),
    response(200),
    response(202, { accepted: true, jobId: 'retry-job' }),
    response(202, { accepted: true, jobId: 'cancel-job' }),
    response(202, { accepted: true }),
    response(200),
    response(201, { id: 'note-id' }),
  ]);
  api.csrf = 'initial-token';

  await api.reauthenticate('revoke_sessions', '123456');
  await api.getUser('user/id');
  await api.getAudience('audience/id', { cursor: 'next', limit: 10 });
  await api.retryJob('retry/id', { reason: 'retry failed recipients' }, 'retry-key');
  await api.cancelJob('cancel/id', { reason: 'operator cancelled' }, 'cancel-key');
  await api.sendTestMessage({ recipientUserId: 'user-id', action: { action: 'email', subject: 'Hi', body: 'Body' } });
  await api.listReportNotes('report/id', { cursor: 'later', limit: 5 });
  await api.addReportNote('report/id', 'follow-up');

  assert.deepEqual(calls.map(({ url, options }) => [url, options.method]), [
    ['https://admin.example/api/v3/admin/session/reauthenticate', 'POST'],
    ['https://admin.example/api/v3/admin/users/user%2Fid', 'GET'],
    ['https://admin.example/api/v3/admin/audiences/audience%2Fid?cursor=next&limit=10', 'GET'],
    ['https://admin.example/api/v3/admin/jobs/retry%2Fid/retry', 'POST'],
    ['https://admin.example/api/v3/admin/jobs/cancel%2Fid/cancel', 'POST'],
    ['https://admin.example/api/v3/admin/messages/test', 'POST'],
    ['https://admin.example/api/v3/admin/reports/report%2Fid/notes?cursor=later&limit=5', 'GET'],
    ['https://admin.example/api/v3/admin/reports/report%2Fid/notes', 'POST'],
  ]);
  assert.deepEqual(calls[0].options.headers, {
    Accept: 'application/json', 'Content-Type': 'application/json', 'X-CSRF-Token': 'initial-token',
  });
  assert.equal(calls[0].options.body, JSON.stringify({ action: 'revoke_sessions', code: '123456' }));
  assert.equal(calls[3].options.headers['X-CSRF-Token'], 'rotated-token');
  assert.equal(calls[3].options.headers['Idempotency-Key'], 'retry-key');
  assert.equal(calls[3].options.body, JSON.stringify({ reason: 'retry failed recipients' }));
  assert.equal(calls[4].options.headers['Idempotency-Key'], 'cancel-key');
  assert.equal(calls[5].options.body, JSON.stringify({ recipientUserId: 'user-id', action: { action: 'email', subject: 'Hi', body: 'Body' } }));
  assert.equal(calls[7].options.body, JSON.stringify({ text: 'follow-up' }));
  assert.equal(calls[7].options.headers['X-CSRF-Token'], 'rotated-token');
  assert.equal(calls[7].options.credentials, 'include');
  assert.equal(api.csrf, 'rotated-token');
});

test('maps every bounded v3 read option and clamps page sizes to the contract range', async () => {
  const { api, calls } = recordingApi();

  await api.listUsers({
    cursor: 'users-next', limit: 101, search: 'alex', securityStatus: 'compromised',
    verifiedEmail: true, createdAfter: '2026-01-01T00:00:00Z', createdBefore: '2026-02-01T00:00:00Z',
  });
  await api.getUser('user/id');
  await api.getAudience('audience/id', { cursor: 'audience-next', limit: 0 });
  await api.listJobs({ cursor: 'jobs-next', limit: 99, status: 'queued', action: 'email' });
  await api.getJob('job/id');
  await api.listRecipients('job/id', { cursor: 'recipient-next', limit: 1000 });
  await api.listReports({ cursor: 'reports-next', limit: 1, search: 'abuse', status: 'open' });
  await api.getReport('report/id', { revision: 7 });
  await api.listReportNotes('report/id', { cursor: 'notes-next', limit: -1 });
  await api.listAudit({ cursor: 'audit-next', limit: 25, targetUserId: 'user-id', action: 'revoke_sessions' });

  assert.deepEqual(calls.map(({ url }) => url), [
    'https://admin.example/api/v3/admin/users?cursor=users-next&limit=100&search=alex&securityStatus=compromised&verifiedEmail=true&createdAfter=2026-01-01T00%3A00%3A00Z&createdBefore=2026-02-01T00%3A00%3A00Z',
    'https://admin.example/api/v3/admin/users/user%2Fid',
    'https://admin.example/api/v3/admin/audiences/audience%2Fid?cursor=audience-next&limit=1',
    'https://admin.example/api/v3/admin/jobs?cursor=jobs-next&limit=99&status=queued&action=email',
    'https://admin.example/api/v3/admin/jobs/job%2Fid',
    'https://admin.example/api/v3/admin/jobs/job%2Fid/recipients?cursor=recipient-next&limit=100',
    'https://admin.example/api/v3/admin/reports?cursor=reports-next&limit=1&search=abuse&status=open',
    'https://admin.example/api/v3/admin/reports/report%2Fid?revision=7',
    'https://admin.example/api/v3/admin/reports/report%2Fid/notes?cursor=notes-next&limit=1',
    'https://admin.example/api/v3/admin/audit?cursor=audit-next&limit=25&targetUserId=user-id&action=revoke_sessions',
  ]);
  assert.ok(calls.every(({ options }) => options.credentials === 'include'));
  assert.ok(calls.every(({ options }) => options.method === 'GET'));
});

test('does not append an empty query delimiter to an unversioned report read', async () => {
  const { api, calls } = recordingApi();

  await api.getReport('report/id');

  assert.equal(calls[0].url, 'https://admin.example/api/v3/admin/reports/report%2Fid');
});

test('binds native report update fields without losing nullable values', async () => {
  const { api, calls } = recordingApi();
  api.csrf = 'active-token';

  await api.updateReport('report/id', {
    expectedRevision: 3, status: 'open', assigneeUserId: 'assignee-id', note: null,
  }, 'report-key');

  assert.equal(calls[0].options.body, JSON.stringify({
    expectedRevision: 3, status: 'open', assigneeUserId: 'assignee-id', note: null,
  }));
});

test('keeps the latest CSRF token for authenticated mutations and returns accepted responses unchanged', async () => {
  const { api, calls } = recordingApi([
    response(200, { csrfToken: 'bootstrap-token' }),
    response(200, { csrfToken: 'restored-token' }),
    response(202, { challengeId: 'challenge-id', csrfToken: 'login-token', sessionState: 'mfa_required' }),
    response(200, { csrfToken: 'mfa-token', sessionState: 'authenticated' }),
    response(202, { accepted: true, audienceId: 'audience-id' }),
    response(202, { accepted: true, jobId: 'job-id' }),
    response(200, { id: 'report-id', revision: 2 }),
    response(204),
  ]);

  await api.bootstrap();
  await api.restore();
  await api.login('operator', 'password');
  await api.completeMfa('challenge-id', '123456');
  const preview = await api.previewAudience({ kind: 'selected', resource: 'accounts', ids: ['user-id'] }, { action: 'email', subject: 'Hi', body: 'Body' });
  const job = await api.createJob({ audienceId: 'audience-id', action: { action: 'email', subject: 'Hi', body: 'Body' } }, 'job-key');
  await api.updateReport('report/id', { expectedRevision: 1, status: 'resolved', assignee: 'clear', note: 'resolved' }, 'report-key');
  await api.logout();

  assert.deepEqual(preview, { accepted: true, audienceId: 'audience-id' });
  assert.deepEqual(job, { accepted: true, jobId: 'job-id' });
  assert.deepEqual(calls.map(({ url, options }) => [url, options.method]), [
    ['https://admin.example/api/v3/admin/session/bootstrap', 'POST'],
    ['https://admin.example/api/v3/admin/session', 'GET'],
    ['https://admin.example/api/v3/admin/session/login', 'POST'],
    ['https://admin.example/api/v3/admin/session/mfa', 'POST'],
    ['https://admin.example/api/v3/admin/audiences/preview', 'POST'],
    ['https://admin.example/api/v3/admin/jobs', 'POST'],
    ['https://admin.example/api/v3/admin/reports/report%2Fid', 'PATCH'],
    ['https://admin.example/api/v3/admin/session/logout', 'POST'],
  ]);
  assert.equal(calls[2].options.headers['X-CSRF-Token'], 'restored-token');
  assert.equal(calls[3].options.headers['X-CSRF-Token'], 'login-token');
  assert.equal(calls[4].options.headers['X-CSRF-Token'], 'mfa-token');
  assert.equal(calls[5].options.headers['Idempotency-Key'], 'job-key');
  assert.equal(calls[5].options.body, JSON.stringify({ audienceId: 'audience-id', action: { action: 'email', subject: 'Hi', body: 'Body' } }));
  assert.equal(calls[6].options.headers['Idempotency-Key'], 'report-key');
  assert.equal(calls[6].options.body, JSON.stringify({ expectedRevision: 1, status: 'resolved', assigneeUserId: null, note: 'resolved' }));
  assert.equal(calls[7].options.headers['X-CSRF-Token'], 'mfa-token');
  assert.equal(api.csrf, null);
});

test('binds session and preview request bodies exactly and keeps bounded text inputs safe', async () => {
  const { api, calls } = recordingApi([
    response(200, { csrfToken: 'bootstrap-token' }),
    response(202, { challengeId: 'challenge-id', csrfToken: 'login-token', sessionState: 'mfa_required' }),
    response(200, { csrfToken: 'mfa-token', sessionState: 'authenticated' }),
    response(200, { status: 'ready', snapshotId: 'snapshot-id' }),
  ]);

  await api.bootstrap();
  await api.login('operator', 'password');
  await api.completeMfa('challenge-id', '123456');
  await api.previewAudience({ kind: 'selected', resource: 'accounts', ids: ['user-id'] }, { action: 'login_link' });

  assert.equal(calls[1].options.body, JSON.stringify({ username: 'operator', password: 'password' }));
  assert.equal(calls[2].options.body, JSON.stringify({ challengeId: 'challenge-id', code: '123456' }));
  assert.equal(calls[3].options.body, JSON.stringify({
    audience: { kind: 'selected', resource: 'accounts', ids: ['user-id'] },
    action: { action: 'login_link' },
  }));

  const longSearch = 'x'.repeat(300);
  await api.listUsers({ search: longSearch });
  assert.equal(new URL(calls[4].url).searchParams.get('search').length, 256);
  assert.throws(() => api.listReports({ cursor: 'x'.repeat(513) }), (error) => error instanceof AdminHttpError && error.status === 400);
  await api.getReport('report-id', { revision: -5 });
  assert.equal(new URL(calls[5].url).searchParams.get('revision'), '0');
});

test('raises typed HTTP failures, clears CSRF after an unauthorized response, and blocks CSRF mutations before fetch', async () => {
  const { api, calls } = recordingApi([
    response(403, { message: 'Missing capability' }),
    response(401, { error: 'Session expired' }),
  ]);
  api.csrf = 'active-token';

  await assert.rejects(api.listUsers(), (error) => {
    assert.ok(error instanceof AdminHttpError);
    assert.equal(error.status, 403);
    assert.equal(error.message, 'Missing capability');
    assert.equal(error.forbidden, true);
    return true;
  });
  await assert.rejects(api.createJob({ audienceId: 'audience-id', action: { action: 'email', subject: 'Hi', body: 'Body' } }, 'job-key'), (error) => {
    assert.ok(error instanceof AdminHttpError);
    assert.equal(error.status, 401);
    assert.equal(error.unauthorized, true);
    assert.equal(error.message, 'Session expired');
    return true;
  });
  await assert.rejects(api.sendTestMessage({ recipientUserId: 'user-id', action: { action: 'email', subject: 'Hi', body: 'Body' } }), (error) => {
    assert.ok(error instanceof AdminHttpError);
    assert.equal(error.status, 428);
    return true;
  });

  assert.equal(calls.length, 2);
  assert.equal(api.csrf, null);
});

test('keeps the bootstrap CSRF token when restore reports an unauthenticated session', async () => {
  const { api, calls } = recordingApi([
    response(200, { csrfToken: 'pre-auth-token' }),
    response(401, { message: 'No admin session' }),
    response(202, { challengeId: 'challenge-id', csrfToken: 'login-token', sessionState: 'mfa_required' }),
  ]);

  await api.bootstrap();
  await assert.rejects(api.restore(), (error) => error instanceof AdminHttpError && error.status === 401);
  await api.login('operator', 'password');

  assert.equal(calls[2].url, 'https://admin.example/api/v3/admin/session/login');
  assert.equal(calls[2].options.headers['X-CSRF-Token'], 'pre-auth-token');
});

test('does not send job mutations without their required idempotency key', async () => {
  const { api, calls } = recordingApi();
  api.csrf = 'active-token';

  for (const operation of [
    () => api.createJob({ audienceId: 'audience-id', action: { action: 'email', subject: 'Hi', body: 'Body' } }),
    () => api.retryJob('job-id', { reason: 'retry failed recipients' }),
    () => api.cancelJob('job-id', { reason: 'operator cancelled' }),
  ]) {
    await assert.rejects(operation(), (error) => error instanceof AdminHttpError && error.status === 428);
  }

  assert.equal(calls.length, 0);
});
