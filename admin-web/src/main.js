import { AdminApi, AdminHttpError } from './api.js';
import { AdminState } from './state.js';

const root = document.querySelector('#app');
const api = new AdminApi();
const state = new AdminState({ page: 'overview', loaded: false, items: [] });
let challengeId = null;

state.subscribe(render);
render(state.value);
start();

async function start() {
  try {
    await api.bootstrap();
    const session = await api.restore();
    state.update({ session: session?.sessionState === 'authenticated' ? 'authenticated' : 'login', sessionData: session });
  } catch (error) {
    state.update({ session: error instanceof AdminHttpError && error.status === 401 ? 'login' : 'error', error: message(error) });
  }
}

function render(value) {
  if (value.session === 'unknown') { root.innerHTML = '<div class="loading">Loading admin session…</div>'; return; }
  if (value.session === 'error') {
    root.innerHTML = `<section class="card narrow"><p class="eyebrow">MonaServer</p><h1>Admin unavailable</h1><p>${escape(value.error)}</p><button data-action="retry">Retry</button></section>`;
    root.querySelector('[data-action="retry"]').addEventListener('click', start); return;
  }
  if (value.session === 'login' || value.session === 'mfa') { renderLogin(value); return; }
  renderShell(value);
}

function renderLogin(value) {
  const mfa = value.session === 'mfa';
  root.innerHTML = `<section class="card narrow"><p class="eyebrow">MonaServer</p><h1>Admin workspace</h1><p>${mfa ? 'Enter the authenticator code to continue.' : 'Sign in with your administrator account.'}</p><form id="login-form">${mfa ? '<label>Authenticator code<input name="code" inputmode="numeric" autocomplete="one-time-code" required></label>' : '<label>Username<input name="username" autocomplete="username" required></label><label>Password<input name="password" type="password" autocomplete="current-password" required></label>'}<button type="submit" ${value.busy ? 'disabled' : ''}>${value.busy ? 'Working…' : (mfa ? 'Verify MFA' : 'Continue')}</button></form>${value.error ? `<p class="error" role="alert">${escape(value.error)}</p>` : ''}</section>`;
  root.querySelector('#login-form').addEventListener('submit', mfa ? submitMfa : submitLogin);
}

async function submitLogin(event) {
  event.preventDefault(); const form = new FormData(event.currentTarget); state.update({ busy: true, error: null });
  try { const result = await api.login(form.get('username'), form.get('password')); challengeId = result.challengeId; state.update({ session: 'mfa', busy: false }); } catch (error) { state.update({ busy: false, error: message(error) }); }
}

async function submitMfa(event) {
  event.preventDefault(); const form = new FormData(event.currentTarget); state.update({ busy: true, error: null });
  try { const session = await api.completeMfa(challengeId, form.get('code')); state.update({ session: 'authenticated', sessionData: session, busy: false, loaded: false }); } catch (error) { state.update({ busy: false, error: message(error) }); }
}

function renderShell(value) {
  const pages = ['overview', 'users', 'reports', 'campaigns', 'jobs', 'audit'];
  root.innerHTML = `<div class="shell"><header><div><p class="eyebrow">MonaServer</p><h1>Admin workspace</h1></div><div class="header-actions"><span class="muted">${escape(value.sessionData?.username ?? value.sessionData?.adminUsername ?? '')}</span><button data-action="logout">Sign out</button></div></header><nav aria-label="Admin sections">${pages.map((page) => `<button class="nav-button ${value.page === page ? 'selected' : ''}" data-page="${page}">${title(page)}</button>`).join('')}</nav><section class="content"><div class="toolbar"><div><p class="eyebrow">${title(value.page)}</p><h2>${heading(value.page)}</h2></div></div>${value.error ? `<p class="error" role="alert">${escape(value.error)}</p>` : ''}${value.notice ? `<p class="notice" role="status">${escape(value.notice)}</p>` : ''}${value.reauth ? reauthMarkup(value) : ''}${pageTools(value)}<div id="page-content">${pageMarkup(value)}</div></section></div>`;
  root.querySelectorAll('[data-page]').forEach((button) => button.addEventListener('click', () => selectPage(button.dataset.page)));
  root.querySelector('[data-action="logout"]').addEventListener('click', logout);
  root.querySelector('#reauth-form')?.addEventListener('submit', submitReauthentication);
  bindPage(value);
}

