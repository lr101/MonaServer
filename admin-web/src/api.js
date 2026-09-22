const defaultBase = globalThis.window?.ADMIN_API_BASE ?? '';

export class AdminHttpError extends Error {
  constructor(status, message = '') {
    super(message || `Admin request failed (${status})`);
    this.name = 'AdminHttpError';
    this.status = status;
  }

  get unauthorized() {
    return this.status === 401;
  }

  get forbidden() {
    return this.status === 403;
  }
}

export class AdminApi {
  constructor({ base = defaultBase, fetcher = window.fetch.bind(window) } = {}) {
    this.base = base.replace(/\/$/, '');
    this.fetcher = fetcher;
    this.csrf = null;
  }

  async request(path, { method = 'GET', body, csrf = false, idempotencyKey, requireIdempotency = false } = {}) {
    const headers = { Accept: 'application/json' };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (csrf) {
      if (!this.csrf) throw new AdminHttpError(428, 'The admin session is not ready.');
      headers['X-CSRF-Token'] = this.csrf;
    }
    if (requireIdempotency && !idempotencyKey) {
      throw new AdminHttpError(428, 'This action requires an idempotency key.');
    }
    if (idempotencyKey) headers['Idempotency-Key'] = idempotencyKey;
    const response = await this.fetcher(`${this.base}${path}`, {
      method,
      credentials: 'include',
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (response.status === 401) this.csrf = null;
    const text = await response.text();
    let value = null;
    if (text) {
      try {
        value = JSON.parse(text);
      } catch {
        value = null;
      }
    }
    if (!response.ok) {
      throw new AdminHttpError(response.status, value?.message ?? value?.error);
    }
    if (value?.csrfToken) this.csrf = value.csrfToken;
    return value;
  }

  bootstrap() {
    return this.request('/api/v3/admin/session/bootstrap', { method: 'POST' });
  }

  restore() {
    return this.request('/api/v3/admin/session');
  }

  login(username, password) {
    return this.request('/api/v3/admin/session/login', {
      method: 'POST',
      csrf: true,
      body: { username, password },
    });
  }

  completeMfa(challengeId, code) {
    return this.request('/api/v3/admin/session/mfa', {
      method: 'POST',
      csrf: true,
      body: { challengeId, code },
    });
  }

  reauthenticate(action, code) {
    return this.request('/api/v3/admin/session/reauthenticate', {
      method: 'POST',
      csrf: true,
      body: { action, code },
    });
  }

  logout() {
    return this.request('/api/v3/admin/session/logout', { method: 'POST', csrf: true })
      .finally(() => { this.csrf = null; });
  }

  listUsers({ cursor, limit = 25, search = '', securityStatus, verifiedEmail, createdAfter, createdBefore } = {}) {
    return this.request(`/api/v3/admin/users?${query({
      cursor, limit, search, securityStatus, verifiedEmail, createdAfter, createdBefore,
    })}`);
  }

  getUser(userId) {
    return this.request(`/api/v3/admin/users/${encodeURIComponent(userId)}`);
  }

  listReports({ cursor, limit = 25, search = '', status } = {}) {
    return this.request(`/api/v3/admin/reports?${query({ cursor, limit, search, status })}`);
  }

  getReport(reportId, { revision } = {}) {
    const params = query({ revision });
    const path = `/api/v3/admin/reports/${encodeURIComponent(reportId)}`;
    return this.request(params.size ? `${path}?${params}` : path);
  }

  updateReport(reportId, update, idempotencyKey) {
    const body = { expectedRevision: update.expectedRevision, status: update.status };
    if (Object.hasOwn(update, 'assigneeUserId')) body.assigneeUserId = update.assigneeUserId;
    else if (update.assignee === 'clear') body.assigneeUserId = null;
    else if (update.assignee) body.assigneeUserId = update.assignee;
    if (Object.hasOwn(update, 'note')) body.note = update.note;
    return this.request(`/api/v3/admin/reports/${encodeURIComponent(reportId)}`, {
      method: 'PATCH', csrf: true, body, idempotencyKey,
    });
  }

  previewAudience(audience, action) {
    return this.request('/api/v3/admin/audiences/preview', {
      method: 'POST', csrf: true, body: { audience, action },
    });
  }

  getAudience(audienceId, { cursor, limit = 25 } = {}) {
    return this.request(`/api/v3/admin/audiences/${encodeURIComponent(audienceId)}?${query({ cursor, limit })}`);
  }

  createJob(request, idempotencyKey) {
    return this.request('/api/v3/admin/jobs', {
      method: 'POST', csrf: true, body: request, idempotencyKey, requireIdempotency: true,
    });
  }

  listJobs({ cursor, limit = 25, status, action } = {}) {
    return this.request(`/api/v3/admin/jobs?${query({ cursor, limit, status, action })}`);
  }

  getJob(jobId) {
    return this.request(`/api/v3/admin/jobs/${encodeURIComponent(jobId)}`);
  }

  listRecipients(jobId, { cursor, limit = 25 } = {}) {
    return this.request(`/api/v3/admin/jobs/${encodeURIComponent(jobId)}/recipients?${query({ cursor, limit })}`);
  }

  retryJob(jobId, command, idempotencyKey) {
    return this.request(`/api/v3/admin/jobs/${encodeURIComponent(jobId)}/retry`, {
      method: 'POST', csrf: true, body: command, idempotencyKey, requireIdempotency: true,
    });
  }

  cancelJob(jobId, command, idempotencyKey) {
    return this.request(`/api/v3/admin/jobs/${encodeURIComponent(jobId)}/cancel`, {
      method: 'POST', csrf: true, body: command, idempotencyKey, requireIdempotency: true,
    });
  }

  sendTestMessage(request) {
    return this.request('/api/v3/admin/messages/test', {
      method: 'POST', csrf: true, body: request,
    });
  }

  listReportNotes(reportId, { cursor, limit = 25 } = {}) {
    return this.request(`/api/v3/admin/reports/${encodeURIComponent(reportId)}/notes?${query({ cursor, limit })}`);
  }

  addReportNote(reportId, text) {
    return this.request(`/api/v3/admin/reports/${encodeURIComponent(reportId)}/notes`, {
      method: 'POST', csrf: true, body: { text },
    });
  }

  listAudit({ cursor, limit = 25, targetUserId, action } = {}) {
    return this.request(`/api/v3/admin/audit?${query({ cursor, limit, targetUserId, action })}`);
  }
}

function query(values) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(values)) {
    if (value !== undefined && value !== null && value !== '') {
      params.set(key, key === 'limit' ? boundedLimit(value) : value);
    }
  }
  return params;
}

function boundedLimit(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 25;
  return Math.min(100, Math.max(1, Math.floor(parsed)));
}
