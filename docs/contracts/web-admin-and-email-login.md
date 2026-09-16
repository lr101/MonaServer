# Web admin and email-login contract catalog

Status: frozen T01 interface catalog. The behavioral authority is
[`docs/specs/web-admin-and-email-login.md`](../specs/web-admin-and-email-login.md)
and the wire authority is [`api/openapi.yaml`](../../api/openapi.yaml).
The new routes below are versioned under `/api/v3`, are independently gated,
and are unavailable until their feature flag and implementation are enabled.
They must never return a successful placeholder mutation while unavailable.

## Shared rules

- `public_email_login` gates the three public email/recovery operations and
  own-session revoke. `web_admin_api` gates the admin API. The workers may
  finish an already-authorized durable job while the UI/API is disabled unless
  an operator explicitly pauses that job.
- Cursor pages use an opaque `cursor` and `limit`; the default is **25**, the
  maximum is **100**, and a response's `nextCursor` is absent/null at the end.
  A client must not rerun a filter when following a snapshot cursor.
- New error bodies use `apiErrorDto`: bounded `code`, human-safe `message`, and
  optional non-negative `retryAfterSeconds`. A `429` also carries an integer
  `Retry-After` header. Error text and metadata never contain passwords, raw
  action tokens, refresh credentials, provider secrets, or arbitrary campaign
  HTML.
- `400` means malformed input or an invalid/expired purpose-bound token;
  `401` means missing, expired, revoked, or invalid authentication;
  `403` means an authenticated identity lacks the capability or recent MFA;
  `404` means the resource is absent or not visible; `409` means a stale
  revision, snapshot/payload mismatch, duplicate command, or idempotency-key
  conflict; `429` means a shared limit; `503` means the gated feature or a
  required local provider is unavailable. Membership eligibility must not be
  disclosed through public email responses or address-specific errors.
- Mutating admin requests require `X-CSRF-Token`. Job creation, retry, and
  cancellation additionally require `Idempotency-Key`; reusing a key with a
  different request body returns `409`.
- New admin responses contain an opaque browser session and capabilities, not
  consumer JWTs or refresh credentials. The explicit Bearer-authenticated
  own-session revoke endpoint verifies refresh-token ownership and revokes only
  that credential; it is idempotent `204`.

## Session and CSRF lifecycle

The admin browser first calls `POST /api/v3/admin/session/bootstrap`. The
server creates or refreshes a pre-authentication session, sets a host-only
`Secure; HttpOnly` `admin_session` cookie, and returns a CSRF value bound to
that session/challenge. The browser sends that value as `X-CSRF-Token` on
login, MFA, reauthentication, logout, and every admin mutation. The server
checks the double-submit value and `Origin` before changing state.

The password step returns `mfa_required` and a one-use `challengeId`; it never
creates a consumer JWT. Successful MFA rotates the CSRF value and returns an
`authenticated` session. Reauthentication for a sensitive action also rotates
the CSRF value and refreshes `recentMfaAt`. `GET /api/v3/admin/session`
restores the authenticated session after a reload. Logout revokes the opaque
session and clears the cookie. Idle lifetime is 30 minutes, absolute lifetime
is 8 hours, and recent MFA is valid for 5 minutes; deployments may configure
these bounds without changing the wire shape.

An expired/revoked admin or consumer credential always maps to `401` on the
new path so Flutter can expire its local session. Consumer v2 login, signup,
password recovery, and other existing API response contracts remain unchanged.

## Endpoint catalog