function reauthMarkup(value) { return `<section class="notice"><strong>Recent MFA required</strong><p>${escape(value.reauth.message ?? 'Confirm this sensitive action with your authenticator.')}</p><form id="reauth-form" class="inline-form"><input name="code" inputmode="numeric" autocomplete="one-time-code" placeholder="MFA code" required><button ${value.busy ? 'disabled' : ''}>Confirm</button></form></section>`; }

function pageTools(value) {
  if (value.page === 'users') return `<form id="user-search" class="inline-form"><input name="search" value="${escape(value.filters?.search ?? '')}" placeholder="Search username or email"><button ${value.busy ? 'disabled' : ''}>Search</button></form>`;
  if (value.page === 'reports') return `<form id="report-search" class="inline-form"><input name="search" value="${escape(value.filters?.search ?? '')}" placeholder="Search reports"><select name="status"><option value="">All statuses</option>${['open', 'resolved', 'dismissed'].map((status) => `<option value="${status}" ${value.filters?.status === status ? 'selected' : ''}>${title(status)}</option>`).join('')}</select><button ${value.busy ? 'disabled' : ''}>Search</button></form>`;
  if (value.page === 'campaigns') return '<p class="muted">Preview recipients before creating a queued operation. The server remains authoritative for eligibility and capabilities.</p>';
  if (value.page === 'jobs') return `<form id="job-search" class="inline-form"><select name="status"><option value="">All job statuses</option>${['queued', 'running', 'completed', 'failed', 'cancelled'].map((status) => `<option value="${status}" ${value.filters?.status === status ? 'selected' : ''}>${title(status)}</option>`).join('')}</select><button ${value.busy ? 'disabled' : ''}>Refresh jobs</button></form>`;
  if (value.page === 'audit') return `<form id="audit-search" class="inline-form"><input name="targetUserId" value="${escape(value.filters?.targetUserId ?? '')}" placeholder="Target user ID"><input name="action" value="${escape(value.filters?.action ?? '')}" placeholder="Action"><button ${value.busy ? 'disabled' : ''}>Search</button></form>`;
  return '';
}

function pageMarkup(value) {
  if (value.busy && !value.detail) return '<div class="loading">Loading…</div>';
  if (value.page === 'overview') return overviewMarkup(value);
  if (value.page === 'users') return usersMarkup(value);
  if (value.page === 'reports') return reportsMarkup(value);
  if (value.page === 'campaigns') return campaignsMarkup(value);
  if (value.page === 'jobs') return jobsMarkup(value);
  if (value.page === 'audit') return auditMarkup(value);
  return '';
}

function overviewMarkup(value) { return `<div class="grid"><article class="card"><h3>Session</h3><p>Authenticated administrator session with server-side capability checks.</p><span class="badge">${escape(value.sessionData?.sessionState ?? 'authenticated')}</span></article><article class="card"><h3>Safety boundary</h3><p>Mutations require CSRF, recent MFA where applicable, and server-bound idempotency.</p><span class="badge">Server enforced</span></article><article class="card"><h3>Delivery state</h3><p>Accepted operations are queued and must be monitored from Jobs. The browser never claims provider delivery.</p></article></div>`; }

function usersMarkup(value) {
  if (value.detail) return userDetailMarkup(value);
  return collectionMarkup(value.items, (record) => `<button class="record card" data-user-id="${escape(record.userId ?? record.id)}"><div><h3>${escape(record.username ?? record.email ?? 'Account')}</h3><p class="muted">${escape(record.userId ?? record.id ?? '')}</p></div><span class="badge">${escape(record.securityStatus ?? record.status ?? 'unknown')}</span></button>`, value.nextCursor, 'users');
}
function userDetailMarkup(value) { const user = value.detail; return `<div class="detail-actions"><button data-action="back">Back to users</button></div><article class="card"><h3>${escape(user.username ?? user.email ?? 'Account')}</h3><dl>${field('User ID', user.userId ?? user.id)}${field('Email', user.email)}${field('Security status', user.securityStatus ?? user.status)}${field('Email verified', user.verifiedEmail)}${field('Device count', user.deviceCount)}${field('Created', formatDate(user.createdAt))}</dl></article><section class="card"><h3>Available actions</h3><p class="muted">Action authorization and recipient eligibility are decided by the server at preview and execution time.</p></section>`; }

