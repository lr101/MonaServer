# Task T07 — audience, bulk actions, users, and audit backend

## Scope delivered

This task adds the transport-independent administrative audience and job
services in [`go-server/internal/service/admin_audience.go`](../go-server/internal/service/admin_audience.go),
[`go-server/internal/service/admin_bulk.go`](../go-server/internal/service/admin_bulk.go),
[`go-server/internal/service/admin_users.go`](../go-server/internal/service/admin_users.go),
and [`go-server/internal/service/admin_audit.go`](../go-server/internal/service/admin_audit.go).

Audience resolution validates the selected/filter/all union and resource-tagged
filters, applies bounded content validation, resolves explicit records into an
immutable actor/action/hash/expiry snapshot, and supports opaque cursor reads.
Whitespace-only or otherwise empty filters are normalized to the explicit
`all` variant before authorization, so they require an action-bound recent MFA
proof. Filter resolution uses a count plus bounded page interface; the service
never asks a store for one full audience slice and queues a safe asynchronous
materialization when the count exceeds the configured limit.
All-account and security actions require an action-bound recent MFA proof;
administrator targets require the stronger include-admin capability and
acknowledgement. Preview and commit capability checks are separate, and
snapshot criteria are deep-copied before persistence. Email, login-link, and
push previews account for current email/device eligibility and opt-outs; a
later execution check can only shrink the recipient set.

Bulk jobs use typed action ports for session revocation, compromise
containment, recovery resend, email, login links, push, and report actions.
The job store interface defines the atomic job/item commit, idempotent commands,
lease/CAS claim and finish, progress, pause, and cursor pagination boundaries.
The in-memory store is deterministic for service tests and local composition.
Failed work is retried only after an explicit idempotent retry command;
duplicate item processing returns the stored outcome. Cancellation skips work
that has not started and cannot undo a completed operation. Successful
self-containment of the actor pauses the remaining job for another authorized
operator. A pre-send eligibility port rechecks account state, preferences, and
device ownership immediately before delivery.

`NewAdminBulkService` can receive the actor reloader at construction time (or
through its setup method for creation-only composition), but all execution
entry points pause and fail closed when it is absent. The service never uses
the request actor as a stale reload fallback. Cancellation audit writes remain
idempotent and can be replayed by an idempotent cancel command if an outbox
write is temporarily unavailable.

Each committed item receives one durable operation ID. Keyed login-link and
recovery ports receive that same ID on every attempt; an ambiguous credential
result is durable `unknown_delivery` and cannot be retried, while retryable
failures require an explicit safe-to-retry classification. Unknown delivery is
terminal for scheduling, contributes to completed progress, and is separately
counted as uncertain so a job reaches `completed_with_errors`. Every item
finish uses the required `FinishJobItemWithAudit` boundary, which commits the
item outcome and actor/target/outcome audit intent together (or through a
durable outbox). Workers require the fenced lease claim/finish primitive and
the atomic audit commit before any provider call; legacy unfenced or
operationless adapters fail closed. Fresh actor membership, auth generation,
and capabilities are required and reloaded before every item; revocation or
demotion pauses the job. The legacy one-shot credential ports remain only for
compatibility and are rejected for execution; production wiring must use the
keyed ports.

The user service exposes a bounded, credential-free account projection with
search/security/verified-email/creation-date filters and cursor pagination.
The audit service provides permissioned cursor reads plus an actor-bound append
boundary. Reasons and metadata are length-limited and secret-like fields,
provider-looking values, control characters, and unsafe payload fields are
redacted before they cross the store or generated DTO boundary.

The generated v3 adapters are in
[`go-server/internal/handler/admin_audience_servicer.go`](../go-server/internal/handler/admin_audience_servicer.go),
[`go-server/internal/handler/admin_jobs_servicer.go`](../go-server/internal/handler/admin_jobs_servicer.go),
[`go-server/internal/handler/admin_users_servicer.go`](../go-server/internal/handler/admin_users_servicer.go),
[`go-server/internal/handler/admin_audit_servicer.go`](../go-server/internal/handler/admin_audit_servicer.go),
and [`go-server/internal/handler/admin_messages_servicer.go`](../go-server/internal/handler/admin_messages_servicer.go).
They enforce the principal and CSRF context proof, map only frozen generated
DTOs, and return the bounded v3 error envelope. Main/router registration is
left to the coordinator as requested.

## Exact DB-owner request

No DB, OpenAPI, generated, main, or router files were changed. The production
facade needs these additive operations, each using PostgreSQL parameters and
transactions where stated:

1. `ListAdminUsers(ctx, cursor, limit, search, securityState, verifiedEmail, createdAfter, createdBefore)` and `GetAdminUserDetails(ctx, userID)` should return the safe user projection, including creation time, admin/security state, auth generation, compromise/password flags, communication opt-out, and an aggregate registered-device count. The query must perform filtering and stable cursor ordering in PostgreSQL and must never select passwords, token/code/url columns, or provider credentials.
2. `CountAdminAudience(ctx, actorID, audience, action)` and `ListAdminAudienceMembers(ctx, actorID, audience, action, afterOrdinal, limit)` should evaluate accounts/reports server-side with stable ordering, per-record permission/state/ownership checks, email-ownership/verified-account checks, communication preferences, device eligibility, and explicit exclusion codes. The actor and sanitized action are required authorization context for both calls. Count must not materialize rows; list must return at most the requested bound. A large count should be handed to an asynchronous materializer rather than loaded into one request. Report criteria must remain report-only.
3. `CreateAudienceSnapshot(ctx, snapshot, members)` must insert the snapshot and every member in one transaction, with an immutable canonical audience/action/hash, actor ID, expiry, ordinals, counts, and bounded exclusions. `GetAudienceSnapshot` and `ListAudienceSnapshotMembers(snapshotID, afterOrdinal, limit)` must enforce actor/resource access at the service boundary and stable ordinal cursors.
4. `CreateAdminJobWithItems(ctx, job, items)` must atomically insert one job and all item rows, assign a stable per-item operation ID, and enforce an actor/action/snapshot/payload-bound idempotency key. The service requires this lease interface: `ClaimJobItemWithLease(ctx, jobID, itemID, worker, ttl) (*AdminJobItem, *AdminJobLease, bool, error)` and `FinishJobItemWithLease(ctx, itemID, lease, operationID, outcome, reason, errorCode, providerReference, retryable, ambiguous)`. It also requires `FinishJobItemWithAudit(ctx, itemID, lease, operationID, outcome, reason, errorCode, providerReference, retryable, ambiguous, audit)` so the outcome and audit intent are one transaction or durable outbox. These operations must use compare-and-set fencing, recover stale leases, and refuse stale-worker acknowledgements. The additive `FinishJobItemWithState` shape is a migration seam only and cannot execute a job. `UpdateAdminJobProgress`, `PauseAdminJob`, and `Get/ListAdminJobs` must derive safe account/eligible/device and outcome counts, including terminal uncertain delivery.
5. `ApplyAdminJobCommand(ctx, actorID, jobID, kind, idempotencyKey, reason)` must make retry (failed items only with a persisted safe-to-retry flag) and cancellation idempotent in one transaction. Cancellation must skip only unclaimed work; it cannot restore credentials or undo delivery. Commands and job/item reads must never return action tokens, passwords, provider payloads, or raw provider errors.
6. `ListAdminAudit(ctx, cursor, limit, targetUserID, action)` and `AppendAdminAudit(ctx, event)` should provide append-only storage, stable cursor ordering, target/action filters, bounded safe metadata, and retention/deletion handling. The additive `RecordJobItemAudit(ctx, AdminJobItemAudit)` operation must be idempotent by job/item/outcome and coordinated with the item finish transaction or a durable outbox; it carries only actor ID, target ID, action, outcome, bounded reason/error classification, and the operation ID.

The current generated users interface represents optional `verifiedEmail` as a
plain `bool`. The handler-owned `CaptureAdminUsersQuery` wrapper records query
presence before invoking the frozen generated controller, so routed
`verifiedEmail=false` becomes `*bool(false)` while omission remains nil. The
coordinator should compose this wrapper around the generated users route.

## Verification

Service tests cover empty/invalid audiences, payload sanitization and binding,
MFA/all-account checks, admin exclusions, filter-copy immutability,
preferences/device shrinkage, empty-filter MFA normalization, bounded async
resolution with actor/action handoff, idempotent item processing, explicit
safe retry, credential unknown-outcome suppression, terminal uncertain job
progress, mandatory actor reload and keyed ports, atomic item/audit commit
failure, per-item actor reload/pause, lease fencing, self-containment pause,
eligibility recheck, and actor/target audit binding.
Handler tests cover generated DTO mapping, CSRF rejection, sanitized preview
responses, immutable job commit, idempotent create, and routed explicit-false
verified-email filtering.

```text
mise exec -- gofmt -w internal/service/admin_*.go internal/handler/admin_*.go
mise exec -- go test ./...
PASS
mise exec -- go test -race ./internal/service ./internal/handler
PASS
mise exec -- go vet ./...
PASS
git diff --check
PASS
```

Database tests were not run with `TEST_DATABASE_URL`: this task deliberately
does not add or change database primitives, and the production adapter remains
coordinator/DB-owner work described above. No provider send, deployment, or
PR was performed.