| Operation | Method and path | Authentication | Success response |
| --- | --- | --- | --- |
| `requestEmailLink` | `POST /api/v3/public/auth/email-link/request` | Public | `202 emailLinkRequestAcceptedDto` |
| `exchangeEmailLink` | `POST /api/v3/public/auth/email-link/exchange` | Public | `200 emailLinkExchangeResponseDto` |
| `completeRecovery` | `POST /api/v3/public/auth/recovery/complete` | Public action token in body | `204` |
| `revokeOwnSession` | `POST /api/v3/auth/session/revoke` | `Authorization: Bearer` plus owned refresh token body | `204` |
| `bootstrapAdminSession` | `POST /api/v3/admin/session/bootstrap` | Public browser bootstrap | `200 adminSessionBootstrapDto` |
| `adminSessionLogin` | `POST /api/v3/admin/session/login` | Pre-auth admin cookie + CSRF | `202 adminSessionLoginResponseDto` |
| `completeAdminSessionMfa` | `POST /api/v3/admin/session/mfa` | Admin cookie + CSRF | `200 adminSessionDto` |
| `reauthenticateAdminSession` | `POST /api/v3/admin/session/reauthenticate` | Admin cookie + CSRF | `200 adminSessionDto` |
| `logoutAdminSession` | `POST /api/v3/admin/session/logout` | Admin cookie + CSRF | `204` |
| `getAdminSession` | `GET /api/v3/admin/session` | Authenticated admin cookie | `200 adminSessionDto` |
| `listAdminUsers` / `getAdminUser` | `GET /api/v3/admin/users[/{userId}]` | Authenticated admin cookie | `200 adminUserPageDto` / `200 adminUserDetailsDto` |
| `previewAdminAudience` / `getAdminAudience` | `POST /api/v3/admin/audiences/preview`, `GET /api/v3/admin/audiences/{audienceId}` | Admin cookie; CSRF on preview | `200/202` preview / `200 adminAudiencePageDto` |
| `listAdminJobs` / `createAdminJob` | `GET/POST /api/v3/admin/jobs` | Admin cookie; CSRF + idempotency on create | `200 adminJobPageDto` / `202 adminJobAcceptedDto` |
| `getAdminJob` / `listAdminJobRecipients` | `GET /api/v3/admin/jobs/{jobId}` / `GET /api/v3/admin/jobs/{jobId}/recipients` | Authenticated admin cookie | `200 adminJobDto` / `200 adminJobRecipientPageDto` |
| `retryAdminJob` / `cancelAdminJob` | `POST /api/v3/admin/jobs/{jobId}/{retry,cancel}` | Admin cookie + CSRF + idempotency | `202 adminJobAcceptedDto` |
| `sendAdminTestMessage` | `POST /api/v3/admin/messages/test` | Admin cookie + CSRF | `202 adminTestMessageAcceptedDto` |
| `listAdminReports` / `getAdminReport` | `GET /api/v3/admin/reports[/{reportId}]` | Authenticated admin cookie | `200 adminReportPageDto` / `200 adminReportDto` |
| `updateAdminReport` | `PATCH /api/v3/admin/reports/{reportId}` | Admin cookie + CSRF | `200 adminReportDto` |
| `listAdminReportNotes` | `GET /api/v3/admin/reports/{reportId}/notes` | Authenticated admin cookie | `200 adminReportNotePageDto` (newest first, cursor-paginated) |
| `addAdminReportNote` | `POST /api/v3/admin/reports/{reportId}/notes` | Admin cookie + CSRF | `201 adminReportNoteDto` |
| `listAdminAudit` | `GET /api/v3/admin/audit` | Authenticated admin cookie | `200 adminAuditPageDto` |

All admin reads return `401` or `403` as appropriate; resource reads also
return `404` when the resource is absent or hidden. Admin writes use the
operation-specific `400/401/403/404/409/429/503` set in the OpenAPI document.
Public request and exchange use `400/429/503`; restricted recovery uses
`400/409/503`; own-session revoke uses `400/401`.

## Capability matrix

The browser session is the only admin principal. T05 maps these stable
capability strings to memberships; the API must check them again for every
request and every job item.

| Capability | Operations or action kinds | Additional gate |
| --- | --- | --- |
| `users.read` | User search and detail | Authenticated admin session |
| `audience.preview` / `audience.read` | Preview and snapshot reads | Actor-bound snapshot for reads |
| `jobs.read` / `jobs.create` / `jobs.control` | Job list/detail/recipients, commit, retry/cancel | Snapshot and payload hash; idempotency on commands |
| `messages.test` | Explicit test delivery | One named recipient; CSRF |
| `reports.read` / `reports.review` | Report list/detail, notes, assignment and transitions | Revision check for updates |
| `audit.read` | Audit history | Permission-filtered results |
| `campaign.email` / `campaign.push` / `campaign.login_link` | Corresponding action payloads | Explicit audience, eligibility and opt-out checks |
| `security.revoke` / `security.compromise` / `security.recovery_resend` | Session revocation, compromise containment, recovery resend | Recent MFA (5 minutes); reason for security actions |
| `reports.resolve` / `reports.dismiss` | Bulk report action variants | Report audience only; recent MFA for bulk actions |
| `audience.include_admins` | Include admin identities in an account audience | Stronger membership and separate acknowledgement |

