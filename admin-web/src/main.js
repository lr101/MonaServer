import { AdminApi, AdminHttpError } from './api.js';
import { AdminState } from './state.js';
import { reauthenticationActionFor } from './permissions.js';

const root = document.querySelector('#app');
const api = new AdminApi();
const state = new AdminState({ page: 'overview', items: [], filters: {} });
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
  if (value.session === 'error') { root.innerHTML = `<section class="card narrow"><p class="eyebrow">MonaServer</p><h1>Admin unavailable</h1><p>${escape(value.error)}</p><button data-action="retry">Retry</button></section>`; root.querySelector('[data-action="retry"]').addEventListener('click', start); return; }
  if (value.session === 'login' || value.session === 'mfa' || value.session === 'setup' || value.session === 'setup-complete') { renderLogin(value); return; }
  renderShell(value);
}

function renderLogin(value) {
  const mfa = value.session === 'mfa';
  if (value.session === 'setup-complete') {
    root.innerHTML = `<section class="card narrow"><p class="eyebrow">MonaServer</p><h1>Save your authenticator key</h1><p>Add this key to your authenticator app now. It is shown only once. You will need a code from that app to sign in.</p><p class="setup-secret"><code>${escape(value.totpSecret)}</code></p><button data-action="setup-done">I saved the key — sign in</button></section>`;
    root.querySelector('[data-action="setup-done"]').addEventListener('click', () => state.update({ session: 'login', totpSecret: null, error: null }));
    return;
  }
  if (value.session === 'setup') {
    root.innerHTML = `<section class="card narrow"><p class="eyebrow">MonaServer</p><h1>Set up first administrator</h1><p>Use an existing password-enabled account and the one-time setup secret configured on the Go server.</p><form id="setup-form"><label>Username<input name="username" autocomplete="username" required></label><label>Password<input name="password" type="password" autocomplete="current-password" required></label><label>Deployment setup secret<input name="setupToken" type="password" autocomplete="off" minlength="32" required></label><button type="submit" ${value.busy ? 'disabled' : ''}>${value.busy ? 'Working…' : 'Create administrator'}</button></form><button class="secondary" data-action="back-to-login">Back to sign in</button>${value.error ? `<p class="error" role="alert">${escape(value.error)}</p>` : ''}</section>`;
    root.querySelector('#setup-form').addEventListener('submit', submitSetup);
    root.querySelector('[data-action="back-to-login"]').addEventListener('click', () => state.update({ session: 'login', error: null }));
    return;
  }
  root.innerHTML = `<section class="card narrow"><p class="eyebrow">MonaServer</p><h1>Admin workspace</h1><p>${mfa ? 'Enter the authenticator code to continue.' : 'Sign in with your administrator account.'}</p><form id="login-form">${mfa ? '<label>Authenticator code<input name="code" inputmode="numeric" autocomplete="one-time-code" required></label>' : '<label>Username<input name="username" autocomplete="username" required></label><label>Password<input name="password" type="password" autocomplete="current-password" required></label>'}<button type="submit" ${value.busy ? 'disabled' : ''}>${value.busy ? 'Working…' : (mfa ? 'Verify MFA' : 'Continue')}</button></form>${!mfa ? '<button class="secondary" data-action="show-setup">Set up first administrator</button>' : ''}${value.error ? `<p class="error" role="alert">${escape(value.error)}</p>` : ''}</section>`;
  root.querySelector('#login-form').addEventListener('submit', mfa ? submitMfa : submitLogin);
  root.querySelector('[data-action="show-setup"]')?.addEventListener('click', () => state.update({ session: 'setup', error: null }));
}

async function submitSetup(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  state.update({ busy: true, error: null });
  try {
    const result = await api.setupInitialAdmin(form.get('username'), form.get('password'), form.get('setupToken'));
    state.update({ session: 'setup-complete', totpSecret: result.totpSecret, busy: false });
  } catch (error) {
    state.update({ busy: false, error: message(error) });
  }
}

async function submitLogin(event) { event.preventDefault(); const form = new FormData(event.currentTarget); state.update({ busy: true, error: null }); try { const result = await api.login(form.get('username'), form.get('password')); challengeId = result.challengeId; state.update({ session: 'mfa', busy: false }); } catch (error) { handle(error); } }
async function submitMfa(event) { event.preventDefault(); const form = new FormData(event.currentTarget); state.update({ busy: true, error: null }); try { const session = await api.completeMfa(challengeId, form.get('code')); state.update({ session: 'authenticated', sessionData: session, busy: false, loaded: false }); } catch (error) { handle(error); } }

