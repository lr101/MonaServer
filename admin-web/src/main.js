import { AdminApi, AdminHttpError } from './api.js';
import { AdminState } from './state.js';
import { countLabel, reportUpdatePayload, userDisplayName } from './view-model.js';

const root = document.querySelector('#app');
const api = new AdminApi();
const state = new AdminState({ page: 'overview', items: [], filters: {} });
let challengeId = null;
let loginCampaignRunning = false;
let startupInProgress = false;

const loginTemplateVariables = [
  { name: 'username', description: 'The recipient’s username.' },
  { name: 'email', description: 'The verified email address receiving this message.' },
  { name: 'login_link', description: 'Their unique, one-time sign-in link. It expires after 24 hours.' },
  { name: 'expires_in', description: 'The link lifetime, shown as “24 hours”.' },
  { name: 'app_name', description: 'The application name, Stick-It.' },
];
const defaultLoginEmailBody = 'Hello {{username}},\n\nUse the link below to sign in to {{app_name}}:\n{{login_link}}\n\nThis one-time link expires in {{expires_in}}. If you did not request it, you can ignore this email.';
const loginProgressStoragePrefix = 'admin.login-email-send.';

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

function tools(value) { if (value.page === 'users') return `<form id="user-search" class="inline-form"><input name="search" value="${escape(value.filters.search ?? '')}" placeholder="Username, email, or user ID" aria-label="Search users"><select name="securityStatus" aria-label="Security state"><option value="">Any security state</option>${['normal', 'password_disabled', 'compromised', 'secured_manual_recovery_required', 'deleted'].map((status) => `<option value="${status}" ${value.filters.securityStatus === status ? 'selected' : ''}>${status.replaceAll('_', ' ')}</option>`).join('')}</select><select name="verifiedEmail" aria-label="Email verification"><option value="">Any email status</option><option value="true" ${value.filters.verifiedEmail === 'true' ? 'selected' : ''}>Verified email</option><option value="false" ${value.filters.verifiedEmail === 'false' ? 'selected' : ''}>Unverified email</option></select><button>Search</button></form>`; if (value.page === 'reports') return `<form id="report-search" class="inline-form"><input name="search" value="${escape(value.filters.search ?? '')}" placeholder="Search reports"><select name="status"><option value="">All statuses</option>${['open', 'resolved', 'dismissed'].map((status) => `<option value="${status}" ${value.filters.status === status ? 'selected' : ''}>${title(status)}</option>`).join('')}</select><button>Search</button></form>`; if (value.page === 'campaigns' && !value.detail && !value.editor) return '<div class="detail-actions"><button data-action="new-campaign">New campaign</button></div>'; if (value.page === 'audit') return `<form id="audit-search" class="inline-form"><input name="targetUserId" value="${escape(value.filters.targetUserId ?? '')}" placeholder="Target user ID"><input name="action" value="${escape(value.filters.action ?? '')}" placeholder="Action"><button>Search</button></form>`; return ''; }

function pageMarkup(value) {
  if (value.busy && !value.detail && value.editor !== 'login-links') return '<div class="loading">Loading…</div>';
  if (value.page === 'overview') return overviewMarkup(value);
  if (value.page === 'users') return value.detail ? userDetail(value) : collection(value.items, userRow, value.nextCursor, 'users');
  if (value.page === 'reports') return value.detail ? reportDetail(value) : collection(value.items, reportRow, value.nextCursor, 'reports');
  if (value.page === 'campaigns') return value.editor === 'login-links' ? loginLinkCampaign(value) : value.editor === 'create' ? campaignEditor(value, emptyCampaign()) : value.detail ? campaignEditor(value, value.detail) : collection(value.items, campaignRow, value.nextCursor, 'campaigns');
  return collection(value.items, auditRow, value.nextCursor, 'audit');
}