Bootstrap, password challenge, MFA completion, reauthentication, and logout
require the appropriate session state and CSRF/Origin checks; they do not
grant capabilities by themselves. A missing capability is `403`, while an
expired or revoked session is `401`.

## Generated service contracts

The generated Go server preserves one typed servicer boundary per tag. Each
method accepts `context.Context`, its typed path/header/query/request DTOs,
and returns `(genserver.ImplResponse, error)`; the generated controllers own
JSON parsing and bounded parameter binding. The frozen groups are:

| Interface | Methods |
| --- | --- |
| `PublicAuthAPIServicer` | `RequestEmailLink`, `ExchangeEmailLink`, `CompleteRecovery` |
| `SessionAuthAPIServicer` | `RevokeOwnSession` |
| `AdminSessionAPIServicer` | `BootstrapAdminSession`, `AdminSessionLogin`, `CompleteAdminSessionMfa`, `ReauthenticateAdminSession`, `LogoutAdminSession`, `GetAdminSession` |
| `AdminUsersAPIServicer` | `ListAdminUsers`, `GetAdminUser` |
| `AdminAudiencesAPIServicer` | `PreviewAdminAudience`, `GetAdminAudience` |
| `AdminJobsAPIServicer` | `ListAdminJobs`, `CreateAdminJob`, `GetAdminJob`, `ListAdminJobRecipients`, `RetryAdminJob`, `CancelAdminJob` |
| `AdminMessagesAPIServicer` | `SendAdminTestMessage` |
| `AdminReportsAPIServicer` | `ListAdminReports`, `GetAdminReport`, `UpdateAdminReport`, `ListAdminReportNotes`, `AddAdminReportNote` |
| `AdminAuditAPIServicer` | `ListAdminAudit` |

These interfaces are additive to the existing v2 generated contracts. The
pre-rollout adapter implements every v3 method with `503 feature_unavailable`
and is covered by a focused controller test; no v3 router is registered until
the session/capability gate and a real implementation are available.

The generated client method `previewAdminAudience` returns the typed
`AdminAudiencePreviewResponseDto` for both `200` (ready) and `202` (pending).
Both statuses require `snapshotId` and `status`; a pending response carries a
`jobId`, while a ready response carries the actor, action, resource, payload
hash, expiry, counts, and exclusions. The conditional fields are nullable in
the common DTO so a client can branch on `status` without decoding a successful
response through an unrelated placeholder type.

## DTOs, unions, and enums

`adminActionKind` is the closed union:
`email`, `login_link`, `push`, `revoke_sessions`, `mark_compromised`,
`recovery_resend`, `report_resolve`, and `report_dismiss`. Each action carries
only its bounded payload. Email body is 1..10,000 characters, optional
sanitized HTML is at most 20,000, and subject is 1..200. Push title is 1..200
and body is 1..2,000. Security/report reasons and notes are bounded by their
DTOs. The server sanitizes/validates content and never evaluates HTML in the
admin browser.

`adminAudience` is a discriminated union on `kind`:

- `selected`: 1..10,000 explicit UUIDs and `resource` `accounts` or `reports`;
- `filter`: a resource-tagged server-evaluated filter whose nested `resource`
  must equal the audience resource. Account filters use `adminUserFilterDto`;
  report filters use `adminReportFilterDto`;
- `all`: all eligible records of the declared `accounts` or `reports` resource.

Report filters support `statuses`, `types`, `createdAfter`, `createdBefore`,
and `assigneeUserId`, matching the report list's review dimensions while
keeping the existing list `status` and `search` query parameters compatible.
A report filter is evaluated against reports only; account criteria are
rejected rather than applied to the report resource. The preview snapshot
stores the exact resource and criteria, and following or committing it never
reruns a local client filter.

An empty selection is invalid. A filter or `all` request is resolved once into
an immutable snapshot. Preview binds the actor, action, payload hash, and
expiry. Commit accepts only that snapshot and hash; execution rechecks
permissions, account state, communication preferences, and device eligibility
and may only reduce the recipient set. Counts distinguish account audience,
eligible recipients, and device deliveries. Explicit admin inclusion requires
the stronger capability and acknowledgement; security actions require a
recent MFA and a reason.