function reportsMarkup(value) {
  if (value.detail) return reportDetailMarkup(value);
  return collectionMarkup(value.items, (record) => `<button class="record card" data-report-id="${escape(record.reportId ?? record.id)}"><div><h3>${escape(record.title ?? record.reason ?? 'Report')}</h3><p class="muted">${escape(record.reportId ?? record.id ?? '')}</p></div><span class="badge">${escape(record.status ?? 'open')}</span></button>`, value.nextCursor, 'reports');
}
function reportDetailMarkup(value) { const report = value.detail; const notes = value.notes ?? []; return `<div class="detail-actions"><button data-action="back">Back to reports</button></div><article class="card"><h3>${escape(report.title ?? report.reason ?? 'Report')}</h3><dl>${field('Report ID', report.reportId ?? report.id)}${field('Status', report.status)}${field('Revision', report.revision ?? report.currentRevision)}${field('Reporter', report.reporterUserId)}${field('Target', report.targetUserId)}${field('Created', formatDate(report.createdAt))}</dl><p>${escape(report.description ?? report.body ?? '')}</p><form id="report-update" class="stack-form"><input type="hidden" name="expectedRevision" value="${escape(report.revision ?? report.currentRevision ?? '')}"><label>Status<select name="status"><option value="open" ${report.status === 'open' ? 'selected' : ''}>Open</option><option value="resolved" ${report.status === 'resolved' ? 'selected' : ''}>Resolved</option><option value="dismissed" ${report.status === 'dismissed' ? 'selected' : ''}>Dismissed</option></select></label><label>Assignee <span class="muted">(leave unchanged unless selected)</span><input name="assignee" placeholder="Admin user ID"></label><label><input type="checkbox" name="clearAssignee"> Clear assignment</label><label>Note<textarea name="note" rows="3"></textarea></label><button ${value.busy ? 'disabled' : ''}>Save report</button></form></article><section class="card"><h3>Notes</h3>${notes.length ? `<div class="records">${notes.map((note) => `<article class="note"><p>${escape(note.text ?? '')}</p><small>${escape(note.authorUserId ?? '')} · ${formatDate(note.createdAt)}</small></article>`).join('')}</div>` : '<p class="muted">No notes.</p>'}<form id="note-form" class="stack-form"><label>Add note<textarea name="text" rows="2" required></textarea></label><button ${value.busy ? 'disabled' : ''}>Add note</button></form></section>`; }

function campaignsMarkup(value) { const preview = value.preview; return `<div class="grid two"><section class="card"><h3>Audience and action</h3><form id="campaign-form" class="stack-form"><label>Action<select name="action"><option value="email">Email</option><option value="push">Push notification</option><option value="login_link">Login link</option><option value="recovery_resend">Recovery resend</option><option value="revoke_sessions">Revoke sessions</option><option value="mark_compromised">Mark compromised</option></select></label><label>Audience kind<select name="audienceKind"><option value="selected">Selected IDs</option><option value="filter">Filter</option><option value="all">All resource records</option></select></label><label>Resource<select name="resource"><option value="accounts">Accounts</option><option value="reports">Reports</option></select></label><label>IDs / filter JSON<textarea name="audienceValue" rows="4" placeholder="For selected: one UUID per line; for filter: JSON object"></textarea></label><label>Action payload JSON<textarea name="payload" rows="5" placeholder="{ &quot;subject&quot;: &quot;...&quot;, &quot;body&quot;: &quot;...&quot; }"></textarea></label><button ${value.busy ? 'disabled' : ''}>Preview audience</button></form></section><section class="card"><h3>Preview</h3>${preview ? previewMarkup(preview) : '<p class="muted">No preview yet.</p>'}</section></div><section class="card"><h3>Send test message</h3><form id="test-message-form" class="inline-form"><select name="action"><option value="email">Email</option><option value="push">Push</option><option value="login_link">Login link</option></select><input name="recipientUserId" placeholder="Recipient user ID" required><button ${value.busy ? 'disabled' : ''}>Send test</button></form></section>`; }
function previewMarkup(preview) { const status = preview.status ?? 'unknown'; const ready = status === 'ready'; return `<p><span class="badge">${escape(status)}</span> ${escape(preview.resource ?? '')}</p>${field('Snapshot', preview.snapshotId)}${field('Eligible', preview.eligibleCount ?? preview.recipientCount ?? preview.counts?.eligible)}${field('Excluded', preview.excludedCount ?? preview.counts?.excluded)}${field('Expires', formatDate(preview.expiresAt))}${preview.exclusions ? `<details><summary>Exclusions</summary><pre>${escape(JSON.stringify(preview.exclusions, null, 2))}</pre></details>` : ''}${preview.jobId ? `<p class="muted">Preview queued as ${escape(preview.jobId)}.</p>` : ''}${ready ? '<button data-action="create-job">Create queued job</button>' : '<p class="muted">A ready preview is required before a job can be created.</p>'}`; }

