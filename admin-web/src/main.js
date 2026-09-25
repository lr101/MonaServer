import { AdminApi, AdminHttpError } from './api.js';
import { AdminState } from './state.js';
import { countLabel, reportUpdatePayload, userDisplayName } from './view-model.js';

const root = document.querySelector('#app');
const api = new AdminApi();
const state = new AdminState({ page: 'overview', items: [], filters: {} });
let challengeId = null;
let loginCampaignRunning = false;
let startupInProgress = false;

state.subscribe(render);
render(state.value);
start();

async function start() {
  if (startupInProgress) return;
  startupInProgress = true;
  state.update({ busy: true });
  try {
    await api.bootstrap();
    const session = await api.restore();
    state.update({ session: session?.sessionState === 'authenticated' ? 'authenticated' : 'login', sessionData: session, busy: false });
    if (session?.sessionState === 'authenticated') await loadOverview();
  } catch (error) {
    state.update({ session: error instanceof AdminHttpError && error.status === 401 ? 'login' : 'error', sessionData: null, busy: false, error: message(error) });
  } finally {
    startupInProgress = false;
  }
}

function render(value) {
  if (value.session === 'unknown') { root.innerHTML = '<div class="loading">Loading admin session…</div>'; return; }
  if (value.session === 'error') { root.innerHTML = `<section class="card narrow"><p class="eyebrow">MonaServer</p><h1>Admin unavailable</h1><p>${escape(value.error)}</p><button data-action="retry" ${value.busy ? 'disabled' : ''}>${value.busy ? 'Retrying…' : 'Retry'}</button></section>`; root.querySelector('[data-action="retry"]').addEventListener('click', start); return; }
  if (value.session === 'login' || value.session === 'mfa') { renderLogin(value); return; }
  renderShell(value);
}

function renderLogin(value) {
  const mfa = value.session === 'mfa';
  root.innerHTML = `<section class="card narrow"><p class="eyebrow">MonaServer</p><h1>Admin workspace</h1><p>${mfa ? 'Enter the authenticator code to continue.' : 'Sign in with your administrator account.'}</p><form id="login-form">${mfa ? '<label>Authenticator code<input name="code" inputmode="numeric" autocomplete="one-time-code" required></label>' : '<label>Username<input name="username" autocomplete="username" required></label><label>Password<input name="password" type="password" autocomplete="current-password" required></label>'}<button type="submit" ${value.busy ? 'disabled' : ''}>${value.busy ? 'Working…' : (mfa ? 'Verify MFA' : 'Continue')}</button></form>${value.error ? `<p class="error" role="alert">${escape(value.error)}</p>` : ''}</section>`;
  root.querySelector('#login-form').addEventListener('submit', mfa ? submitMfa : submitLogin);
}

async function submitLogin(event) { event.preventDefault(); const form = new FormData(event.currentTarget); state.update({ busy: true, error: null }); try { const result = await api.login(form.get('username'), form.get('password')); challengeId = result.challengeId; state.update({ session: 'mfa', busy: false }); } catch (error) { handle(error); } }
async function submitMfa(event) { event.preventDefault(); const form = new FormData(event.currentTarget); state.update({ busy: true, error: null }); try { const session = await api.completeMfa(challengeId, form.get('code')); state.update({ session: 'authenticated', sessionData: session, busy: false, loaded: false }); await loadOverview(); } catch (error) { handle(error); } }

function renderShell(value) {
  const pages = ['overview', 'users', 'reports', 'campaigns', 'audit'];
  const lockNavigation = value.page === 'campaigns' && value.editor === 'login-links' && value.busy;
  root.innerHTML = `<div class="shell"><header><div><p class="eyebrow">MonaServer</p><h1>Admin workspace</h1></div><div class="header-actions"><span class="muted">${escape(value.sessionData?.username ?? value.sessionData?.adminUsername ?? '')}</span><button data-action="logout" ${lockNavigation ? 'disabled' : ''}>Sign out</button></div></header><nav aria-label="Admin sections">${pages.map((page) => `<button class="nav-button ${value.page === page ? 'selected' : ''}" data-page="${page}" ${lockNavigation ? 'disabled' : ''}>${title(page)}</button>`).join('')}</nav><section class="content"><div class="toolbar"><div><p class="eyebrow">${title(value.page)}</p><h2>${value.page === 'overview' ? 'At a glance' : title(value.page)}</h2></div></div>${value.error ? `<p class="error" role="alert">${escape(value.error)}</p>` : ''}${value.notice ? `<p class="notice" role="status">${escape(value.notice)}</p>` : ''}${tools(value)}<div id="page-content">${pageMarkup(value)}</div></section></div>`;
  root.querySelectorAll('nav [data-page]').forEach((button) => button.addEventListener('click', () => selectPage(button.dataset.page)));
  root.querySelector('[data-action="logout"]').addEventListener('click', logout);
  bindPage();
}