`adminSecurityState` is `normal`, `password_disabled`, `compromised`,
`secured_manual_recovery_required`, or `deleted`. `adminJobStatus` is `pending`,
`running`, `completed`, `completed_with_errors`, `paused`, or `cancelled`.
Recipient outcomes are `skipped`, `secured`, `queued`, `provider_accepted`,
`failed`, and `unknown_delivery`. Reports use `open`, `resolved`, or
`dismissed`. Report updates carry `expectedRevision`; stale revisions return
`409`. A deleted report target stays reviewable through its retained target
identifier/name and `deleted` marker.
In a report update, omitting `assigneeUserId` preserves the current assignment,
`null` clears it, and a UUID assigns that user. The separate report-note
history endpoint returns newest-first cursor pages so detail views can remain
bounded without hiding older notes.

The account summary intentionally omits passwords, password hashes, action
tokens, refresh credentials, provider tokens, and delivery payloads. Audit
events expose bounded actor/target/action/reason/outcome metadata only.

The Go server templates for these canonical unions live in
`go-server/generator-templates/`; `make gen-server` verifies the pinned
OpenAPI Generator 7.19.0 SHA-256 before generation. Dart uses the analogous
`flutter/generator-templates/` source with OpenAPI Generator 7.9.0. Generated
model and API tests are disabled by source-controlled generator properties;
the v2 compatibility fixtures and the canonical v3 union/preview fixtures live
in `flutter/test/web_admin_contract_test.dart`.

## Transaction and delivery ports

Security containment is one caller-owned database transaction: lock the
account, write the incident, disable the password, set
`passwordResetRequired`, advance the authentication generation, remove old
refresh/action credentials, revoke admin sessions, then call the following
port with the transaction-scoped `*db.Queries`:

```go
type RecoveryEnqueueRequest struct {
    AccountID      uuid.UUID
    ActorID        *uuid.UUID
    AuthGeneration int64
    Reason         RecoveryReason
    VerifiedEmail  *string // canonical, already verified; nil => manual recovery
}

type RecoveryEnqueueResult struct {
    AttemptID *uuid.UUID
    Status    RecoveryEnqueueStatus // queued | manual_recovery_required
}

type RecoveryEnqueuer interface {
    EnqueueRecovery(context.Context, *db.Queries, RecoveryEnqueueRequest) (RecoveryEnqueueResult, error)
}
```

The concrete definitions live in
`go-server/internal/service/recovery_queue.go`. T03 owns security decisions
and the test double; T04 owns the durable adapter. The adapter uses the
provided transaction directly and never opens a second transaction or calls a
provider in it. A missing trusted address returns
`manual_recovery_required`; provider outage is unavailable/failed delivery and
never rolls back containment. Action-token rows retain hashes only. A short
lived encrypted delivery payload uses a separate key ID, is never exposed by
admin DTOs, and is purged after acceptance or expiry.

## Flow examples

The values below are fixtures, not credentials. The opaque strings are
deliberately nonfunctional and must be kept out of URLs, logs, and rendered
admin data.

### Public email login and recovery

Requesting an email link has one membership-independent response, including
for absent, unverified, duplicate, deleted, or restricted addresses:

```json
POST /api/v3/public/auth/email-link/request
{"email":" person@example.com "}

202
{"accepted":true}
```

Only POST redeems a link. A successful exchange returns the existing consumer
token-pair shape plus the authoritative username and consumes the token once:

```json
POST /api/v3/public/auth/email-link/exchange
{"token":"opaque-token-kept-out-of-logs"}

200
{
  "tokens": {
    "accessToken":"access-token",
    "refreshToken":"046b6c7f-0b8a-43b9-b35d-6489e6daee91",
    "userId":"046b6c7f-0b8a-43b9-b35d-6489e6daee91"
  },
  "username":"alice"
}
```

Invalid, expired, replayed, mismatched, or restricted tokens return the same
bounded `400` shape. Recovery is purpose-limited, consumes the token
atomically, clears the restriction, invalidates sibling capabilities, and
requires a fresh login; it does not return a JWT:

