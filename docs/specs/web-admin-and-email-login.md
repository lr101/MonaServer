# Web administration and email-link login specification

Status: proposed implementation specification; no feature implementation yet.
Baseline: `34e4cf1` on `develop`, including Flutter lifecycle refactor #509.
Companion: [distributed implementation plan](../plans/web-admin-and-email-login.md).

## Requested outcomes

1. A web admin interface displays submitted reports and supports review and resolution.
2. Administrators send emails and push notifications to selected users or all eligible users.
3. Administrators classify accounts as compromised, disable their passwords, remove refresh tokens, revoke existing access, and send password recovery emails.
4. Web users can sign in by entering only their email and following a one-time emailed link. Administrators can send these links individually or in campaigns.
5. Meaningful administrative operations work on explicit selections, all matching filters across pages, or all eligible accounts. Report operations select reports rather than accounts.

## Architecture and scope

Extend the existing Go server with versioned administrative endpoints and shared business services. PostgreSQL remains the source of truth; a durable PostgreSQL job queue supports bulk actions and delivery. A worker may initially run in the Go process, behind an owned start/stop lifecycle, with an optional separate worker command using the same services later. No second independently implemented database-writing admin server.

Keep Flutter, Riverpod, the generated Dart API, and one Flutter package as required by `flutter/ARCHITECTURE.md`. Add a separate admin entry point/build and feature modules within that package, served on an admin hostname. It has its own session and bootstrap, without starting consumer Drift, camera, Firebase, or sync. Public email-link login belongs in the existing consumer web app. Preserve Android password login, signup, and recovery compatibility.

The following are design defaults for implementation, rather than claims about existing behavior:

- Admin identity uses explicit stable user IDs and granular permissions. A dedicated password-plus-TOTP flow issues a short-lived opaque admin cookie session, separate from consumer JWT/refresh credentials. Email links never grant admin sessions. Bootstrap membership/enrollment via an operator-only local command; no public self-enrollment. Permission management UI and external identity-provider integration are later work.
- Initial admin cookie lifetime: 30-minute idle / 8-hour absolute; security and all-account actions require MFA verification within 5 minutes. Make limits configurable. Cookies are Secure, HttpOnly, host-only, with CSRF and Origin checks. Serve admin and API under HTTPS on the same site by default; explicit credentialed CORS is required when origins differ. Unrelated-site cookie deployment is not an implicit supported default.
- Consumer login tokens: 32 random bytes, hash at rest, 15-minute lifetime. Recovery tokens: 10-minute lifetime. Never expose raw tokens in admin APIs, previews, audit events, application/proxy logs, or campaign tracking. Authentication email HTML is server-owned.
- Email lookup trims surrounding whitespace and compares case-insensitively, without provider-specific dot/plus rewriting. Exactly one active account with a verified matching email is eligible. A canonical-email claim table provides atomic ownership: backfill unique verified accounts as owned and duplicate groups as blocked/ambiguous, without a unique constraint on existing users' email values. Confirmation/change/deletion must acquire, release or reconcile that claim transactionally; concurrent verification cannot create a second owner. Ambiguous, absent, unverified, deleted, or restricted accounts receive the same public response and no login token. Do not merge accounts, rewrite existing addresses, or add a failing uniqueness migration. Add an admin ambiguity indicator and retain password login/manual support for affected users. Recheck ownership and email binding at token redemption and after email changes.
- Public login links do not create accounts. Compromised accounts must use recovery. Missing or suspected compromised email requires manual identity recovery; an admin cannot override a recovery destination through the bulk form.
- New broadcasts require an explicit audience; an empty selection is an error. Existing v2 admin DTOs/statuses/send semantics remain compatibility adapters, but their authorization intentionally migrates to the same stable-membership, MFA cookie and capability gate as v3. Username equality and ordinary Bearer tokens no longer authorize admin actions. Enroll operators before enabling that gate; document this deliberate legacy admin-client authentication change. Consumer/mobile API authentication remains supported.
- Notifications mean push in this scope. A persistent in-app inbox and general segmentation engine are deferred. Multiple registered device tokens and explicit opt-out are included so targeted sends can reach supported devices; legacy single-token registrations remain supported.
- No historical report inbox import, scheduled marketing automation, new analytics, production sending, deployment, or PR creation is authorized by this planning task.

## User flows and invariants

### Email-only login

Email entry returns a generic accepted response regardless of eligibility. Enforce per-IP, per-address and global delivery limits through shared atomic PostgreSQL quotas so multiple API instances/restarts cannot bypass them. Use keyed HMAC identifiers with a configured rotation policy; an unkeyed email hash is not adequate privacy protection. Initial configurable defaults: address 3 requests/15 minutes and 10/day, IP 20/15 minutes, public authentication delivery 100/minute globally. Apply quotas to eligible and ineligible requests alike. Address-specific suppression keeps the generic accepted response; IP/global throttles may return identical 429/Retry-After responses independent of membership. Validate trusted proxy configuration before using forwarded client addresses. An infrastructure-wide outage may return a generic unavailable response consistently.