function tools(value) { if (value.page === 'users') return `<form id="user-search" class="inline-form"><input name="search" value="${escape(value.filters.search ?? '')}" placeholder="Username, email, or user ID" aria-label="Search users"><select name="securityStatus" aria-label="Security state"><option value="">Any security state</option>${['normal', 'password_disabled', 'compromised', 'secured_manual_recovery_required', 'deleted'].map((status) => `<option value="${status}" ${value.filters.securityStatus === status ? 'selected' : ''}>${status.replaceAll('_', ' ')}</option>`).join('')}</select><select name="verifiedEmail" aria-label="Email verification"><option value="">Any email status</option><option value="true" ${value.filters.verifiedEmail === 'true' ? 'selected' : ''}>Verified email</option><option value="false" ${value.filters.verifiedEmail === 'false' ? 'selected' : ''}>Unverified email</option></select><button>Search</button></form>`; if (value.page === 'reports') return `<form id="report-search" class="inline-form"><input name="search" value="${escape(value.filters.search ?? '')}" placeholder="Search reports"><select name="status"><option value="">All statuses</option>${['open', 'resolved', 'dismissed'].map((status) => `<option value="${status}" ${value.filters.status === status ? 'selected' : ''}>${title(status)}</option>`).join('')}</select><button>Search</button></form>`; if (value.page === 'campaigns' && !value.detail && !value.editor) return `<div class="detail-actions"><button data-action="new-campaign">New campaign</button>${canSendLoginCampaign(value) ? '<button data-action="new-login-campaign" class="outline">Login links to everyone</button>' : ''}</div>`; if (value.page === 'audit') return `<form id="audit-search" class="inline-form"><input name="targetUserId" value="${escape(value.filters.targetUserId ?? '')}" placeholder="Target user ID"><input name="action" value="${escape(value.filters.action ?? '')}" placeholder="Action"><button>Search</button></form>`; return ''; }

function pageMarkup(value) {
  if (value.busy && !value.detail && value.editor !== 'login-links') return '<div class="loading">Loading…</div>';
  if (value.page === 'overview') return overviewMarkup(value);
  if (value.page === 'users') return value.detail ? userDetail(value) : collection(value.items, userRow, value.nextCursor, 'users');
  if (value.page === 'reports') return value.detail ? reportDetail(value) : collection(value.items, reportRow, value.nextCursor, 'reports');
  if (value.page === 'campaigns') return value.editor === 'login-links' ? loginLinkCampaign(value) : value.editor === 'create' ? campaignEditor(value, emptyCampaign()) : value.detail ? campaignEditor(value, value.detail) : collection(value.items, campaignRow, value.nextCursor, 'campaigns');
  return collection(value.items, auditRow, value.nextCursor, 'audit');
}