function renderShell(value) {
  const pages = ['overview', 'users', 'reports', 'campaigns', 'audit'];
  root.innerHTML = `<div class="shell"><header><div><p class="eyebrow">MonaServer</p><h1>Admin workspace</h1></div><div class="header-actions"><span class="muted">${escape(value.sessionData?.username ?? value.sessionData?.adminUsername ?? '')}</span><button data-action="logout">Sign out</button></div></header><nav aria-label="Admin sections">${pages.map((page) => `<button class="nav-button ${value.page === page ? 'selected' : ''}" data-page="${page}">${title(page)}</button>`).join('')}</nav><section class="content"><div class="toolbar"><div><p class="eyebrow">${title(value.page)}</p><h2>${value.page === 'overview' ? 'Simple server-backed administration' : title(value.page)}</h2></div></div>${value.error ? `<p class="error" role="alert">${escape(value.error)}</p>` : ''}${value.notice ? `<p class="notice" role="status">${escape(value.notice)}</p>` : ''}${value.reauth ? reauthMarkup(value) : ''}${tools(value)}<div id="page-content">${pageMarkup(value)}</div></section></div>`;
  root.querySelectorAll('[data-page]').forEach((button) => button.addEventListener('click', () => selectPage(button.dataset.page)));
  root.querySelector('[data-action="logout"]').addEventListener('click', logout);
  root.querySelector('#reauth-form')?.addEventListener('submit', submitReauthentication);
  bindPage();
}

function reauthMarkup(value) { return `<section class="notice"><strong>Recent MFA required</strong><p>${escape(value.reauth.message ?? 'Confirm this sensitive action.')}</p><form id="reauth-form" class="inline-form"><input name="code" inputmode="numeric" autocomplete="one-time-code" placeholder="MFA code" required><button ${value.busy ? 'disabled' : ''}>Confirm</button></form></section>`; }
function tools(value) { if (value.page === 'users') return `<form id="user-search" class="inline-form"><input name="search" value="${escape(value.filters.search ?? '')}" placeholder="Search username or email"><button>Search</button></form>`; if (value.page === 'reports') return `<form id="report-search" class="inline-form"><input name="search" value="${escape(value.filters.search ?? '')}" placeholder="Search reports"><select name="status"><option value="">All statuses</option>${['open', 'resolved', 'dismissed'].map((status) => `<option value="${status}" ${value.filters.status === status ? 'selected' : ''}>${title(status)}</option>`).join('')}</select><button>Search</button></form>`; if (value.page === 'campaigns' && !value.detail && value.editor !== 'create') return '<button data-action="new-campaign">New campaign</button>'; if (value.page === 'audit') return `<form id="audit-search" class="inline-form"><input name="targetUserId" value="${escape(value.filters.targetUserId ?? '')}" placeholder="Target user ID"><input name="action" value="${escape(value.filters.action ?? '')}" placeholder="Action"><button>Search</button></form>`; return ''; }

function pageMarkup(value) {
  if (value.busy && !value.detail) return '<div class="loading">Loading…</div>';
  if (value.page === 'overview') return '<div class="grid"><article class="card"><h3>Users</h3><p>Search bounded account records and inspect security state without credential material.</p></article><article class="card"><h3>Reports</h3><p>Review, assign, resolve, dismiss, and annotate reports with revision checks.</p></article><article class="card"><h3>Campaigns</h3><p>Create and manage content records without scheduling or delivery.</p></article><article class="card"><h3>Audit</h3><p>Inspect permission-filtered administrative history with bounded details.</p></article></div>';
  if (value.page === 'users') return value.detail ? userDetail(value) : collection(value.items, userRow, value.nextCursor, 'users');
  if (value.page === 'reports') return value.detail ? reportDetail(value) : collection(value.items, reportRow, value.nextCursor, 'reports');
  if (value.page === 'campaigns') return value.editor === 'create' ? campaignEditor(value, emptyCampaign()) : value.detail ? campaignEditor(value, value.detail) : collection(value.items, campaignRow, value.nextCursor, 'campaigns');
  return collection(value.items, auditRow, value.nextCursor, 'audit');
}