function jobsMarkup(value) { if (value.detail) return jobDetailMarkup(value); return collectionMarkup(value.items, (record) => `<button class="record card" data-job-id="${escape(record.jobId ?? record.id)}"><div><h3>${escape(record.action?.action ?? record.action ?? 'Job')}</h3><p class="muted">${escape(record.jobId ?? record.id ?? '')}</p></div><span class="badge">${escape(record.status ?? 'unknown')}</span></button>`, value.nextCursor, 'jobs'); }
function jobDetailMarkup(value) { const job = value.detail; const recipients = value.recipients ?? []; return `<div class="detail-actions"><button data-action="back">Back to jobs</button></div><article class="card"><h3>${escape(job.action?.action ?? job.action ?? 'Job')}</h3><dl>${field('Job ID', job.jobId)}${field('Status', job.status)}${field('Snapshot', job.snapshotId)}${field('Created', formatDate(job.createdAt))}${field('Updated', formatDate(job.updatedAt))}${field('Completed', job.counts?.completed)}${field('Failed', job.counts?.failed)}</dl><p>${job.cancellationRequested ? 'Cancellation requested.' : ''}</p><div class="detail-actions"><button data-action="retry-job" ${value.busy ? 'disabled' : ''}>Retry failed</button><button data-action="cancel-job" ${value.busy ? 'disabled' : ''}>Cancel job</button></div></article><section class="card"><h3>Recipients</h3>${recipients.length ? `<div class="records">${recipients.map((recipient) => `<article class="record"><div><strong>${escape(recipient.accountId ?? '')}</strong><p class="muted">Attempts: ${escape(recipient.attemptCount ?? 0)} · Devices: ${escape(recipient.deviceCount ?? 0)}</p></div><span class="badge">${escape(recipient.outcome ?? recipient.reason ?? 'pending')}</span></article>`).join('')}</div>` : '<p class="muted">No recipient records returned.</p>'}</section>`; }
function auditMarkup(value) { return collectionMarkup(value.items, (record) => `<article class="record card"><div><h3>${escape(record.action ?? 'Audit event')}</h3><p class="muted">${escape(record.targetUserId ?? '')} · ${formatDate(record.occurredAt)}</p></div><span class="badge">${escape(record.outcome ?? 'recorded')}</span><details><summary>Details</summary><pre>${escape(JSON.stringify(record.details ?? record.reason ?? '', null, 2))}</pre></details></article>`, value.nextCursor, 'audit'); }
function collectionMarkup(items = [], renderItem, nextCursor, kind) { if (!items.length && !nextCursor) return '<p class="muted">No records returned.</p>'; return `<div class="records">${items.map(renderItem).join('')}</div>${nextCursor ? `<button data-next-page="${kind}" data-cursor="${escape(nextCursor)}" ${state.value.busy ? 'disabled' : ''}>Load more</button>` : ''}`; }