function overviewMarkup(value) { const stats = value.overview; return `<div class="grid stats">${[['Accounts', stats?.users], ['Open reports', stats?.reports], ['Campaigns', stats?.campaigns]].map(([label, page]) => `<article class="card stat"><p class="muted">${label}</p><strong>${page ? countLabel(page) : '—'}</strong><small>${!page ? 'Unavailable or no access' : page.nextCursor ? 'At least this many records' : 'Records found'}</small></article>`).join('')}</div><p class="muted">Counts show up to the first 100 records in each section.</p><div class="grid"><article class="card"><h3>Review reports</h3><p>${stats?.reports?.items?.length ? 'Open reports need a decision.' : 'Review the open reports queue.'}</p><button data-page="reports">Open reports</button></article><article class="card"><h3>Find an account</h3><p>Search by username, email, or user ID.</p><button data-page="users">Browse users</button></article><article class="card"><h3>Campaign content</h3><p>Draft and manage email or push content.</p><button data-page="campaigns">Browse campaigns</button></article></div>`; }
function userRow(user) { const id = user.id ?? ''; return `<button class="record card" data-user-id="${escape(id)}"><div><h3>${escape(userDisplayName(user))}</h3><p class="muted">${escape(user.email ?? id)}</p></div><span class="badge">${escape(user.securityState ?? 'unknown')}</span></button>`; }
function userDetail(value) {
  const user = value.detail;
  const capabilities = value.sessionData?.capabilities ?? [];
  const canVerify = capabilities.includes('users.verify');
  const recoveryAllowed = user.securityState === 'normal'
    ? (!user.passwordDisabled || user.passwordResetRequired)
    : ['password_disabled', 'compromised'].includes(user.securityState) && user.passwordResetRequired;
  const canResetPassword = capabilities.includes('security.recovery_resend') && user.email && user.emailVerified && recoveryAllowed;
  const canSendLoginLink = capabilities.includes('campaign.login_link') && user.emailVerified && user.securityState === 'normal' && !user.passwordDisabled && !user.passwordResetRequired;
  const disabled = value.busy ? 'disabled' : '';
  const actions = [
    canVerify && user.email && !user.emailVerified ? `<button data-action="verify-user-email" ${disabled}>Mark email verified</button>` : '',
    canResetPassword ? `<button data-action="send-user-password-reset" ${disabled}>Send password reset link</button>` : '',
    canSendLoginLink ? `<button data-action="send-user-login-link" ${disabled}>Send 24-hour login link</button>` : '',
  ].filter(Boolean).join('');
  return `<div class="detail-actions"><button data-action="back">Back to users</button></div><article class="card"><h3>${escape(userDisplayName(user))}</h3><dl>${field('Username', user.username)}${field('User ID', user.id)}${field('Email', user.email)}${field('Security state', user.securityState)}${field('Email verified', user.emailVerified)}${field('Created', formatDate(user.createdAt))}${field('Admin account', user.isAdmin)}${field('Registered devices', user.registeredDeviceCount)}${field('Eligibility', (user.eligibilityReasons ?? []).join(', ') || 'eligible')}</dl><h4>Account actions</h4><p class="muted">A password reset email does not change the password until the user completes recovery.</p><div class="detail-actions">${actions || '<span class="muted">No actions are available for this account.</span>'}</div></article>`;
}
function reportRow(report) { return `<button class="record card" data-report-id="${escape(report.id ?? '')}"><div><h3>Report ${escape(report.id ?? '')}</h3><p class="muted">${escape(report.text ?? report.legacyMessage ?? '')}</p></div><span class="badge">${escape(report.status ?? 'open')}</span></button>`; }
function reportDetail(value) { const report = value.detail; const target = report.target ?? {}; const notes = value.notes ?? report.notes ?? []; return `<div class="detail-actions"><button data-action="back">Back to reports</button></div><article class="card"><h3>Report ${escape(report.id ?? '')}</h3><dl>${field('Status', report.status)}${field('Revision', report.revision)}${field('Reporter', report.reporterUserId)}${field('Target', target.userId ?? (target.deleted ? 'deleted account' : null))}${field('Created', formatDate(report.createdAt))}</dl><p>${escape(report.text ?? report.legacyMessage ?? 'No description supplied.')}</p><form id="report-update" class="stack-form"><label>Optional note<textarea name="note" rows="3" placeholder="Add context if useful"></textarea></label><div class="detail-actions"><button name="status" value="resolved" ${value.busy || report.status === 'resolved' ? 'disabled' : ''}>Resolve report</button><button name="status" value="dismissed" class="outline" ${value.busy || report.status === 'dismissed' ? 'disabled' : ''}>Dismiss report</button>${report.status !== 'open' ? `<button name="status" value="open" class="outline" ${value.busy ? 'disabled' : ''}>Reopen report</button>` : ''}</div></form></article><section class="card"><h3>Notes</h3>${notes.length ? `<div class="records">${notes.map((note) => `<article class="note"><p>${escape(note.text ?? '')}</p><small>${escape(note.actorUserId ?? '')} · ${formatDate(note.createdAt)}</small></article>`).join('')}</div>` : '<p class="muted">No notes.</p>'}<form id="note-form" class="stack-form"><label>Add note<textarea name="text" rows="2" required></textarea></label><button>Add note</button></form></section>`; }
function campaignRow(campaign) { return `<button class="record card" data-campaign-id="${escape(campaign.id ?? '')}"><div><h3>${escape(campaign.name ?? 'Campaign')}</h3><p class="muted">${escape(campaign.channel ?? '')} · ${escape(campaign.id ?? '')}</p></div><span class="badge">${escape(campaign.status ?? 'draft')}</span></button>`; }
function loginLinkCampaign(value) {
  const recipients = value.loginRecipients;
  const progress = value.loginProgress;
  const failed = value.loginFailedIds?.length ?? 0;
  let recipientMarkup;

  if (recipients === null || recipients === undefined) {
    recipientMarkup = `<p class="muted">${value.busy ? 'Finding eligible accounts…' : 'Eligible account list is not loaded.'}</p>`;
    if (!value.busy) recipientMarkup += '<button data-action="load-login-recipients">Load eligible accounts</button>';
  } else {
    const summary = failed
      ? `<p><strong>${failed}</strong> link${failed === 1 ? '' : 's'} still need to be queued.</p>`
      : `<p><strong>${value.loginTotal ?? recipients.length}</strong> eligible account${(value.loginTotal ?? recipients.length) === 1 ? '' : 's'} found.</p>`;
    const progressMarkup = progress
      ? `<p class="muted" role="status">Processed ${progress.done} of ${progress.total} accounts…</p>`
      : '';
    let actionMarkup = '';
    if (value.loginFinished) actionMarkup = '<p class="notice">All eligible login links have been queued.</p>';
    else if (recipients.length) {
      actionMarkup = `<form id="login-campaign" class="stack-form"><button ${value.busy ? 'disabled' : ''}>${failed ? `Retry ${failed} failed links` : 'Queue 24-hour links for everyone'}</button></form>`;
    } else if (value.loginTotal === 0) actionMarkup = '<p class="muted">No eligible accounts were found.</p>';
    recipientMarkup = `${summary}${progressMarkup}${actionMarkup}`;
  }

  return `<div class="detail-actions"><button data-action="back" ${value.busy ? 'disabled' : ''}>Back to campaigns</button></div><article class="card"><h3>Login email campaign</h3><p>This sends a one-time sign-in link that expires after 24 hours to every non-deleted account with a verified email, normal security state, and active sign-in eligibility. Administrator accounts are included. Email ownership is rechecked when each link is issued, so accounts that no longer qualify can fail and be retried.</p>${recipientMarkup}</article>`;
}
function campaignEditor(value, campaign) { const creating = value.editor === 'create'; const archived = !creating && campaign.status === 'archived'; const canLogin = creating && canSendLoginCampaign(value); return `<div class="detail-actions"><button data-action="back">Back to campaigns</button>${!creating && !archived ? '<button data-action="archive-campaign">Archive campaign</button>' : ''}${!creating && campaign.status === 'draft' ? '<button data-action="delete-campaign">Delete draft</button>' : ''}</div><article class="card"><h3>${creating ? 'New campaign' : escape(campaign.name ?? 'Campaign')}</h3>${creating ? '' : `<dl>${field('Campaign ID', campaign.id)}${field('Revision', campaign.revision)}${field('Created', formatDate(campaign.createdAt))}${field('Updated', formatDate(campaign.updatedAt))}${field('Created by', campaign.createdByUserId)}</dl>`}<p class="muted">Email and push campaign records store content only. Selecting Login starts an immediate send and does not create a content record.</p>${archived ? '<p class="notice">This campaign is archived and cannot be changed.</p>' : ''}<form id="campaign-editor" class="stack-form">${creating ? '' : `<input type="hidden" name="expectedRevision" value="${escape(campaign.revision ?? '')}">`}<label>Name<input name="name" value="${escape(campaign.name ?? '')}" maxlength="200" required ${archived ? 'disabled' : ''}></label><label>Channel<select name="channel" ${archived ? 'disabled' : ''}><option value="email" ${campaign.channel === 'email' ? 'selected' : ''}>Email</option><option value="push" ${campaign.channel === 'push' ? 'selected' : ''}>Push</option>${canLogin ? '<option value="login">Login · send 24-hour links to everyone</option>' : ''}</select></label><label>Email subject<input name="subject" value="${escape(campaign.subject ?? '')}" maxlength="200" ${archived ? 'disabled' : ''}></label><label>Push title<input name="title" value="${escape(campaign.title ?? '')}" maxlength="200" ${archived ? 'disabled' : ''}></label><label>Body<textarea name="body" rows="8" maxlength="10000" required ${archived ? 'disabled' : ''}>${escape(campaign.body ?? '')}</textarea></label><label>Status<select name="status" ${archived ? 'disabled' : ''}><option value="draft" ${campaign.status === 'draft' ? 'selected' : ''}>Draft</option><option value="active" ${campaign.status === 'active' ? 'selected' : ''}>Active</option></select></label>${archived ? '' : `<button ${value.busy ? 'disabled' : ''}>Save campaign content</button>`}</form></article>`; }
function emptyCampaign() { return { channel: 'email', status: 'draft' }; }
function auditRow(event) { return `<article class="record card"><div><h3>${escape(event.action ?? 'Audit event')}</h3><p class="muted">${escape(event.targetUserId ?? '')} · ${formatDate(event.occurredAt)}</p></div><span class="badge">${escape(event.outcome ?? 'recorded')}</span><details><summary>Details</summary><pre>${escape(JSON.stringify(event.details ?? event.reason ?? '', null, 2))}</pre></details></article>`; }
function collection(items = [], renderRow, nextCursor, kind) { if (!items.length && !nextCursor) return '<p class="muted">No records returned.</p>'; return `<div class="records">${items.map(renderRow).join('')}</div>${nextCursor ? `<button data-next-page="${kind}" data-cursor="${escape(nextCursor)}">Load more</button>` : ''}`; }
function field(label, value) { return value === undefined || value === null || value === '' ? '' : `<div><dt>${escape(label)}</dt><dd>${escape(value)}</dd></div>`; }