function userRow(user) { const id = user.id ?? ''; return `<button class="record card" data-user-id="${escape(id)}"><div><h3>${escape(user.username ?? user.email ?? 'Account')}</h3><p class="muted">${escape(id)}</p></div><span class="badge">${escape(user.securityState ?? 'unknown')}</span></button>`; }
function userDetail(value) { const user = value.detail; return `<div class="detail-actions"><button data-action="back">Back to users</button></div><article class="card"><h3>${escape(user.username ?? user.email ?? 'Account')}</h3><dl>${field('User ID', user.id)}${field('Email', user.email)}${field('Security state', user.securityState)}${field('Email verified', user.emailVerified)}${field('Created', formatDate(user.createdAt))}${field('Admin account', user.isAdmin)}${field('Eligibility', (user.eligibilityReasons ?? []).join(', ') || 'eligible')}</dl></article>`; }
function reportRow(report) { return `<button class="record card" data-report-id="${escape(report.id ?? '')}"><div><h3>Report ${escape(report.id ?? '')}</h3><p class="muted">${escape(report.text ?? report.legacyMessage ?? '')}</p></div><span class="badge">${escape(report.status ?? 'open')}</span></button>`; }
function reportDetail(value) { const report = value.detail; const target = report.target ?? {}; const notes = value.notes ?? report.notes ?? []; return `<div class="detail-actions"><button data-action="back">Back to reports</button></div><article class="card"><h3>Report ${escape(report.id ?? '')}</h3><dl>${field('Status', report.status)}${field('Revision', report.revision)}${field('Reporter', report.reporterUserId)}${field('Target', target.userId ?? (target.deleted ? 'deleted account' : null))}${field('Created', formatDate(report.createdAt))}</dl><p>${escape(report.text ?? report.legacyMessage ?? '')}</p><form id="report-update" class="stack-form"><input type="hidden" name="expectedRevision" value="${escape(report.revision ?? '')}"><label>Status<select name="status"><option value="open" ${report.status === 'open' ? 'selected' : ''}>Open</option><option value="resolved" ${report.status === 'resolved' ? 'selected' : ''}>Resolved</option><option value="dismissed" ${report.status === 'dismissed' ? 'selected' : ''}>Dismissed</option></select></label><label>Assignee<input name="assignee" value="${escape(report.assigneeUserId ?? '')}" placeholder="Admin user ID"></label><label><input type="checkbox" name="clearAssignee"> Clear assignment</label><label>Note<textarea name="note" rows="3"></textarea></label><button ${value.busy ? 'disabled' : ''}>Save report</button></form></article><section class="card"><h3>Notes</h3>${notes.length ? `<div class="records">${notes.map((note) => `<article class="note"><p>${escape(note.text ?? '')}</p><small>${escape(note.actorUserId ?? '')} · ${formatDate(note.createdAt)}</small></article>`).join('')}</div>` : '<p class="muted">No notes.</p>'}<form id="note-form" class="stack-form"><label>Add note<textarea name="text" rows="2" required></textarea></label><button>Add note</button></form></section>`; }
function campaignRow(campaign) { return `<button class="record card" data-campaign-id="${escape(campaign.id ?? '')}"><div><h3>${escape(campaign.name ?? 'Campaign')}</h3><p class="muted">${escape(campaign.channel ?? '')} · ${escape(campaign.id ?? '')}</p></div><span class="badge">${escape(campaign.status ?? 'draft')}</span></button>`; }
function campaignEditor(value, campaign) { const creating = value.editor === 'create'; const archived = !creating && campaign.status === 'archived'; return `<div class="detail-actions"><button data-action="back">Back to campaigns</button>${!creating && !archived ? '<button data-action="archive-campaign">Archive campaign</button>' : ''}${!creating && campaign.status === 'draft' ? '<button data-action="delete-campaign">Delete draft</button>' : ''}</div><article class="card"><h3>${creating ? 'New campaign' : escape(campaign.name ?? 'Campaign')}</h3>${creating ? '' : `<dl>${field('Campaign ID', campaign.id)}${field('Revision', campaign.revision)}${field('Created', formatDate(campaign.createdAt))}${field('Updated', formatDate(campaign.updatedAt))}${field('Created by', campaign.createdByUserId)}</dl>`}<p class="muted">Campaign content records do not schedule or deliver messages.</p>${archived ? '<p class="notice">This campaign is archived and cannot be changed.</p>' : ''}<form id="campaign-editor" class="stack-form">${creating ? '' : `<input type="hidden" name="expectedRevision" value="${escape(campaign.revision ?? '')}">`}<label>Name<input name="name" value="${escape(campaign.name ?? '')}" maxlength="200" required ${archived ? 'disabled' : ''}></label><label>Channel<select name="channel" ${archived ? 'disabled' : ''}><option value="email" ${campaign.channel === 'email' ? 'selected' : ''}>Email</option><option value="push" ${campaign.channel === 'push' ? 'selected' : ''}>Push</option></select></label><label>Email subject<input name="subject" value="${escape(campaign.subject ?? '')}" maxlength="200" ${archived ? 'disabled' : ''}></label><label>Push title<input name="title" value="${escape(campaign.title ?? '')}" maxlength="200" ${archived ? 'disabled' : ''}></label><label>Body<textarea name="body" rows="8" maxlength="10000" required ${archived ? 'disabled' : ''}>${escape(campaign.body ?? '')}</textarea></label><label>Status<select name="status" ${archived ? 'disabled' : ''}><option value="draft" ${campaign.status === 'draft' ? 'selected' : ''}>Draft</option><option value="active" ${campaign.status === 'active' ? 'selected' : ''}>Active</option></select></label>${archived ? '' : `<button ${value.busy ? 'disabled' : ''}>Save campaign content</button>`}</form></article>`; }
function emptyCampaign() { return { channel: 'email', status: 'draft' }; }
function auditRow(event) { return `<article class="record card"><div><h3>${escape(event.action ?? 'Audit event')}</h3><p class="muted">${escape(event.targetUserId ?? '')} · ${formatDate(event.occurredAt)}</p></div><span class="badge">${escape(event.outcome ?? 'recorded')}</span><details><summary>Details</summary><pre>${escape(JSON.stringify(event.details ?? event.reason ?? '', null, 2))}</pre></details></article>`; }
function collection(items = [], renderRow, nextCursor, kind) { if (!items.length && !nextCursor) return '<p class="muted">No records returned.</p>'; return `<div class="records">${items.map(renderRow).join('')}</div>${nextCursor ? `<button data-next-page="${kind}" data-cursor="${escape(nextCursor)}">Load more</button>` : ''}`; }
function field(label, value) { return value === undefined || value === null || value === '' ? '' : `<div><dt>${escape(label)}</dt><dd>${escape(value)}</dd></div>`; }