function overviewMarkup(value) { const stats = value.overview; return `<div class="grid stats">${[['Accounts', stats?.users], ['Open reports', stats?.reports], ['Campaigns', stats?.campaigns]].map(([label, page]) => `<article class="card stat"><p class="muted">${label}</p><strong>${page ? countLabel(page) : '—'}</strong><small>${!page ? 'Unavailable or no access' : page.nextCursor ? 'At least this many records' : 'Records found'}</small></article>`).join('')}</div><p class="muted">Counts show up to the first 100 records in each section.</p><div class="grid"><article class="card"><h3>Review reports</h3><p>${stats?.reports?.items?.length ? 'Open reports need a decision.' : 'Review the open reports queue.'}</p><button data-page="reports">Open reports</button></article><article class="card"><h3>Find an account</h3><p>Search by username, email, or user ID.</p><button data-page="users">Browse users</button></article><article class="card"><h3>Login email campaigns</h3><p>Create a personalized login email template and follow its queue progress.</p><button data-page="campaigns">Browse campaigns</button></article></div>`; }
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
function campaignRow(campaign) { const invalidActiveEmail = campaign.status === 'active' && campaign.channel === 'email' && validateLoginTemplate({ subject: campaign.subject ?? '', body: campaign.body ?? '' }); const status = invalidActiveEmail ? 'template needs update' : campaign.status === 'active' ? 'ready to send' : campaign.status ?? 'draft'; return `<button class="record card" data-campaign-id="${escape(campaign.id ?? '')}"><div><h3>${escape(campaign.name ?? 'Campaign')}</h3><p class="muted">${escape(campaign.channel ?? '')} · ${escape(campaign.id ?? '')}</p></div><span class="badge">${escape(status)}</span></button>`; }
function loginLinkCampaign(value) {
  const campaign = value.detail ?? {};
  const recipients = value.loginRecipients;
  const progress = value.loginProgress;
  const failed = value.loginFailedIds?.length ?? 0;
  let recipientMarkup;

  if (recipients === null || recipients === undefined) {
    recipientMarkup = `<p class="muted">${value.busy ? 'Finding eligible accounts…' : 'Eligible account list is not loaded.'}</p>`;
    if (!value.busy) recipientMarkup += '<button data-action="load-login-recipients">Load eligible accounts</button>';
  } else {
    const total = value.loginTotal ?? recipients.length;
    const progressMarkup = progress
      ? `<section class="campaign-progress-card" aria-live="polite"><div class="progress-heading"><strong>${value.busy ? 'Sending login emails' : progress.failed || progress.pending ? 'Needs attention' : 'Send complete'}</strong><span>${progress.done} of ${progress.total} processed</span></div><progress class="campaign-progress" max="${Math.max(progress.total, 1)}" value="${Math.min(progress.done, progress.total)}">${progress.done} of ${progress.total}</progress><p class="muted">${progress.queued} queued · ${progress.skipped ?? 0} skipped · ${progress.failed} failed${progress.pending ? ` · ${progress.pending} not attempted` : ''}${value.busy ? ' · processing eligible accounts' : ''}</p><small class="muted">Counts track requests queued by the server; inbox delivery may take a little longer. Progress is saved in this browser, and resuming the same send will not queue a recipient twice.</small></section>`
      : '';
    const summary = failed
      ? `<p><strong>${failed}</strong> account${failed === 1 ? '' : 's'} remain in this send. ${value.loginSentCount ?? 0} already queued.</p>`
      : `<p><strong>${total}</strong> eligible account${total === 1 ? '' : 's'} found.</p>`;
    let actionMarkup = '';
    if (value.loginFinished) actionMarkup = `<p class="notice">Send finished: ${value.loginSentCount ?? 0} login emails queued${value.loginSkippedIds?.length ? `; ${value.loginSkippedIds.length} accounts skipped because they became ineligible` : ''}. Each sign-in link expires after 24 hours.</p>`;
    else if (recipients.length) {
      actionMarkup = `<form id="login-campaign" class="stack-form"><button ${value.busy ? 'disabled' : ''}>${failed ? `Resume ${failed} remaining accounts` : 'Send login email campaign'}</button></form>`;
    } else if (value.loginTotal === 0) actionMarkup = '<p class="muted">No eligible accounts were found.</p>';
    recipientMarkup = `${summary}${progressMarkup}${actionMarkup}`;
  }

  const template = value.loginTemplate ?? { subject: campaign.subject ?? '', body: campaign.body ?? '' };
  return `<div class="detail-actions"><button data-action="back-to-campaign" ${value.busy ? 'disabled' : ''}>Back to campaign</button></div><article class="card"><p class="eyebrow">${escape(campaign.name ?? 'Campaign')}</p><h3>Login email campaign</h3><p>This sends a unique, one-time sign-in link that expires after 24 hours to each eligible account. The current verified email and sign-in eligibility are rechecked for each account. Administrator accounts can receive the message too.</p><dl>${field('Email subject', template.subject)}${field('Template status', campaign.status === 'active' ? 'Ready to send' : campaign.status)}</dl></article><article class="card"><h3>Recipients and progress</h3>${recipientMarkup}</article><article class="card"><h3>Email preview</h3><p class="muted">A sample using username “Alex” and a safe example link:</p><p><strong>${escape(previewTemplate(template.subject ?? '', 'Alex', 'alex@example.com'))}</strong></p><div class="email-preview">${escape(previewTemplate(template.body ?? '', 'Alex', 'alex@example.com')).replaceAll('\n', '<br>')}</div></article>`;
}
function campaignEditor(value, campaign) {
  const creating = value.editor === 'create';
  const archived = !creating && campaign.status === 'archived';
  const email = campaign.channel === 'email';
  const templateProblem = email ? validateLoginTemplate({ subject: campaign.subject ?? '', body: campaign.body ?? '' }) : null;
  const canSend = !creating && !archived && email && campaign.status === 'active' && !templateProblem && !value.loginCampaignStale && canSendLoginCampaign(value);
  const sameSendRevision = value.loginCampaignRevision === undefined || Number(value.loginCampaignRevision) === Number(campaign.revision);
  const failedForCampaign = canSend && sameSendRevision && value.loginCampaignId === campaign.id ? value.loginFailedIds?.length ?? 0 : 0;
  const sendAction = failedForCampaign
    ? `<button data-action="resume-campaign-send" data-persisted-campaign-send ${value.busy ? 'disabled' : ''}>Resume ${failedForCampaign} remaining accounts</button>`
    : canSend ? `<button data-action="start-campaign-send" data-persisted-campaign-send ${value.busy ? 'disabled' : ''}>${value.loginCampaignId === campaign.id && value.loginFinished ? 'Send campaign again' : 'Send login email campaign'}</button>` : '';
  const currentProgress = !creating && value.loginCampaignId === campaign.id ? value.loginProgress : null;
  const emailFields = campaignEmailFields(campaign, archived, email);
  const pushFields = campaignPushFields(campaign, archived, !email);
  return `<div class="detail-actions"><button data-action="back">Back to campaigns</button>${sendAction}${!creating && !archived ? '<button data-action="archive-campaign">Archive campaign</button>' : ''}${!creating && campaign.status === 'draft' ? '<button data-action="delete-campaign">Delete draft</button>' : ''}</div><article class="card"><h3>${creating ? 'New campaign' : escape(campaign.name ?? 'Campaign')}</h3>${creating ? '' : `<dl>${field('Campaign ID', campaign.id)}${field('Revision', campaign.revision)}${field('Created', formatDate(campaign.createdAt))}${field('Updated', formatDate(campaign.updatedAt))}${field('Created by', campaign.createdByUserId)}${field('Status', campaign.status === 'active' && templateProblem ? 'Template needs update' : campaign.status === 'active' ? 'Ready to send' : campaign.status)}</dl>`}<p class="muted">Email campaigns send a one-time 24-hour sign-in link to eligible accounts. Set the subject and message below; variables are filled separately for every recipient. Push campaigns continue to store push content.</p>${value.loginCampaignStale && value.loginCampaignId === campaign.id ? '<p class="error" role="alert">This campaign changed during the previous send. Reload it before sending again. <button type="button" data-action="reload-campaign">Reload campaign</button></p>' : ''}${templateProblem && campaign.status === 'active' ? `<p class="error" role="alert">${escape(templateProblem)} Set the campaign to Draft, fix the template, then activate it again.</p>` : ''}${archived ? '<p class="notice">This campaign is archived and cannot be changed.</p>' : ''}${currentProgress ? `<section class="campaign-progress-card"><div class="progress-heading"><strong>${value.busy ? 'Sending login emails' : 'Most recent send'}</strong><span>${currentProgress.done} of ${currentProgress.total}</span></div><progress class="campaign-progress" max="${Math.max(currentProgress.total, 1)}" value="${Math.min(currentProgress.done, currentProgress.total)}"></progress><p class="muted">${currentProgress.queued} queued · ${currentProgress.skipped ?? 0} skipped · ${currentProgress.failed} failed${currentProgress.pending ? ` · ${currentProgress.pending} not attempted` : ''}</p><small class="muted">Progress is saved in this browser. Resuming uses the same send ID to avoid duplicate queue requests.</small></section>` : ''}<form id="campaign-editor" class="stack-form">${creating ? '' : `<input type="hidden" name="expectedRevision" value="${escape(campaign.revision ?? '')}">`}<label>Name<input name="name" value="${escape(campaign.name ?? '')}" maxlength="200" required ${archived ? 'disabled' : ''}></label><label>Channel<select name="channel" ${archived ? 'disabled' : ''}><option value="email" ${email ? 'selected' : ''}>Email · login link campaign</option><option value="push" ${!email ? 'selected' : ''}>Push</option></select></label>${emailFields}${pushFields}<label>Status<select name="status" ${archived ? 'disabled' : ''}><option value="draft" ${campaign.status === 'draft' ? 'selected' : ''}>Draft</option><option value="active" ${campaign.status === 'active' ? 'selected' : ''}>Active · ready to send</option></select></label>${archived ? '' : `<button ${value.busy ? 'disabled' : ''}>${creating ? 'Save campaign' : 'Save changes'}</button>`}</form></article>`;
}
function campaignEmailFields(campaign, archived, selected) {
  const disabled = archived || !selected;
  return `<section data-channel-fields="email" ${selected ? '' : 'hidden'}><label>Email subject<input data-campaign-template-field="subject" name="subject" value="${escape(campaign.subject ?? '')}" maxlength="200" required ${disabled ? 'disabled' : ''}></label>${templateVariableInfo('subject', disabled)}<label>Email message<textarea data-campaign-template-field="body" name="body" rows="8" maxlength="10000" required ${disabled ? 'disabled' : ''}>${escape(campaign.body ?? '')}</textarea></label>${templateVariableInfo('body', disabled)}<section class="template-preview"><h4>Preview</h4><p class="muted">Sample personalization for Alex. Real links are unique and valid for 24 hours.</p><p data-preview-subject><strong>${escape(previewTemplate(campaign.subject ?? '', 'Alex', 'alex@example.com')) || 'Email subject'}</strong></p><div class="email-preview" data-preview-body>${escape(previewTemplate(campaign.body ?? '', 'Alex', 'alex@example.com')).replaceAll('\n', '<br>')}</div></section></section>`;
}
function campaignPushFields(campaign, archived, selected) {
  const disabled = archived || !selected;
  return `<section data-channel-fields="push" ${selected ? '' : 'hidden'}><label>Push title<input name="title" value="${escape(campaign.title ?? '')}" maxlength="200" required ${disabled ? 'disabled' : ''}></label><label>Push message<textarea name="body" rows="8" maxlength="10000" required ${disabled ? 'disabled' : ''}>${escape(campaign.body ?? '')}</textarea></label></section>`;
}
function templateVariableInfo(target, disabled) { const variables = loginTemplateVariables.filter(({ name }) => target === 'subject' ? !['login_link', 'username', 'email'].includes(name) : true); const note = target === 'subject' ? 'Use app_name or expires_in here; the subject must fit 200 bytes for every recipient. Put username, email, and the login link in the message body.' : 'Include {{login_link}} in the message so recipients can sign in.'; return `<aside class="variable-info"><strong>Available variables</strong><p>Select a token to insert it at the cursor. ${note}</p><div class="variable-list">${variables.map(({ name, description }) => `<button type="button" class="variable-chip" data-insert-variable="${name}" data-target="${target}" title="${escape(description)}" ${disabled ? 'disabled' : ''}>{{${name}}}</button>`).join('')}</div></aside>`; }
function emptyCampaign() { return { channel: 'email', subject: 'Sign in to {{app_name}}', body: defaultLoginEmailBody, status: 'draft' }; }
function auditRow(event) { return `<article class="record card"><div><h3>${escape(event.action ?? 'Audit event')}</h3><p class="muted">${escape(event.targetUserId ?? '')} · ${formatDate(event.occurredAt)}</p></div><span class="badge">${escape(event.outcome ?? 'recorded')}</span><details><summary>Details</summary><pre>${escape(JSON.stringify(event.details ?? event.reason ?? '', null, 2))}</pre></details></article>`; }
function collection(items = [], renderRow, nextCursor, kind) { if (!items.length && !nextCursor) return '<p class="muted">No records returned.</p>'; return `<div class="records">${items.map(renderRow).join('')}</div>${nextCursor ? `<button data-next-page="${kind}" data-cursor="${escape(nextCursor)}">Load more</button>` : ''}`; }
function field(label, value) { return value === undefined || value === null || value === '' ? '' : `<div><dt>${escape(label)}</dt><dd>${escape(value)}</dd></div>`; }