```json
POST /api/v3/public/auth/recovery/complete
{"token":"opaque-recovery-token","password":"a-new-password"}

204
```

The own-session endpoint requires explicit Bearer authentication and a refresh
credential owned by that identity. It does not use the ambient admin cookie
and cannot revoke another account:

```json
POST /api/v3/auth/session/revoke
Authorization: Bearer access-token
{"refreshToken":"046b6c7f-0b8a-43b9-b35d-6489e6daee91"}

204
```

### Admin bootstrap, login, MFA, reload, and logout

```json
POST /api/v3/admin/session/bootstrap

200
{
  "csrfToken":"csrf-bootstrap-value",
  "expiresAt":"2026-09-14T12:30:00Z",
  "sessionState":"pre_authentication"
}
```

The server also sets the host-only `admin_session` cookie. The password step
binds the one-use challenge to that session and returns no consumer token:

```json
POST /api/v3/admin/session/login
X-CSRF-Token: csrf-bootstrap-value
{"username":"operator","password":"password-kept-out-of-logs"}

202
{
  "challengeId":"046b6c7f-0b8a-43b9-b35d-6489e6daee91",
  "csrfToken":"csrf-login-value",
  "expiresAt":"2026-09-14T12:05:00Z",
  "sessionState":"mfa_required"
}
```

MFA rotates the CSRF value and returns capabilities. A reload uses the GET
operation to restore this same opaque session:

```json
POST /api/v3/admin/session/mfa
X-CSRF-Token: csrf-login-value
{"challengeId":"046b6c7f-0b8a-43b9-b35d-6489e6daee91","code":"123456"}

200
{
  "authenticatedAt":"2026-09-14T04:00:00Z",
  "capabilities":["users.read","security.revoke"],
  "csrfToken":"csrf-authenticated-value",
  "idleExpiresAt":"2026-09-14T04:30:00Z",
  "lastActivityAt":"2026-09-14T04:10:00Z",
  "permissions":["users.read"],
  "recentMfaAt":"2026-09-14T04:10:00Z",
  "sessionId":"046b6c7f-0b8a-43b9-b35d-6489e6daee91",
  "sessionState":"authenticated",
  "userId":"046b6c7f-0b8a-43b9-b35d-6489e6daee91",
  "username":"operator"
}
```

`POST /api/v3/admin/session/reauthenticate` has the same response shape and
rotates CSRF for an action such as `mark_compromised`; `POST .../logout` with
the current CSRF returns `204` and clears the cookie. Expiry, revocation, or a
missing capability maps to `401`/`403`, allowing the UI to clear or restrict
its local state.

### Users, audiences, and previews

A user page is bounded and contains safe account state only:

```json
GET /api/v3/admin/users?limit=25

200
{
  "items":[{
    "id":"046b6c7f-0b8a-43b9-b35d-6489e6daee91",
    "username":"alice",
    "email":"person@example.com",
    "emailVerified":true,
    "createdAt":"2026-01-10T12:00:00Z",
    "securityState":"normal",
    "authGeneration":2,
    "passwordDisabled":false,
    "passwordResetRequired":false,
    "isAdmin":false,
    "eligibilityReasons":[]
  }],
  "nextCursor":"next-cursor"
}
```

The three valid audience forms are explicit and mutually exclusive:

```json
{"kind":"selected","resource":"accounts","ids":["046b6c7f-0b8a-43b9-b35d-6489e6daee91"]}
{"kind":"filter","resource":"accounts","filter":{"resource":"accounts","verifiedEmail":true,"includeAdmins":false,"securityStatuses":["normal"]}}
{"kind":"filter","resource":"reports","filter":{"resource":"reports","statuses":["open"],"types":["abuse"],"createdAfter":"2026-01-01T00:00:00Z","createdBefore":"2026-09-01T00:00:00Z","assigneeUserId":"246b6c7f-0b8a-43b9-b35d-6489e6daee93"}}
{"kind":"all","resource":"accounts"}
```

The nested filter resource tag must match the outer audience resource. Report
audience filters support status, type, date-range, and assignee criteria; the
server rejects an account filter sent for a report audience instead of
silently applying account rules. A ready preview binds the exact action and
payload hash:

```json
POST /api/v3/admin/audiences/preview
X-CSRF-Token: csrf-authenticated-value
{
  "audience":{"kind":"selected","resource":"accounts","ids":["046b6c7f-0b8a-43b9-b35d-6489e6daee91"]},
  "action":{"action":"login_link"}
}

200
{
  "snapshotId":"046b6c7f-0b8a-43b9-b35d-6489e6daee91",
  "actorUserId":"146b6c7f-0b8a-43b9-b35d-6489e6daee91",
  "resource":"accounts",
  "action":{"action":"login_link"},
  "payloadHash":"sha256-payload-hash",
  "status":"ready",
  "expiresAt":"2026-09-14T04:15:00Z",
  "counts":{"accountAudienceCount":1,"eligibleRecipientCount":1,"deviceDeliveryCount":0,"excludedCount":0},
  "exclusions":[]
}
```

Large materialization returns `202` with `{ "jobId", "snapshotId",
"status":"pending" }`, and the generated Flutter convenience method
deserializes that response through the same `AdminAudiencePreviewResponseDto`
used for a ready `200`. A snapshot page retains exclusions and stable members
rather than rerunning the filter:

```json
{
  "snapshotId":"046b6c7f-0b8a-43b9-b35d-6489e6daee91",
  "status":"ready",
  "expiresAt":"2026-09-14T04:15:00Z",
  "counts":{"accountAudienceCount":2,"eligibleRecipientCount":1,"deviceDeliveryCount":2,"excludedCount":1},
  "items":[{"id":"046b6c7f-0b8a-43b9-b35d-6489e6daee91","resource":"accounts","eligible":true}],
  "exclusions":[{"id":"246b6c7f-0b8a-43b9-b35d-6489e6daee91","resource":"accounts","reason":"password_disabled"}],
  "nextCursor":null
}
```

### Jobs, actions, delivery outcomes, and test messages

Commit references the preview snapshot, repeats the exact action and payload
hash, and requires an idempotency key:

```json
POST /api/v3/admin/jobs
X-CSRF-Token: csrf-authenticated-value
Idempotency-Key: campaign-20260914-01
{
  "snapshotId":"046b6c7f-0b8a-43b9-b35d-6489e6daee91",
  "payloadHash":"sha256-payload-hash",
  "action":{"action":"email","subject":"Account notice","body":"Please review your account."}
}

202
{"jobId":"346b6c7f-0b8a-43b9-b35d-6489e6daee91","status":"pending"}
```

The job lifecycle is `pending` → `running` → `completed` or
`completed_with_errors`; an operator may observe `paused` or `cancelled`.
Recipient pages expose safe counts and can contain each outcome vocabulary:

```json
{
  "items":[
    {"accountId":"046b6c7f-0b8a-43b9-b35d-6489e6daee91","attemptCount":1,"deviceCount":0,"outcome":"skipped","reason":"communication_opt_out"},
    {"accountId":"146b6c7f-0b8a-43b9-b35d-6489e6daee91","attemptCount":0,"deviceCount":0,"outcome":"secured","reason":"contained_without_delivery"},
    {"accountId":"246b6c7f-0b8a-43b9-b35d-6489e6daee91","attemptCount":1,"deviceCount":0,"outcome":"queued"},
    {"accountId":"346b6c7f-0b8a-43b9-b35d-6489e6daee91","attemptCount":1,"deviceCount":2,"outcome":"provider_accepted"},
    {"accountId":"446b6c7f-0b8a-43b9-b35d-6489e6daee91","attemptCount":2,"deviceCount":1,"outcome":"failed","reason":"provider_unavailable"},
    {"accountId":"546b6c7f-0b8a-43b9-b35d-6489e6daee91","attemptCount":2,"deviceCount":1,"outcome":"unknown_delivery","reason":"ack_timeout"}
  ],
  "nextCursor":null
}
```

Retry acts only on eligible failed work and cancellation stops pending work;
neither action unsends mail or restores credentials. Test delivery names one
`recipientUserId` and returns `accepted:true` plus an optional job ID. It never
returns an action token or sends to an implicit audience:

```json
POST /api/v3/admin/messages/test
X-CSRF-Token: csrf-authenticated-value
{"recipientUserId":"046b6c7f-0b8a-43b9-b35d-6489e6daee91","action":{"action":"push","title":"Test","body":"A test notification."}}

202
{"accepted":true,"jobId":"346b6c7f-0b8a-43b9-b35d-6489e6daee91"}
```