Use a fixed consumer-web callback such as `https://consumer.example/#/email-login/callback?token=<opaque>`, with the token inside the single browser fragment route (compatible with Flutter's hash router). Opening a URL or previewing an email must not redeem it. A web launch adapter captures the token in memory before full consumer bootstrap, removes it from browser history/address state, and hands one-shot launch data to the callback, which presents an explicit Sign in button. No third-party content, tracking, or referrer leakage on this page. A reload after URL removal may require requesting a fresh link; explain this state. Only a POST exchanges the token for the existing token-pair shape plus canonical username. Redirect targets are server-selected or strictly allowlisted internal paths.

Redemption locks the account and token, checks purpose, expiry, email binding, eligibility and revocation, consumes exactly once, and creates the refresh credential transactionally. An ambiguous network outcome may require a fresh email; never replay a consumed token to disclose its prior credentials. Same-account reauthentication preserves drafts; switching accounts requires explicit confirmation and existing cleanup. No credential write, sync, or navigation can escape a stale Flutter account generation.

Public request tokens are capped/rate-limited; requesting a new link does not invalidate an already mailed valid link and allow nuisance lockout. Successful redemption invalidates other outstanding login links for that account. Recovery, compromise, email changes, and deletion invalidate relevant action tokens. Admin campaign retry reuses the same still-valid delivery attempt token rather than minting uncontrolled parallel credentials.

### Compromise and recovery

For each account, one transaction locks the user, records the incident/reason/actor, disables the password, sets `password_reset_required`, advances the authentication generation, removes refresh credentials and outstanding action tokens/codes, revokes any admin sessions, and queues recovery delivery. A failure to deliver never rolls back containment. No trusted destination yields `secured_manual_recovery_required`, not a failed containment operation.

All JWT-bearing application routes check current security state/generation. Login, refresh, password change, email change, token redemption and compromise use the same user-lock order and generation rules. Requests authorized before containment can already be in flight; fence sensitive writes inside transactions. Do not claim cancellation of all previously started network work.

Recovery uses a restricted action-token endpoint, never a normal access token created by a GET page. Submit a new password, atomically consume the token, revoke old credentials again, clear the restriction, reset failed-login counters, invalidate sibling tokens, and require fresh login. Keep incident history after recovery. Pending deletion/email-confirmation links must not bypass containment. Audit legacy HTML account-action flows as part of this change.

### Admin audiences and jobs

An audience is a discriminated union: selected IDs, validated filter, or all. Filters initially cover username/email/ID search, verified-email presence, security status and creation date. Resolve account IDs into an immutable server-side snapshot, with stable pagination and explicit exclusions. Bind preview to actor, action, payload hash and expiry. Commit executes that exact snapshot; never rerun a filter silently. Recheck permission and recipient safety/opt-outs at execution, which may only shrink eligibility.

The confirmation UI states the scope and count, including admin targets. All-account and security operations require recent MFA and a reason where applicable. Default security previews exclude admin identities; explicit inclusion requires a stronger permission and separate acknowledgement. If an actor revokes their own authority, pause the remaining job for another authorized administrator.

Per-recipient transactions are atomic; a bulk operation is not one huge transaction. Jobs expose pending, running, completed, completed-with-errors, paused and cancelled states; recipient outcomes distinguish skipped, secured, queued, provider-accepted, failed and unknown-delivery. Counts distinguish account audience size, eligible recipients and device deliveries. Retry only eligible failed work; cancel stops pending work and cannot unsend mail or restore credentials. Expired leases recover after restart, and stale workers cannot acknowledge another worker's lease.

SMTP/FCM do not offer database-transactional exactly-once delivery. Record provider-accepted separately from delivery; an uncertain SMTP acceptance may cause a duplicate on retry. Keep duplicate attempts bounded and expose uncertainty. Security transitions remain idempotent even if email delivery is uncertain.

## Acceptance matrix

| Feature | One / selected | Filter / all | Required evidence |
| --- | --- | --- | --- |
| Reports | Detail, note, assign, resolve/dismiss | Selected/all matching reports | Persist without SMTP; authenticated reporter; concurrency-safe state changes |
| Email | Template preview and test send | Frozen recipient snapshot | No accidental empty broadcast; opt-out/eligibility; retry and failure counts |
| Sign-in links | Public request or admin send | Individual links per eligible recipient | Single-use POST; scanner-safe GET; replay/race/expiry; no admin escalation |
| Push | Registered devices per user | All opted-in eligible devices | No-op configuration shown unavailable; partial provider failures and invalid-token cleanup |
| Session revocation | One/selected accounts | Filter/all accounts | Access and refresh rejection, including same-second and concurrent issuance |
| Compromise | Contain and queue recovery | Filter/all accounts | Atomic containment, idempotent retry, recovery failure remains contained |
| Recovery resend | Trusted destination only | Eligible restricted accounts | No ordinary login token; expiry and purpose enforcement |
| Audit | Actor/target/reason/outcome | Paginated and filtered history | No secrets; permissions; bounded retention and account deletion policy |

## Rollout requirements

Feature flags independently control admin UI/API and public email login; workers remain able to finish authorized queued work when UI is disabled unless explicitly paused. New schema is additive and forward-only. JWTs gain an optional generation claim: existing no-generation tokens are treated as generation zero only while the user's generation is zero. New server versions must be deployed everywhere before generation-based containment is enabled; old binaries cannot enforce revocation. Do not roll back to an old binary while relying on containment.

Default proposed retention: expired action tokens/encrypted delivery secrets purged within 24 hours, recipient delivery details 30 days, campaign summaries/audit/report history 180 days. Configure and document the final retention policy before production; delete or anonymize personal data consistently with account deletion, retaining only justified non-secret operational records. Routine re-engagement respects communication preferences; security recovery is a separate transactional email category. No new production performance or delivery claim without recorded evidence.