function bindPage() { root.querySelectorAll('#page-content [data-page]').forEach((button) => button.addEventListener('click', () => selectPage(button.dataset.page))); root.querySelector('#user-search')?.addEventListener('submit', searchUsers); root.querySelector('#report-search')?.addEventListener('submit', searchReports); root.querySelector('#audit-search')?.addEventListener('submit', searchAudit); root.querySelector('#login-campaign')?.addEventListener('submit', sendLoginCampaign); root.querySelector('#campaign-editor')?.addEventListener('submit', saveCampaign); root.querySelector('#campaign-editor select[name="channel"]')?.addEventListener('change', toggleCampaignFields); root.querySelector('#campaign-editor select[name="status"]')?.addEventListener('change', updateSendButton); root.querySelector('#campaign-editor input[name="name"]')?.addEventListener('input', updateSendButton); root.querySelector('#campaign-editor input[name="subject"]')?.addEventListener('input', updateTemplatePreview); root.querySelector('#campaign-editor textarea[data-campaign-template-field="body"]')?.addEventListener('input', updateTemplatePreview); root.querySelectorAll('[data-insert-variable]').forEach((button) => button.addEventListener('click', insertTemplateVariable)); root.querySelector('[data-action="start-campaign-send"]')?.addEventListener('click', beginCampaignLoginSend); root.querySelector('[data-action="resume-campaign-send"]')?.addEventListener('click', resumeCampaignSend); root.querySelector('[data-action="reload-campaign"]')?.addEventListener('click', () => loadCampaign(state.value.detail?.id)); root.querySelector('[data-action="load-login-recipients"]')?.addEventListener('click', loadLoginRecipients); root.querySelector('#report-update')?.addEventListener('submit', updateReport); root.querySelector('#note-form')?.addEventListener('submit', addNote); root.querySelector('[data-action="verify-user-email"]')?.addEventListener('click', verifyUserEmail); root.querySelector('[data-action="send-user-password-reset"]')?.addEventListener('click', sendUserPasswordResetLink); root.querySelector('[data-action="send-user-login-link"]')?.addEventListener('click', sendUserLoginLink); root.querySelector('[data-action="new-campaign"]')?.addEventListener('click', () => state.update({ editor: 'create', error: null, notice: null })); root.querySelector('[data-action="archive-campaign"]')?.addEventListener('click', archiveCampaign); root.querySelector('[data-action="delete-campaign"]')?.addEventListener('click', deleteCampaign); root.querySelector('[data-action="back-to-campaign"]')?.addEventListener('click', () => state.update({ editor: null })); root.querySelector('[data-action="back"]')?.addEventListener('click', () => state.update({ detail: null, notes: null, editor: null, loginRecipients: null, loginFailedIds: [], loginProgress: null, loginFinished: false })); root.querySelectorAll('[data-user-id]').forEach((button) => button.addEventListener('click', () => loadUser(button.dataset.userId))); root.querySelectorAll('[data-report-id]').forEach((button) => button.addEventListener('click', () => loadReport(button.dataset.reportId))); root.querySelectorAll('[data-campaign-id]').forEach((button) => button.addEventListener('click', () => loadCampaign(button.dataset.campaignId))); root.querySelector('[data-next-page]')?.addEventListener('click', (event) => loadPage(event.currentTarget.dataset.nextPage, { ...state.value.filters, cursor: event.currentTarget.dataset.cursor })); }
async function selectPage(page) { if (loginCampaignRunning) return; state.update({ page, detail: null, notes: null, editor: null, items: [], nextCursor: null, error: null, filters: {} }); if (page === 'overview') await loadOverview(); else await loadPage(page); }
async function loadOverview() { const results = await Promise.allSettled([api.listUsers({ limit: 100 }), api.listReports({ limit: 100, status: 'open' }), api.listCampaigns({ limit: 100 })]); const overview = Object.fromEntries(['users', 'reports', 'campaigns'].map((key, index) => [key, results[index].status === 'fulfilled' ? results[index].value : null])); state.update({ overview }); }
async function loadPage(page, options = {}) { state.update({ page, busy: true, error: null }); try { const result = page === 'users' ? await api.listUsers(options) : page === 'reports' ? await api.listReports(options) : page === 'campaigns' ? await api.listCampaigns(options) : await api.listAudit(options); state.update({ busy: false, loaded: true, items: result?.items ?? [], nextCursor: result?.nextCursor ?? null }); } catch (error) { handle(error); } }
async function searchUsers(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const filters = { search: form.get('search'), securityStatus: form.get('securityStatus'), verifiedEmail: form.get('verifiedEmail') }; state.update({ filters }); await loadPage('users', filters); }
function canSendLoginCampaign(value) { const capabilities = value.sessionData?.capabilities ?? []; return capabilities.includes('campaign.login_link') && capabilities.includes('campaigns.read') && capabilities.includes('users.read'); }
function beginCampaignLoginSend() {
  const campaign = state.value.detail;
  if (!campaign || campaign.channel !== 'email' || campaign.status !== 'active' || !canSendLoginCampaign(state.value)) return;
  const template = { subject: campaign.subject ?? '', body: campaign.body ?? '' };
  const invalid = validateLoginTemplate(template);
  if (invalid) { state.update({ error: invalid, notice: null }); return; }
  state.update({
    editor: 'login-links', loginCampaignId: campaign.id, loginCampaignRevision: Number(campaign.revision), loginTemplate: template,
    loginSendId: crypto.randomUUID(), loginAllRecipientIds: [], loginQueuedIds: [],
    loginRecipients: null, loginFailedIds: [], loginSkippedIds: [], loginProgress: null, loginFinished: false, loginTotal: null,
    loginSentCount: 0, error: null, notice: null, busy: false,
  });
  loadLoginRecipients();
}
async function resumeCampaignSend() {
  if (loginCampaignRunning) return;
  const campaign = state.value.detail;
  const ids = state.value.loginFailedIds ?? [];
  const template = { subject: campaign?.subject ?? '', body: campaign?.body ?? '' };
  const invalid = validateLoginTemplate(template);
  if (campaign && state.value.loginCampaignRevision !== undefined && Number(state.value.loginCampaignRevision) !== Number(campaign.revision)) {
    state.update({ error: 'This campaign changed during the previous send. Reload it and start a new send with the current template.', notice: null });
    return;
  }
  if (!campaign || !ids.length || invalid) {
    if (invalid) state.update({ error: invalid, notice: null });
    return;
  }
  if (!window.confirm(`Retry the login email for ${ids.length} remaining account${ids.length === 1 ? '' : 's'}?`)) return;
  loginCampaignRunning = true;
  state.update({ editor: 'login-links', loginTemplate: template, loginSendId: state.value.loginSendId ?? crypto.randomUUID(), error: null, notice: null });
  try { await queueLoginLinks(ids); } finally { loginCampaignRunning = false; }
}
async function loadLoginRecipients() {
  state.update({ busy: true, error: null, notice: null, loginRecipients: null, loginAllRecipientIds: [], loginQueuedIds: [], loginFailedIds: [], loginSkippedIds: [], loginProgress: null, loginFinished: false, loginSentCount: 0, loginTotal: null });
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
    state.update({ busy: false, loginRecipients: ids, loginAllRecipientIds: ids, loginTotal: ids.length });
    persistLoginCampaignProgress({ status: 'ready', pendingIds: ids, failedIds: [], skippedIds: [], queuedIds: [], progress: null, finished: false });
  } catch (error) { handle(error); }
}
async function sendLoginCampaign(event) {
  event.preventDefault();
  if (loginCampaignRunning) return;
  const ids = state.value.loginFailedIds?.length ? state.value.loginFailedIds : (state.value.loginRecipients ?? []);
  if (!ids.length) return;
  const retry = Boolean(state.value.loginFailedIds?.length);
  if (!window.confirm(`${retry ? 'Retry' : 'Queue'} the 24-hour login email for ${ids.length} ${retry ? 'failed ' : ''}accounts?`)) return;
  loginCampaignRunning = true;
  try { await queueLoginLinks(ids); } finally { loginCampaignRunning = false; }
}
async function queueLoginLinks(ids) {
  const total = state.value.loginTotal ?? ids.length;
  const allIds = state.value.loginAllRecipientIds?.length ? state.value.loginAllRecipientIds : ids;
  const queuedIds = new Set(state.value.loginQueuedIds ?? []);
  const failedIds = new Set();
  const skippedIds = new Set(state.value.loginSkippedIds ?? []);
  const pendingIds = () => allIds.filter((id) => !queuedIds.has(id) && !failedIds.has(id) && !skippedIds.has(id));
  const progress = () => ({ done: queuedIds.size + skippedIds.size + failedIds.size, total, queued: queuedIds.size, skipped: skippedIds.size, failed: failedIds.size, pending: pendingIds().length });
  state.update({ busy: true, error: null, notice: null, loginProgress: progress(), loginQueuedIds: [...queuedIds] });
  persistLoginCampaignProgress({ status: 'sending', queuedIds: [...queuedIds], failedIds: [], skippedIds: [...skippedIds], pendingIds: [...ids], progress: progress(), finished: false });
  for (let start = 0; start < ids.length; start += 5) {
    const batch = ids.slice(start, start + 5);
    const campaign = state.value.detail;
    const campaignContext = { campaignId: campaign.id, campaignRevision: Number(state.value.loginCampaignRevision ?? campaign.revision), sendId: state.value.loginSendId };
    const outcomes = await Promise.allSettled(batch.map((id) => api.sendUserLoginLink(id, campaignContext)));
    outcomes.forEach((outcome, index) => {
      if (outcome.status === 'fulfilled') { queuedIds.add(batch[index]); failedIds.delete(batch[index]); skippedIds.delete(batch[index]); }
      else if (outcome.reason instanceof AdminHttpError && outcome.reason.status === 410) { skippedIds.add(batch[index]); failedIds.delete(batch[index]); }
      else failedIds.add(batch[index]);
    });
    const completed = Math.min(start + batch.length, ids.length);
    state.update({ loginProgress: progress(), loginQueuedIds: [...queuedIds] });
    persistLoginCampaignProgress({ status: 'sending', queuedIds: [...queuedIds], failedIds: [...failedIds], skippedIds: [...skippedIds], pendingIds: pendingIds(), progress: progress(), finished: false });
    const blocked = outcomes.find((outcome) => outcome.status === 'rejected' && outcome.reason instanceof AdminHttpError && [401, 403, 409].includes(outcome.reason.status));
    if (blocked) {
      const unattempted = ids.slice(completed);
      unattempted.forEach((id) => failedIds.add(id));
      const retryIds = [...failedIds];
      const blockedProgress = { done: queuedIds.size + skippedIds.size + failedIds.size - unattempted.length, total, queued: queuedIds.size, skipped: skippedIds.size, failed: failedIds.size - unattempted.length, pending: unattempted.length };
      state.update({ busy: false, loginRecipients: retryIds, loginFailedIds: retryIds, loginSkippedIds: [...skippedIds], loginSentCount: queuedIds.size, loginProgress: blockedProgress });
      persistLoginCampaignProgress({ status: 'sending', queuedIds: [...queuedIds], failedIds: retryIds, skippedIds: [...skippedIds], pendingIds: unattempted, progress: blockedProgress, finished: false });
      if (blocked.reason.status === 409) state.update({ loginCampaignStale: true, error: 'This campaign changed while sending. Reload it before resuming; remaining recipients were not sent.', notice: null });
      else handle(blocked.reason);
      return;
    }
  }
  const failedList = [...failedIds];
  const remaining = pendingIds();
  const sentCount = queuedIds.size;
  const finalProgress = { done: queuedIds.size + skippedIds.size + failedIds.size, total, queued: sentCount, skipped: skippedIds.size, failed: failedIds.size, pending: remaining.length };
  state.update({
    busy: false, loginRecipients: failedList.concat(remaining), loginFailedIds: failedList.concat(remaining), loginSkippedIds: [...skippedIds], loginSentCount: sentCount,
    loginFinished: failedIds.size === 0 && remaining.length === 0, loginProgress: finalProgress,
    notice: `Queued 24-hour login emails for ${sentCount} of ${total} eligible accounts.${skippedIds.size ? ` Skipped ${skippedIds.size} account${skippedIds.size === 1 ? '' : 's'} that became ineligible.` : ''}`,
    error: failedIds.size || remaining.length ? `${failedIds.size + remaining.length} account${failedIds.size + remaining.length === 1 ? '' : 's'} still need a login email. You can resume this send below.` : null,
  });
  persistLoginCampaignProgress({ status: state.value.loginFinished ? 'complete' : 'sending', queuedIds: [...queuedIds], failedIds: failedList, skippedIds: [...skippedIds], pendingIds: remaining, progress: finalProgress, finished: state.value.loginFinished });
}
function persistLoginCampaignProgress({ status, queuedIds, failedIds, skippedIds = [], pendingIds, progress, finished }) {
  const campaign = state.value.detail;
  const sendId = state.value.loginSendId;
  if (!campaign?.id || !sendId) return;
  const record = {
    campaignRevision: Number(campaign.revision), sendId, status,
    total: state.value.loginTotal ?? state.value.loginAllRecipientIds?.length ?? 0,
    allIds: state.value.loginAllRecipientIds ?? [], queuedIds, failedIds, skippedIds, pendingIds, progress, finished,
  };
  try { localStorage.setItem(`${loginProgressStoragePrefix}${campaign.id}`, JSON.stringify(record)); } catch { /* Storage can be unavailable in private browsing. */ }
}
function restoreLoginCampaignProgress(campaign) {
  try {
    const key = `${loginProgressStoragePrefix}${campaign.id}`;
    const record = JSON.parse(localStorage.getItem(key) ?? 'null');
    if (!record || record.status === 'ready') return {};
    if (Number(record.campaignRevision) !== Number(campaign.revision)) {
      localStorage.removeItem(key);
      return {};
    }
    const queuedIds = Array.isArray(record.queuedIds) ? record.queuedIds : [];
    const skippedIds = Array.isArray(record.skippedIds) ? record.skippedIds : [];
    const remaining = [...new Set([...(record.failedIds ?? []), ...(record.pendingIds ?? [])])];
    const progress = record.progress ?? { done: queuedIds.length + skippedIds.length, total: record.total ?? 0, queued: queuedIds.length, skipped: skippedIds.length, failed: remaining.length, pending: 0 };
    return {
      loginCampaignId: campaign.id, loginCampaignRevision: Number(record.campaignRevision), loginSendId: record.sendId,
      loginTemplate: { subject: campaign.subject ?? '', body: campaign.body ?? '' },
      loginAllRecipientIds: Array.isArray(record.allIds) ? record.allIds : [...queuedIds, ...remaining],
      loginQueuedIds: queuedIds, loginRecipients: remaining, loginFailedIds: remaining, loginSkippedIds: skippedIds,
      loginTotal: Number(record.total) || 0, loginSentCount: queuedIds.length,
      loginProgress: progress, loginFinished: Boolean(record.finished),
    };
  } catch { return {}; }
}
async function searchReports(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const filters = { search: form.get('search'), status: form.get('status') }; state.update({ filters }); await loadPage('reports', filters); }
async function searchAudit(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const filters = { targetUserId: form.get('targetUserId'), action: form.get('action') }; state.update({ filters }); await loadPage('audit', filters); }
async function loadUser(id) { state.update({ busy: true, error: null }); try { state.update({ detail: await api.getUser(id), busy: false }); } catch (error) { handle(error); } }
async function verifyUserEmail() { const id = state.value.detail?.id; if (!id || !window.confirm(`Mark ${state.value.detail.email} as verified?`)) return; await mutate(async () => { state.update({ detail: await api.verifyUserEmail(id) }); }, 'Email marked verified.'); }
async function sendUserPasswordResetLink() { const user = state.value.detail; if (!user?.id || !user.email || !user.emailVerified || !window.confirm(`Send a password reset email to ${user.email}? Their current password stays active until they complete recovery.`)) return; await mutate(() => api.sendUserPasswordResetLink(user.id), 'Password reset email sent.'); }
async function sendUserLoginLink() { const user = state.value.detail; if (!user?.id || !window.confirm(`Send a one-time login link valid for 24 hours to ${user.email}?`)) return; await mutate(() => api.sendUserLoginLink(user.id), '24-hour login link queued.'); }
async function loadReport(id) { state.update({ busy: true, error: null, notes: null }); try { const report = await api.getReport(id); const notes = await api.listReportNotes(id); state.update({ detail: report, notes: notes?.items ?? [], busy: false }); } catch (error) { handle(error); } }
async function loadCampaign(id) { state.update({ busy: true, error: null, editor: null, loginCampaignStale: false, loginCampaignId: null, loginCampaignRevision: null, loginSendId: null, loginTemplate: null, loginAllRecipientIds: [], loginQueuedIds: [], loginRecipients: null, loginFailedIds: [], loginSkippedIds: [], loginProgress: null, loginFinished: false, loginSentCount: 0, loginTotal: null }); try { const campaign = await api.getCampaign(id); state.update({ detail: campaign, ...restoreLoginCampaignProgress(campaign), busy: false }); } catch (error) { handle(error); } }
async function updateReport(event) { event.preventDefault(); const form = new FormData(event.currentTarget); const id = state.value.detail.id; const status = event.submitter?.value; if (!['open', 'resolved', 'dismissed'].includes(status)) return; const update = reportUpdatePayload({ revision: state.value.detail.revision, status, note: form.get('note') }); await mutate(() => api.updateReport(id, update), 'Report saved.'); if (!state.value.error) await loadReport(id); }
async function addNote(event) { event.preventDefault(); const id = state.value.detail.id; const text = new FormData(event.currentTarget).get('text'); await mutate(() => api.addReportNote(id, text), 'Note added.'); if (!state.value.error) await loadReport(id); }
async function saveCampaign(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  const payload = campaignPayload(form);
  if (payload.channel === 'email' && payload.status === 'active') {
    const invalid = validateLoginTemplate({ subject: payload.subject ?? '', body: payload.body });
    if (invalid) { showTemplateError(event.currentTarget, invalid); return; }
  }
  if (state.value.editor === 'create') {
    await mutate(async () => { state.update({ detail: await api.createCampaign(payload), editor: null }); }, 'Campaign saved.');
    return;
  }
  const id = state.value.detail.id;
  await mutate(async () => { state.update({ detail: await api.updateCampaign(id, { ...payload, expectedRevision: Number(form.get('expectedRevision')) }) }); }, 'Campaign saved.');
}
function showTemplateError(form, text) {
  let error = form.querySelector('[data-template-error]');
  if (!error) {
    error = document.createElement('p');
    error.className = 'error';
    error.setAttribute('role', 'alert');
    error.dataset.templateError = 'true';
    form.prepend(error);
  }
  error.textContent = text;
}
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
function validateLoginTemplate(template) {
  const subject = template.subject?.trim() ?? '';
  const body = template.body?.trim() ?? '';
  if (!subject || !body) return 'Add both an email subject and message before activating this campaign.';
  if (new TextEncoder().encode(subject).length > 200 || new TextEncoder().encode(body).length > 10000) return 'Keep the subject within 200 UTF-8 bytes and the message within 10,000 UTF-8 bytes.';
  if ([...subject.matchAll(/{{\s*([a-z_]+)\s*}}/g)].some((match) => match[1] === 'login_link')) return 'Put {{login_link}} in the email message, not the subject.';
  const supported = new Set(loginTemplateVariables.map(({ name }) => name));
  const validateText = (text) => {
    const matches = [...text.matchAll(/{{\s*([a-z_]+)\s*}}/g)];
    const stripped = text.replace(/{{\s*[a-z_]+\s*}}/g, '');
    if (stripped.includes('{{') || stripped.includes('}}')) return false;
    return matches.every((match) => supported.has(match[1]));
  };
  if (!validateText(subject) || !validateText(body)) return 'Use only the listed variables, written with double braces, such as {{username}}.';
  if ([...subject.matchAll(/{{\s*([a-z_]+)\s*}}/g)].some((match) => ['username', 'email'].includes(match[1]))) return 'Use {{username}} and {{email}} in the message body. Subjects must stay within 200 bytes for every recipient.';
  if (![...body.matchAll(/{{\s*([a-z_]+)\s*}}/g)].some((match) => match[1] === 'login_link')) return 'Add {{login_link}} to the message so recipients can sign in.';
  if (loginTemplateWorstCaseBytes(subject) > 200 || loginTemplateWorstCaseBytes(body) > 10000 || loginTemplateWorstCaseBytes(body, true) > 20000) return 'Personalized email content could exceed the delivery size limits. Shorten the message or remove repeated variables.';
  return null;
}
function loginTemplateWorstCaseBytes(source, htmlMode = false) {
  const textBytes = (value) => new TextEncoder().encode(value).length;
  const htmlStaticBytes = (value) => textBytes(String(value).replace(/[&<>"']/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&#34;', "'": '&#39;' })[character]).replaceAll('\n', '<br>\n'));
  const maxima = { username: 1020, email: 320, login_link: 1536 + 7 + 43, expires_in: 9, app_name: 8 };
  const staticBytes = (value) => htmlMode ? htmlStaticBytes(value) : textBytes(value);
  let size = 0;
  let last = 0;
  for (const match of source.matchAll(/{{\s*([a-z_]+)\s*}}/g)) {
    size += staticBytes(source.slice(last, match.index));
    const maximum = maxima[match[1]] ?? 0;
    size += htmlMode ? (match[1] === 'login_link' ? 22 + maximum * 6 : maximum * 6) : maximum;
    last = match.index + match[0].length;
  }
  return size + staticBytes(source.slice(last));
}
function previewTemplate(value, username, email) {
  const sample = {
    username, email, app_name: 'Stick-It', expires_in: '24 hours',
    login_link: 'https://example.com/login?token=example',
  };
  return String(value ?? '').replace(/{{\s*([a-z_]+)\s*}}/g, (_, name) => sample[name] ?? `{{${name}}}`);
}
function updateTemplatePreview() {
  const form = root.querySelector('#campaign-editor');
  if (!form) return;
  const subject = form.querySelector('[data-campaign-template-field="subject"]')?.value ?? '';
  const body = form.querySelector('[data-campaign-template-field="body"]')?.value ?? '';
  const subjectNode = root.querySelector('[data-preview-subject]');
  const bodyNode = root.querySelector('[data-preview-body]');
  if (subjectNode) subjectNode.textContent = previewTemplate(subject, 'Alex', 'alex@example.com') || 'Email subject';
  if (bodyNode) bodyNode.textContent = previewTemplate(body, 'Alex', 'alex@example.com');
  updateSendButton();
}
function toggleCampaignFields(event) {
  const form = event.currentTarget.form;
  const selected = event.currentTarget.value;
  const archived = state.value.detail?.status === 'archived';
  form.querySelectorAll('[data-channel-fields]').forEach((section) => {
    const enabled = section.dataset.channelFields === selected;
    section.hidden = !enabled;
    section.querySelectorAll('input, textarea, select, button').forEach((control) => { control.disabled = archived || !enabled; });
  });
  updateTemplatePreview();
}
function updateSendButton() {
  const button = root.querySelector('[data-persisted-campaign-send]');
  const form = root.querySelector('#campaign-editor');
  const campaign = state.value.detail;
  if (!button || !form || !campaign) return;
  const current = campaignPayload(new FormData(form));
  const saved = {
    name: campaign.name, channel: campaign.channel, subject: campaign.subject ?? null,
    title: campaign.title ?? null, body: campaign.body, status: campaign.status,
  };
  button.disabled = state.value.busy || JSON.stringify(current) !== JSON.stringify(saved);
  button.title = button.disabled ? 'Save your campaign changes before sending.' : '';
}
function insertTemplateVariable(event) {
  const button = event.currentTarget;
  const form = root.querySelector('#campaign-editor');
  const input = form?.querySelector(`[data-campaign-template-field="${button.dataset.target}"]`);
  if (!input || input.disabled) return;
  const token = `{{${button.dataset.insertVariable}}}`;
  const start = input.selectionStart ?? input.value.length;
  const end = input.selectionEnd ?? start;
  input.setRangeText(token, start, end, 'end');
  input.focus();
  input.dispatchEvent(new Event('input', { bubbles: true }));
}
function optionalField(value) { return value === '' ? null : value; }
async function mutate(operation, notice) { state.update({ busy: true, error: null }); try { await operation(); state.update({ busy: false, notice }); } catch (error) { handle(error); } }
function handle(error) { if (error instanceof AdminHttpError && error.unauthorized) { state.update({ session: 'login', busy: true, error: 'Session expired. Preparing sign-in…' }); api.bootstrap().then(() => state.update({ busy: false, error: null })).catch((bootstrapError) => state.update({ session: 'error', busy: false, error: message(bootstrapError) })); } else if (error instanceof AdminHttpError && error.forbidden) state.update({ busy: false, error: 'You do not have permission for this operation.' }); else if (error instanceof AdminHttpError && error.status === 409) state.update({ busy: false, error: 'This record changed. Reload it and reapply your change.' }); else state.update({ busy: false, error: message(error) }); }
async function logout() { try { await api.logout(); } finally { state.update({ session: 'login', sessionData: null, loaded: false, busy: true, error: null }); try { await api.bootstrap(); state.update({ busy: false }); } catch (error) { state.update({ session: 'error', busy: false, error: message(error) }); } } }
function title(value) { return value[0].toUpperCase() + value.slice(1); }
function message(error) { return error instanceof Error ? error.message : 'The admin request could not be completed.'; }
function formatDate(value) { if (!value) return '—'; const date = new Date(value); return Number.isNaN(date.valueOf()) ? String(value) : date.toLocaleString(); }
function escape(value) { return String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char])); }