### Reports and audit

Report details retain the authenticated reporter, bounded original text,
revision, notes, and a separate deletion-safe target:

```json
{
  "id":"646b6c7f-0b8a-43b9-b35d-6489e6daee91",
  "reporterUserId":"046b6c7f-0b8a-43b9-b35d-6489e6daee91",
  "reporterUsername":"alice",
  "text":"The submitted report text remains intact.",
  "legacyMessage":"optional legacy message",
  "target":{"userId":"746b6c7f-0b8a-43b9-b35d-6489e6daee91","username":"bob","deleted":false},
  "status":"open",
  "revision":3,
  "assigneeUserId":null,
  "notes":[],
  "createdAt":"2026-09-14T03:00:00Z",
  "updatedAt":"2026-09-14T04:00:00Z"
}
```

```json
PATCH /api/v3/admin/reports/646b6c7f-0b8a-43b9-b35d-6489e6daee91
X-CSRF-Token: csrf-authenticated-value
{"expectedRevision":3,"status":"resolved","note":"Reviewed and resolved."}

200
{"status":"resolved","revision":4,"notes":[{"id":"846b6c7f-0b8a-43b9-b35d-6489e6daee91","actorUserId":"146b6c7f-0b8a-43b9-b35d-6489e6daee91","text":"Reviewed and resolved.","createdAt":"2026-09-14T04:01:00Z"}]}
```

An audit page is append-only, permission-filtered, and secret-free:

```json
{
  "items":[{
    "id":"946b6c7f-0b8a-43b9-b35d-6489e6daee91",
    "actorUserId":"146b6c7f-0b8a-43b9-b35d-6489e6daee91",
    "targetUserId":"046b6c7f-0b8a-43b9-b35d-6489e6daee91",
    "action":"mark_compromised",
    "outcome":"secured_manual_recovery_required",
    "reason":"user reported takeover",
    "details":{"generation":"3","delivery":"manual_recovery_required"},
    "occurredAt":"2026-09-14T04:02:00Z"
  }],
  "nextCursor":null
}
```

## Flutter mock-domain fixtures

The generated Dart API is a transport boundary. Flutter presentation code
should map it into small pure domain states and can use these fixtures without
importing generated DTOs or repository implementations:

```dart
sealed class EmailLoginState {
  const EmailLoginState();
}

final class EmailEntry extends EmailLoginState {
  const EmailEntry();
}

final class LinkSent extends EmailLoginState {
  const LinkSent({required this.email});
  final String email;
}

final class LinkReadyForConfirmation extends EmailLoginState {
  const LinkReadyForConfirmation({required this.opaqueToken});
  final String opaqueToken; // memory only; never log or render
}

final class SignedIn extends EmailLoginState {
  const SignedIn({required this.userId, required this.username});
  final String userId;
  final String username;
}

final class RecoveryRequired extends EmailLoginState {
  const RecoveryRequired({required this.reason});
  final String reason;
}
```

Admin mock screens can use the same transport-independent states:

```dart
enum AdminSessionState { preAuthentication, mfaRequired, authenticated }
enum AdminJobState { pending, running, completed, completedWithErrors, paused, cancelled }
enum RecipientOutcome { skipped, secured, queued, providerAccepted, failed, unknownDelivery }
```

The callback adapter captures a fragment token before router/bootstrap work,
removes it from browser history/address state, and presents an explicit POST
confirmation. It must support signed-out, expired, and already-signed-in
states without consuming a token on GET/build and without placing the token in
logs or analytics.

## Compatibility and rollout

The existing v2 paths, DTOs, generated interfaces, and consumer behavior stay
wire-compatible. The preserved Go `api.go` adapter retains the old interfaces
and adds the generated v3 tag contracts; v3 controllers are generated but are
not registered in `main.go` until their feature gates and servicers exist.
Generation-based containment must not be enabled on a deployment containing
old binaries that cannot enforce it. Feature flags are independent for the
admin API/UI and public email login. Before production, configure retention
for expired action tokens/encrypted delivery payloads, recipient details,
reports, and audit history; the defaults proposed by the spec are 24 hours,
30 days, and 180 days respectively.