function bindPage() { root.querySelectorAll('#page-content [data-page]').forEach((button) => button.addEventListener('click', () => selectPage(button.dataset.page))); root.querySelector('#user-search')?.addEventListener('submit', searchUsers); root.querySelector('#report-search')?.addEventListener('submit', searchReports); root.querySelector('#audit-search')?.addEventListener('submit', searchAudit); root.querySelector('#login-campaign')?.addEventListener('submit', sendLoginCampaign); root.querySelector('#campaign-editor')?.addEventListener('submit', saveCampaign); root.querySelector('#campaign-editor select[name="channel"]')?.addEventListener('change', chooseCampaignChannel); root.querySelector('[data-action="load-login-recipients"]')?.addEventListener('click', loadLoginRecipients); root.querySelector('#report-update')?.addEventListener('submit', updateReport); root.querySelector('#note-form')?.addEventListener('submit', addNote); root.querySelector('[data-action="verify-user-email"]')?.addEventListener('click', verifyUserEmail); root.querySelector('[data-action="send-user-password-reset"]')?.addEventListener('click', sendUserPasswordResetLink); root.querySelector('[data-action="send-user-login-link"]')?.addEventListener('click', sendUserLoginLink); root.querySelector('[data-action="new-campaign"]')?.addEventListener('click', () => state.update({ editor: 'create', error: null, notice: null })); root.querySelector('[data-action="new-login-campaign"]')?.addEventListener('click', openLoginCampaign); root.querySelector('[data-action="archive-campaign"]')?.addEventListener('click', archiveCampaign); root.querySelector('[data-action="delete-campaign"]')?.addEventListener('click', deleteCampaign); root.querySelector('[data-action="back"]')?.addEventListener('click', () => state.update({ detail: null, notes: null, editor: null, loginRecipients: null, loginFailedIds: [], loginProgress: null, loginFinished: false })); root.querySelectorAll('[data-user-id]').forEach((button) => button.addEventListener('click', () => loadUser(button.dataset.userId))); root.querySelectorAll('[data-report-id]').forEach((button) => button.addEventListener('click', () => loadReport(button.dataset.reportId))); root.querySelectorAll('[data-campaign-id]').forEach((button) => button.addEventListener('click', () => loadCampaign(button.dataset.campaignId))); root.querySelector('[data-next-page]')?.addEventListener('click', (event) => loadPage(event.currentTarget.dataset.nextPage, { ...state.value.filters, cursor: event.currentTarget.dataset.cursor })); }
async function selectPage(page) { if (loginCampaignRunning) return; state.update({ page, detail: null, notes: null, editor: null, items: [], nextCursor: null, error: null, filters: {} }); if (page === 'overview') await loadOverview(); else await loadPage(page); }
async function loadOverview() { const results = await Promise.allSettled([api.listUsers({ limit: 100 }), api.listReports({ limit: 100, status: 'open' }), api.listCampaigns({ limit: 100 })]); const overview = Object.fromEntries(['users', 'reports', 'campaigns'].map((key, index) => [key, results[index].status === 'fulfilled' ? results[index].value : null])); state.update({ overview }); }
async function loadPage(page, options = {}) { state.update({ page, busy: true, error: null }); try { const result = page === 'users' ? await api.listUsers(options) : page === 'reports' ? await api.listReports(options) : page === 'campaigns' ? await api.listCampaigns(options) : await api.listAudit(options); state.update({ busy: false, loaded: true, items: result?.items ?? [], nextCursor: result?.nextCursor ?? null }); } catch (error) { handle(error); } }
async function searchUsers(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const filters = { search: form.get('search'), securityStatus: form.get('securityStatus'), verifiedEmail: form.get('verifiedEmail') }; state.update({ filters }); await loadPage('users', filters); }
function canSendLoginCampaign(value) { const capabilities = value.sessionData?.capabilities ?? []; return capabilities.includes('campaign.login_link') && capabilities.includes('users.read'); }
function openLoginCampaign() { if (loginCampaignRunning) return; state.update({ editor: 'login-links', loginRecipients: null, loginFailedIds: [], loginProgress: null, loginFinished: false, loginSentCount: 0, error: null, notice: null, busy: false }); loadLoginRecipients(); }
function chooseCampaignChannel(event) { if (event.currentTarget.value === 'login') openLoginCampaign(); }
async function loadLoginRecipients() {
  state.update({ busy: true, error: null, notice: null, loginRecipients: null, loginFailedIds: [], loginProgress: null, loginFinished: false, loginSentCount: 0 });
  try {
    const ids = [];
    let cursor;
    do {
      const page = await api.listUsers({ cursor, limit: 100, securityStatus: 'normal', verifiedEmail: true });
      for (const user of page?.items ?? []) {
        if (user.id && user.email && user.emailVerified && user.securityState === 'normal' && !user.passwordDisabled && !user.passwordResetRequired) ids.push(user.id);
      }
      if (!page?.nextCursor || page.nextCursor === cursor) break;
      cursor = page.nextCursor;
    } while (true);
    state.update({ busy: false, loginRecipients: ids, loginTotal: ids.length });
  } catch (error) { handle(error); }
}
async function sendLoginCampaign(event) {
  event.preventDefault();
  if (loginCampaignRunning) return;
  const ids = state.value.loginFailedIds?.length ? state.value.loginFailedIds : (state.value.loginRecipients ?? []);
  if (!ids.length) return;
  const retry = Boolean(state.value.loginFailedIds?.length);
  if (!window.confirm(`${retry ? 'Retry' : 'Queue'} 24-hour login links for ${ids.length} ${retry ? 'failed ' : ''}accounts? This sends an email immediately to every eligible account in this campaign.`)) return;
  loginCampaignRunning = true;
  try { await queueLoginLinks(ids); } finally { loginCampaignRunning = false; }
}
async function queueLoginLinks(ids) {
  const sentBefore = state.value.loginSentCount ?? 0;
  const total = state.value.loginTotal ?? ids.length;
  let queued = 0;
  const failedIds = [];
  state.update({ busy: true, error: null, notice: null, loginProgress: { done: sentBefore, total } });
  for (let start = 0; start < ids.length; start += 5) {
    const batch = ids.slice(start, start + 5);
    const outcomes = await Promise.allSettled(batch.map((id) => api.sendUserLoginLink(id)));
    outcomes.forEach((outcome, index) => {
      if (outcome.status === 'fulfilled') queued += 1;
      else failedIds.push(batch[index]);
    });
    const completed = Math.min(start + batch.length, ids.length);
    state.update({ loginProgress: { done: sentBefore + completed, total } });
    const blocked = outcomes.find((outcome) => outcome.status === 'rejected' && outcome.reason instanceof AdminHttpError && [401, 403].includes(outcome.reason.status));
    if (blocked) {
      const unattempted = ids.slice(completed);
      state.update({ busy: false, loginRecipients: failedIds.concat(unattempted), loginFailedIds: failedIds.concat(unattempted), loginSentCount: sentBefore + queued, loginProgress: null });
      handle(blocked.reason);
      return;
    }
  }
  const sentCount = sentBefore + queued;
  state.update({
    busy: false, loginRecipients: failedIds, loginFailedIds: failedIds, loginSentCount: sentCount,
    loginFinished: failedIds.length === 0, loginProgress: null,
    notice: `Queued 24-hour login links for ${sentCount} of ${total} eligible accounts.`,
    error: failedIds.length ? `${failedIds.length} account${failedIds.length === 1 ? '' : 's'} could not be queued. You can retry those accounts below.` : null,
  });
}
async function searchReports(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const filters = { search: form.get('search'), status: form.get('status') }; state.update({ filters }); await loadPage('reports', filters); }
async function searchAudit(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const filters = { targetUserId: form.get('targetUserId'), action: form.get('action') }; state.update({ filters }); await loadPage('audit', filters); }
async function loadUser(id) { state.update({ busy: true, error: null }); try { state.update({ detail: await api.getUser(id), busy: false }); } catch (error) { handle(error); } }
async function verifyUserEmail() { const id = state.value.detail?.id; if (!id || !window.confirm(`Mark ${state.value.detail.email} as verified?`)) return; await mutate(async () => { state.update({ detail: await api.verifyUserEmail(id) }); }, 'Email marked verified.'); }
async function sendUserPasswordResetLink() { const user = state.value.detail; if (!user?.id || !user.email || !user.emailVerified || !window.confirm(`Send a password reset email to ${user.email}? Their current password stays active until they complete recovery.`)) return; await mutate(() => api.sendUserPasswordResetLink(user.id), 'Password reset email sent.'); }
async function sendUserLoginLink() { const user = state.value.detail; if (!user?.id || !window.confirm(`Send a one-time login link valid for 24 hours to ${user.email}?`)) return; await mutate(() => api.sendUserLoginLink(user.id), '24-hour login link queued.'); }
async function loadReport(id) { state.update({ busy: true, error: null, notes: null }); try { const report = await api.getReport(id); const notes = await api.listReportNotes(id); state.update({ detail: report, notes: notes?.items ?? [], busy: false }); } catch (error) { handle(error); } }
async function loadCampaign(id) { state.update({ busy: true, error: null, editor: null }); try { state.update({ detail: await api.getCampaign(id), busy: false }); } catch (error) { handle(error); } }
async function updateReport(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const id = state.value.detail.id; const status = event.submitter?.value; if (!['open', 'resolved', 'dismissed'].includes(status)) return; const update = reportUpdatePayload({ revision: state.value.detail.revision, status, note: form.get('note') }); await mutate(() => api.updateReport(id, update), 'Report saved.'); if (!state.value.error) await loadReport(id); }
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
async function mutate(operation, notice) { state.update({ busy: true, error: null }); try { await operation(); state.update({ busy: false, notice }); } catch (error) { handle(error); } }
function handle(error) { if (error instanceof AdminHttpError && error.unauthorized) { state.update({ session: 'login', busy: true, error: 'Session expired. Preparing sign-in…' }); api.bootstrap().then(() => state.update({ busy: false, error: null })).catch((bootstrapError) => state.update({ session: 'error', busy: false, error: message(bootstrapError) })); } else if (error instanceof AdminHttpError && error.forbidden) state.update({ busy: false, error: 'You do not have permission for this operation.' }); else if (error instanceof AdminHttpError && error.status === 409) state.update({ busy: false, error: 'This record changed. Reload it and reapply your change.' }); else state.update({ busy: false, error: message(error) }); }
async function logout() { try { await api.logout(); } finally { state.update({ session: 'login', sessionData: null, loaded: false, busy: true, error: null }); try { await api.bootstrap(); state.update({ busy: false }); } catch (error) { state.update({ session: 'error', busy: false, error: message(error) }); } } }
function title(value) { return value[0].toUpperCase() + value.slice(1); }
function message(error) { return error instanceof Error ? error.message : 'The admin request could not be completed.'; }
function formatDate(value) { if (!value) return '—'; const date = new Date(value); return Number.isNaN(date.valueOf()) ? String(value) : date.toLocaleString(); }
function escape(value) { return String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char])); }