function bindPage(value) {
  root.querySelector('#user-search')?.addEventListener('submit', searchUsers); root.querySelector('#report-search')?.addEventListener('submit', searchReports); root.querySelector('#job-search')?.addEventListener('submit', searchJobs); root.querySelector('#audit-search')?.addEventListener('submit', searchAudit); root.querySelector('#campaign-form')?.addEventListener('submit', previewCampaign); root.querySelector('#test-message-form')?.addEventListener('submit', sendTestMessage); root.querySelector('#report-update')?.addEventListener('submit', updateReport); root.querySelector('#note-form')?.addEventListener('submit', addReportNote); root.querySelector('[data-action="create-job"]')?.addEventListener('click', createJob); root.querySelector('[data-action="retry-job"]')?.addEventListener('click', retryJob); root.querySelector('[data-action="cancel-job"]')?.addEventListener('click', cancelJob); root.querySelector('[data-action="back"]')?.addEventListener('click', () => state.update({ detail: null, notes: null, recipients: null }));
  root.querySelectorAll('[data-user-id]').forEach((button) => button.addEventListener('click', () => loadUser(button.dataset.userId))); root.querySelectorAll('[data-report-id]').forEach((button) => button.addEventListener('click', () => loadReport(button.dataset.reportId))); root.querySelectorAll('[data-job-id]').forEach((button) => button.addEventListener('click', () => loadJob(button.dataset.jobId))); root.querySelector('[data-next-page]')?.addEventListener('click', (event) => loadNext(event.currentTarget.dataset.nextPage, event.currentTarget.dataset.cursor));
}