function bindPage() { root.querySelector('#user-search')?.addEventListener('submit', searchUsers); root.querySelector('#report-search')?.addEventListener('submit', searchReports); root.querySelector('#audit-search')?.addEventListener('submit', searchAudit); root.querySelector('#report-update')?.addEventListener('submit', updateReport); root.querySelector('#note-form')?.addEventListener('submit', addNote); root.querySelector('#campaign-editor')?.addEventListener('submit', saveCampaign); root.querySelector('[data-action="new-campaign"]')?.addEventListener('click', () => state.update({ editor: 'create', error: null, notice: null })); root.querySelector('[data-action="archive-campaign"]')?.addEventListener('click', archiveCampaign); root.querySelector('[data-action="delete-campaign"]')?.addEventListener('click', deleteCampaign); root.querySelector('[data-action="back"]')?.addEventListener('click', () => state.update({ detail: null, notes: null, editor: null })); root.querySelectorAll('[data-user-id]').forEach((button) => button.addEventListener('click', () => loadUser(button.dataset.userId))); root.querySelectorAll('[data-report-id]').forEach((button) => button.addEventListener('click', () => loadReport(button.dataset.reportId))); root.querySelectorAll('[data-campaign-id]').forEach((button) => button.addEventListener('click', () => loadCampaign(button.dataset.campaignId))); root.querySelector('[data-next-page]')?.addEventListener('click', (event) => loadPage(event.currentTarget.dataset.nextPage, { ...state.value.filters, cursor: event.currentTarget.dataset.cursor })); }
async function selectPage(page) { state.update({ page, detail: null, notes: null, editor: null, items: [], nextCursor: null, error: null, filters: {} }); if (page !== 'overview') await loadPage(page); }
async function loadPage(page, options = {}) { state.update({ page, busy: true, error: null }); try { const result = page === 'users' ? await api.listUsers(options) : page === 'reports' ? await api.listReports(options) : page === 'campaigns' ? await api.listCampaigns(options) : await api.listAudit(options); state.update({ busy: false, loaded: true, items: result?.items ?? [], nextCursor: result?.nextCursor ?? null }); } catch (error) { handle(error); } }
async function searchUsers(event) { event.preventDefault(); const search = new FormData(event.currentTarget).get('search'); state.update({ filters: { search } }); await loadPage('users', { search }); }
async function searchReports(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const filters = { search: form.get('search'), status: form.get('status') }; state.update({ filters }); await loadPage('reports', filters); }
async function searchAudit(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const filters = { targetUserId: form.get('targetUserId'), action: form.get('action') }; state.update({ filters }); await loadPage('audit', filters); }
async function loadUser(id) { state.update({ busy: true, error: null }); try { state.update({ detail: await api.getUser(id), busy: false }); } catch (error) { handle(error); } }
async function loadReport(id) { state.update({ busy: true, error: null, notes: null }); try { const report = await api.getReport(id); const notes = await api.listReportNotes(id); state.update({ detail: report, notes: notes?.items ?? [], busy: false }); } catch (error) { handle(error); } }
async function loadCampaign(id) { state.update({ busy: true, error: null, editor: null }); try { state.update({ detail: await api.getCampaign(id), busy: false }); } catch (error) { handle(error); } }
async function updateReport(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const id = state.value.detail.id; const assignee = form.get('clearAssignee') ? 'clear' : form.get('assignee'); await mutate(() => api.updateReport(id, { expectedRevision: Number(form.get('expectedRevision')), status: form.get('status'), assignee, note: form.get('note') }), 'Report saved.'); if (!state.value.error) await loadReport(id); }
async function addNote(event) { event.preventDefault(); const id = state.value.detail.id; const text = new FormData(event.currentTarget).get('text'); await mutate(() => api.addReportNote(id, text), 'Note added.'); if (!state.value.error) await loadReport(id); }
async function saveCampaign(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const payload = campaignPayload(form); if (state.value.editor === 'create') { await mutate(async () => { state.update({ detail: await api.createCampaign(payload), editor: null }); }, 'Campaign content record saved.'); return; } const id = state.value.detail.id; await mutate(async () => { state.update({ detail: await api.updateCampaign(id, { ...payload, expectedRevision: Number(form.get('expectedRevision')) }) }); }, 'Campaign content record saved.'); }
async function archiveCampaign() { const campaign = state.value.detail; await mutate(async () => { state.update({ detail: await api.archiveCampaign(campaign.id, campaign.revision) }); }, 'Campaign archived.'); }
async function deleteCampaign() { const campaign = state.value.detail; if (!window.confirm(`Delete draft campaign “${campaign.name}”?`)) return; await mutate(async () => { await api.deleteCampaign(campaign.id, campaign.revision); state.update({ detail: null }); await loadPage('campaigns'); }, 'Draft campaign deleted.'); }
function campaignPayload(form) {
  const channel = form.get('channel');
  return {
    name: form.get('name'),
    channel,
    subject: channel === 'email' ? optionalField(form.get('subject')) : null,
    title: channel === 'push' ? optionalField(form.get('title')) : null,
    body: form.get('body'),
    status: form.get('status'),
  };
}
function optionalField(value) { return value === '' ? null : value; }
async function submitReauthentication(event) { event.preventDefault(); const code = new FormData(event.currentTarget).get('code'); try { await api.reauthenticate(state.value.reauth.action, code); const pending = state.value.reauth.pending; state.update({ reauth: null }); if (pending) await pending(); } catch (error) { state.update({ busy: false, error: message(error) }); } }
async function mutate(operation, notice) { state.update({ busy: true, error: null }); try { await operation(); state.update({ busy: false, notice }); } catch (error) { if (error instanceof AdminHttpError && error.status === 403 && error.message.toLowerCase().includes('mfa')) state.update({ busy: false, reauth: { action: reauthenticationActionFor(state.value.page), message: error.message, pending: operation } }); else handle(error); } }
function handle(error) { if (error instanceof AdminHttpError && error.unauthorized) { state.update({ session: 'login', busy: true, error: 'Session expired. Preparing sign-in…' }); api.bootstrap().then(() => state.update({ busy: false, error: null })).catch((bootstrapError) => state.update({ session: 'error', busy: false, error: message(bootstrapError) })); } else if (error instanceof AdminHttpError && error.forbidden) state.update({ busy: false, error: 'You do not have permission for this operation.' }); else if (error instanceof AdminHttpError && error.status === 409) state.update({ busy: false, error: 'This record changed. Reload it and reapply your change.' }); else state.update({ busy: false, error: message(error) }); }
async function logout() { try { await api.logout(); } finally { state.update({ session: 'login', sessionData: null, loaded: false, busy: true, error: null }); try { await api.bootstrap(); state.update({ busy: false }); } catch (error) { state.update({ session: 'error', busy: false, error: message(error) }); } } }
function title(value) { return value[0].toUpperCase() + value.slice(1); }
function message(error) { return error instanceof Error ? error.message : 'The admin request could not be completed.'; }
function formatDate(value) { if (!value) return '—'; const date = new Date(value); return Number.isNaN(date.valueOf()) ? String(value) : date.toLocaleString(); }
function escape(value) { return String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char])); }