async function selectPage(page) { state.update({ page, loaded: page === 'overview', detail: null, notes: null, recipients: null, preview: null, items: [], nextCursor: null, error: null, filters: {} }); if (page !== 'overview') await loadPage(page); }
async function loadPage(page, options = {}) { state.update({ page, busy: true, error: null }); try { const result = page === 'users' ? await api.listUsers(options) : page === 'reports' ? await api.listReports(options) : page === 'jobs' ? await api.listJobs(options) : page === 'audit' ? await api.listAudit(options) : { items: [] }; state.update({ busy: false, loaded: true, items: result?.items ?? result?.records ?? [], nextCursor: result?.nextCursor ?? result?.cursor ?? null }); } catch (error) { handle(error); } }
async function loadNext(page, cursor) { await loadPage(page, { ...(state.value.filters ?? {}), cursor }); }
async function searchUsers(event) { event.preventDefault(); const search = new FormData(event.currentTarget).get('search'); state.update({ filters: { search } }); await loadPage('users', { search }); }
async function searchReports(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const filters = { search: form.get('search'), status: form.get('status') }; state.update({ filters }); await loadPage('reports', filters); }
async function searchJobs(event) { event.preventDefault(); const status = new FormData(event.currentTarget).get('status'); state.update({ filters: { status } }); await loadPage('jobs', { status }); }
async function searchAudit(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const filters = { targetUserId: form.get('targetUserId'), action: form.get('action') }; state.update({ filters }); await loadPage('audit', filters); }
async function loadUser(userId) { state.update({ busy: true, error: null }); try { state.update({ detail: await api.getUser(userId), busy: false }); } catch (error) { handle(error); } }
async function loadReport(reportId) { state.update({ busy: true, error: null, notes: null }); try { const [detail, notes] = await Promise.all([api.getReport(reportId), api.listReportNotes(reportId)]); state.update({ detail, notes: notes?.items ?? notes?.records ?? [], busy: false }); } catch (error) { handle(error); } }
async function loadJob(jobId) { state.update({ busy: true, error: null }); try { const [detail, recipients] = await Promise.all([api.getJob(jobId), api.listRecipients(jobId)]); state.update({ detail, recipients: recipients?.items ?? recipients?.records ?? [], busy: false, loaded: true }); } catch (error) { handle(error); } }
async function updateReport(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const reportId = state.value.detail.reportId ?? state.value.detail.id; const assignee = form.get('clearAssignee') ? 'clear' : form.get('assignee'); await mutate(() => api.updateReport(reportId, { expectedRevision: Number(form.get('expectedRevision')), status: form.get('status'), assignee, note: form.get('note') }, operationKey('report', reportId)), 'Report update accepted.'); if (!state.value.error) await loadReport(reportId); }
async function addReportNote(event) { event.preventDefault(); const reportId = state.value.detail.reportId ?? state.value.detail.id; const text = new FormData(event.currentTarget).get('text'); await mutate(() => api.addReportNote(reportId, text), 'Note added.'); if (!state.value.error) await loadReport(reportId); }
async function previewCampaign(event) { event.preventDefault(); const form = new FormData(event.currentTarget); try { const audience = audienceFromForm(form); const action = actionFromForm(form); state.update({ busy: true, error: null, preview: null, campaignAction: action }); state.update({ preview: await api.previewAudience(audience, action), busy: false }); } catch (error) { handle(error); } }
async function createJob() { const preview = state.value.preview; if (!preview?.snapshotId || preview.status !== 'ready') return; await mutate(() => api.createJob({ action: preview.action ?? state.value.campaignAction, payloadHash: preview.payloadHash, snapshotId: preview.snapshotId }, operationKey('job', preview.snapshotId)), 'Job accepted and queued.'); }
async function sendTestMessage(event) { event.preventDefault(); const form = new FormData(event.currentTarget); await mutate(() => api.sendTestMessage({ action: { action: form.get('action') }, recipientUserId: form.get('recipientUserId') }), 'Test message accepted.'); }
async function retryJob() { const id = state.value.detail.jobId; if (globalThis.confirm?.('Retry failed recipients using the same server snapshot?')) await mutate(() => api.retryJob(id, { reason: 'Administrator requested retry' }, operationKey('retry', id)), 'Retry accepted.'); }
async function cancelJob() { const id = state.value.detail.jobId; if (globalThis.confirm?.('Request cancellation for this job? In-flight provider work may still complete.')) await mutate(() => api.cancelJob(id, { reason: 'Administrator requested cancellation' }, operationKey('cancel', id)), 'Cancellation requested.'); }
async function submitReauthentication(event) { event.preventDefault(); const code = new FormData(event.currentTarget).get('code'); try { await api.reauthenticate(state.value.reauth.action, code); const pending = state.value.reauth.pending; state.update({ reauth: null }); if (pending) await pending(); } catch (error) { state.update({ busy: false, error: message(error) }); } }
async function mutate(operation, acceptedMessage) { state.update({ busy: true, error: null }); try { await operation(); state.update({ busy: false, notice: acceptedMessage }); } catch (error) { if (error instanceof AdminHttpError && error.status === 403 && error.message.toLowerCase().includes('mfa')) state.update({ busy: false, reauth: { action: 'admin_mutation', message: error.message, pending: operation } }); else handle(error); } }
function audienceFromForm(form) { const kind = form.get('audienceKind'); const resource = form.get('resource'); const raw = String(form.get('audienceValue') ?? '').trim(); if (kind === 'all') return { kind, resource }; if (kind === 'selected') return { kind, resource, ids: raw.split(/\s+/).filter(Boolean) }; let filter = {}; try { filter = raw ? JSON.parse(raw) : {}; } catch { throw new Error('Filter JSON is invalid.'); } return { kind, resource, filter }; }
function actionFromForm(form) { const action = form.get('action'); let payload = {}; const raw = String(form.get('payload') ?? '').trim(); try { payload = raw ? JSON.parse(raw) : {}; } catch { throw new Error('Action payload JSON is invalid.'); } return { action, ...payload }; }
function operationKey(kind, id) { return `${kind}:${id}:${globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random()}`}`; }
async function logout() { try { await api.logout(); } finally { state.update({ session: 'login', sessionData: null, loaded: false, error: null }); } }
function handle(error) { if (error instanceof AdminHttpError && error.unauthorized) state.update({ session: 'login', busy: false, error: 'Your admin session has expired.' }); else if (error instanceof AdminHttpError && error.forbidden) state.update({ busy: false, error: 'You do not have the capability required for this action.' }); else if (error instanceof AdminHttpError && error.status === 409) state.update({ busy: false, error: 'This record changed on the server. Reload it and try again.' }); else state.update({ busy: false, error: message(error) }); }
function title(value) { return value[0].toUpperCase() + value.slice(1); }
function heading(value) { return value === 'overview' ? 'Operate with server-bound controls' : `Review ${value} from the API`; }
function message(error) { return error instanceof Error ? error.message : 'The admin request could not be completed.'; }
function field(label, value) { return value === undefined || value === null || value === '' ? '' : `<div><dt>${escape(label)}</dt><dd>${escape(value)}</dd></div>`; }
function formatDate(value) { if (!value) return '—'; const date = new Date(value); return Number.isNaN(date.valueOf()) ? String(value) : date.toLocaleString(); }
function escape(value) { return String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char])); }
