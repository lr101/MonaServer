# Web admin and email-link login: distributed implementation plan

Status: ready for task-level design review; implementation has not started.
Spec: [web-admin-and-email-login.md](../specs/web-admin-and-email-login.md).
Baseline: `34e4cf1` (`develop`, Flutter startup/session/sync #509), pulled into `t3code/plan-web-admin-interface` by a clean fast-forward on 2026-09-14.

The specification is the behavioral authority. This plan allocates work; a task cannot weaken the spec to simplify its implementation. Defaults in the spec are explicit design decisions, not pre-existing product behavior.

## 1. Source-backed baseline

| Source | Existing behavior / consequence |
| --- | --- |
| `go-server/internal/handler/admin_servicer.go` | Mail accepts addresses or falls back to all verified emails; sends synchronously. Push sends to a topic. Report submission only emails an inbox. |
| `go-server/internal/service/email.go`, `notification.go` | Reuse transport adapters, but add structured provider outcomes. Disabled push currently returns success; bulk mail stops on first error. |
| `go-server/internal/service/auth.go`, `user.go` | Password login, refresh and user mutation exist. Password update removes refresh tokens; no immediate JWT revocation. |
| `go-server/internal/token/jwt.go`, `middleware/jwt.go` | JWT has subject/issued-at/expiry; parser returns only user ID. Middleware looks up username and grants admin by configured username. |
| `go-server/internal/handler/views.go` | Recovery and deletion GET pages mint normal JWTs. Replace action authorization safely rather than reusing this for email login. |
| `go-server/internal/db/queries/users.sql` | Verified-email broadcast query and token deletion exist; email is not unique. DB guide's last migration is 000023; allocate new numbers from actual HEAD during execution. |
| `flutter/lib/app/{bootstrap,production_bootstrap,app}.dart` | App owns startup and restored dependencies. Do not move initialization back into main/widgets. |
| `flutter/lib/app/routing/{app_router,session_redirect}.dart` | App owns router and session listener disposal. Signed-out public allowlist currently excludes email callback/recovery. |
| `flutter/lib/data/service/global_data_service.dart` | `updateData(token, username, expectedGeneration:)` owns guarded credential acceptance, same-account recovery, different-account cleanup. Reuse through a narrow adapter. |
| `flutter/lib/data/config/openapi_config.dart` | Per-session client, serialized refresh, one 401 replay, disposal fences; 403 application failures do not trigger refresh. Preserve this. |
| `flutter/lib/app/lifecycle/sync_lifecycle.dart`, `core/sync/sync_coordinator.dart` | Own automatic session/resume sync and serialization; feature screens must not start duplicate sync. |
| `flutter/ARCHITECTURE.md`, `test/architecture_test.dart` | One Flutter package and target feature boundaries. Auth remains legacy; new isolated features get boundaries without forcing a whole auth migration. |
| `mise.toml`, `.github/workflows/build-flutter.yml` | Local and release configuration pins are Go 1.27.1, Flutter 3.47.4, Node 24.21.0, sqlc 1.31.1. T10 records the Flutter 3.47.4 reconciliation without an unrelated SDK upgrade. |

## 2. Global constraints and coordination

- Planning only in this change. Future execution uses fresh task worktrees based on the integrated prerequisite commit. No agent works on `develop`, pushes, deploys, sends real messages, or creates a PR unless separately requested.
- Follow root, Go, DB, API and Flutter guides conditionally. Read the local stack guide before starting services. Preserve wire compatibility, soft-delete rules and account cleanup. Do not include unrelated dependency upgrades or durable pin-upload work.
- Each task has exactly one writer. Workers are not alone in the codebase: never revert other work, modify unowned files, or regenerate another lane's outputs. Request a coordinator ownership transfer for necessary shared edits. No nested delegation by implementers.
- Isolated worktrees prevent simultaneous writes, but do not eliminate merge conflicts. Integrate in dependency order. Rebase dependent work on reviewed integrated commits; do not independently recreate prerequisites or cherry-pick a prerequisite twice.
- The T01 contract owner writes `api/**`, `go-server/internal/gen/api/**`, generated `internal/gen/server/**`, and `flutter/api/**`. The T02 schema owner assigns migration numbers, writes DB facade/queries and exclusively regenerates `go-server/internal/gen/db/**`. Feature workers submit requested changes to those owners. Regeneration happens at explicit integration barriers, never concurrently. Resume T01/T02 owners for amendments; pause affected consumers until reviewed amendments integrate and allocate them a worker slot.
- The coordinator allocates temporary exclusive ownership of `go-server/cmd/server/main.go`, `server_test.go`, config, Flutter router/composition files, `mise.toml`, dependency manifests and architecture-test registrations. Each allocation appears in the task brief; lane tasks otherwise add focused new files only.
- Implementation workers write meaningful tests first for behavior, record commands/results and commit their task. A task reviewer checks both spec and quality; fixes return to its owner, followed by scoped re-review. The coordinator performs an integrated whole-branch review after all gates. Security/race work deserves a reviewer with sufficient architecture judgment.
- Before execution create this plan's isolated progress ledger using the subagent-driven-development skill workspace helper. Record baseline, task status, ownership, dependency SHAs, interfaces, decisions, tests, review findings and integration commits. No task is done merely because its worker says so.
- Preflight review records one row per task for internal consistency and one row per shared file/interface listed below. Resolve findings before dependent dispatch. A plan amendment is explicit and reviewed; user authorization still controls scope.

### Shared interfaces and ownership barriers

| Producer → consumer | Frozen interface / conflict | Resolution |
| --- | --- | --- |
| T01 → all | OpenAPI names/types/statuses, domain contracts and schema fields | Publish contract examples first; revision requires affected owners to acknowledge |
| T02 → T03/T04/T05/T06/T07 | Auth generation, action tokens, email claims/quotas, audit, snapshots, leases and DB facade | Schema owner generates per reviewed DB change and publishes transaction/locking APIs |
| T03 → T04/T06 | Lock order, principal security state, restricted action validation | One security service owns revocation and issuance; no alternate implementation |
| T04 → T05/T06/T07/T12 | Job handler registration and lease ownership | Worker owns scheduling; action services own business transactions |
| T05 → T07–T12 | Admin session transport, permissions, CSRF and recent MFA | Separate from consumer auth client; shell owns lifecycle |
| T06 → T09/T12 | Login request, exchange, recovery, canonical username | Existing token DTO wrapped in a new result; no breaking DTO edits |
| T07 → T10/T11/T12 | Audience snapshots, job commands/status and actor authorization | Backend determines eligible counts; UI never expands filters locally |
| T08 → T10 | Report query/update/history DTOs | Report actor comes from auth context; target is a separate field |
| T09 ↔ T10–T12 | Flutter router/bootstrap / manifests | Consumer and admin entries separate; coordinator integrates shared wiring serially |
| T10 → T11/T12 | Pure selection models, visual components, admin session providers | Freeze domain contracts/components before parallel feature screens |
| All → T13 | Generated output, schema numbers, composition and E2E infrastructure | Exclusive integration pass and full checks on combined branch |

## 3. API and storage contracts to freeze in T01

New API prefix `/api/v3/admin`; public auth additions `/api/v3/public/auth`. Keep current v2 routes operational with explicit compatibility adapters. Runtime Go route grouping is authoritative, not just OpenAPI security metadata.

| Routes (proposed exact contract) | Purpose |
| --- | --- |
| `POST /api/v3/public/auth/email-link/request` | `{email}` → generic 202; public throttling; no account disclosure |
| `POST /api/v3/public/auth/email-link/exchange` | `{token}` → `{tokens: TokenResponseDto, username}`; invalid/expired/used → generic 400 |
| `POST /api/v3/public/auth/recovery/complete` | `{token, password}` → 204; restricted recovery only |
| `POST /api/v3/auth/session/revoke` | Bearer-authenticated caller revokes only the submitted refresh credential belonging to that caller; idempotent 204. Used for explicit session cleanup, including an exchanged session the client cannot retain. |
| `/api/v3/admin/session/login`, `/mfa`, `/reauthenticate`, `/logout`, `GET /api/v3/admin/session` | Password challenge, TOTP completion, step-up, revocation and current capabilities; no normal JWT fallback |
| `GET /api/v3/admin/users`, `GET /users/{id}` | Bounded cursor search/details, security state and eligibility reasons; no raw tokens/hashes |
| `POST /api/v3/admin/audiences/preview` | Action/payload/audience → snapshot ID, payload binding, counts, expiry; may return 202 snapshot job for large sets |
| `GET /api/v3/admin/audiences/{id}` | Paginated snapshot status/exclusions, authorized to its actor/capability |
| `POST /api/v3/admin/jobs` | Confirm snapshot and action with idempotency key; 202 job ID; no missing/implicit audience |
| `GET /api/v3/admin/jobs`, `GET /jobs/{id}`, `GET /jobs/{id}/recipients` | Progress, account/device counts, cursor outcomes |
| `POST /api/v3/admin/jobs/{id}/retry`, `/cancel` | Eligible failure retry / stop pending; idempotent commands |
| `POST /api/v3/admin/messages/test` | Explicit test recipient, same validation/sanitization; cannot expose action tokens |
| `GET /api/v3/admin/reports`, `GET /reports/{id}`, `POST /reports/{id}/notes`, `PATCH /reports/{id}` | Review, assignment, revision-checked transitions; bulk status actions use report snapshots/jobs |
| `GET /api/v3/admin/audit` | Permission-filtered cursor history |

T01 must specify methods for every session endpoint, operation IDs, pagination limit/default (100/25), field bounds, discriminated audience/action variants, 401 versus 403 versus 409/429/503 behavior, idempotency conflicts and generated-client examples. Freeze CSRF issuance on the pre-authentication session bootstrap, binding to the login challenge/session, rotation after MFA/reauthentication, reload restoration via session GET, and the required header for mutations. Freeze a narrow transaction-safe recovery-enqueue interface for T03 to own and T04 to implement; both receive it before parallel dispatch. Expired/revoked credentials on the new auth path return 401 so Flutter expires its session; preserve legacy endpoint error contracts with an explicit client-compatible migration test. The own-session revoke endpoint uses explicit Bearer authentication (not ambient cookies), verifies refresh-token ownership, and is implemented/tested in T03; it revokes that refresh credential, while account-wide revocation additionally advances generation.

Proposed additive storage groups (T02 confirms concrete SQL types/indexes):

- Users: `auth_generation` default zero, security state, password-disabled flag, compromise timestamp; indexed normalized email lookup without destructive uniqueness enforcement.
- `email_login_claims`: unique canonical email, nullable owner, blocked-ambiguity state; backfill duplicate groups as blocked and unique groups as owned. Atomic claim acquisition/release/reconciliation applies to every confirmation, email change and account deletion. No administrator can choose a duplicate owner through the bulk UI.
- Shared expiring rate-limit buckets keyed by HMAC scope/identifier and window, with atomic quota acquisition, key ID/rotation rules, purge and bounded cardinality. T05/T06 consume the same primitive; authentication delivery has separate capacity from admin campaigns. T02 owns storage, T04 owns dispatch admission, T05/T06 own request admission.
- `account_action_tokens`: hash, purpose, account, email binding, generation, expiry, consumed/revoked state and delivery-attempt reference; never ordinary sessions.
- `admin_memberships`, permissions, encrypted TOTP enrollment, `admin_sessions`, expiring one-use login challenges and MFA replay counters. Store hashes of opaque sessions, key IDs for encrypted secrets, actor user IDs and revocation state.
- `security_incidents`, append-only application audit events; do not FK-cascade away required non-personal incident summaries accidentally. Define deletion/anonymization with retention.
- `reports`, `report_notes`, revision/status/assignee, structured reporter/target IDs and legacy text; indexes for status/date paging.
- `audience_snapshots` and members, `admin_jobs` and items, `delivery_attempts`, durable jobs/outbox with unique business idempotency keys and leased state.
- Device registrations and communication preferences; backfill legacy Firebase token idempotently. Security mail, general mail and push eligibility are separate policies.

Avoid a plaintext-token outbox: keep only token hashes in action-token rows; encrypt the short-lived email token payload needed for retry with a separately configured delivery key and key ID. Clear encrypted payload after acceptance/expiry and never render it in job details. T04 owns encryption/key-rotation failure behavior and must fail closed without the key. An alternative hash-only design is acceptable only with reviewed retry/crash semantics, not silent invalidation of links already sent.

## 4. Task briefs

Each task below is independently dispatchable only after its dependencies are integrated. Estimated sizes are relative (S/M/L), not calendar promises. `Own` names proposed files as well as existing touch points; confirm exact new names in T01 and preserve exclusive shared-file allocations.

### T01 — Freeze contracts and scaffold safe integration (L)

Dependencies: none. Own: `api/**`, all generated Go API/server and Dart API output; coordinator allocation for new unimplemented servicer adapters/router tests only.

Read the spec/guides, write DTO examples for every flow and state, service input/result interfaces, error mapping and capability matrix. Define actions `email`, `login_link`, `push`, `revoke_sessions`, `mark_compromised`, `recovery_resend`, `report_resolve`, `report_dismiss`; explicit selection/filter/all unions. Avoid changing existing generated interfaces without updating implementers in the same commit. Stub new routes as unavailable behind disabled flags, protected at runtime, so the integrated tree compiles; never return successful placeholder mutations. Freeze pure Flutter-facing domain examples for mock UI development.

Acceptance: generation reproducible with pinned tools; both Go outputs and Dart client agree; v2 compatibility fixtures retained; unauthenticated/ordinary-user requests denied on admin routes; disabled APIs unavailable; methods/security/statuses reviewed. Handoff: contract catalog, examples, generator commands and exact SHA.

### T02 — Add schema, database facade and transaction contracts (L)

Dependencies: T01. Own: `go-server/internal/db/**`, `go-server/internal/gen/db/**` regenerated from its SQL sources, and DB tests. Reserve new migration numbers centrally; subsequent query amendments remain this owner's responsibility.

Implement additive schema above, bounded paginated queries, snapshot materialization, unique idempotency constraints, claim/extend/finish leases, shared quota acquisition and consistent locking APIs. Backfill canonical email claims, marking existing duplicate groups blocked rather than failing migration; verification/email mutation atomically claims ownership before making an address eligible. Document one lock order for affected claims/users/tokens, including sorted multi-key email changes; retry deadlock/serialization failures within bounded limits. Reconcile claim release on deletion/change without enabling a still-ambiguous address. Backfill legacy device registrations without disclosing or merging addresses. Specify deletion/retention, HMAC key-rotation quota continuity and indexes. Provide transaction-aware repository methods, not standalone SQL duplicated in services.

Acceptance: old populated schema migrates; duplicate/mixed-case emails do not break startup; simultaneous email confirmations cannot claim the same address; email change/delete releases or blocks claims correctly; quotas remain effective across parallel API instances, restart and key rotation; realistic query indexes; concurrent worker claims have one owner, stale leases cannot commit, same-user security operations serialize; snapshot membership stable; deletion and purge tests. Use disposable PostGIS serially. Handoff: schema/query reference, migration numbers, lock ordering and test evidence. Schedule explicit owner follow-ups at the wave 2 and 4 integration barriers for query amendments needed by downstream workers.

### T03 — Centralize security state and session revocation (L)

Dependencies: T02. Own: `internal/service/account_security.go`, `auth.go`, `user.go`, `internal/token/**`, `internal/middleware/jwt.go`, focused security tests; exclusive coordinator window for route registration and legacy views/templates.

Add generation claim issuance/parsing with zero-generation legacy compatibility. Middleware loads principal security state and roles by stable identity. Route all credential issuance and sensitive mutations through common locking/generation checks, passing the existing transaction facade through token creation rather than escaping it through a pool-backed auth service. Implement atomic containment, own-session refresh revocation, account-wide revocation and incident/audit creation. Own the transaction-safe recovery-queue port frozen in T01; use a test implementation until T04's adapter integrates at the wave-2 barrier. Invalidate login/recovery/delete/confirmation capabilities and admin sessions. Replace broad JWT grants in account-action GET pages with restricted forms/endpoints while preserving old link routes through purpose-limited adapters. Redact legacy action-link paths in `requestLogger` and document matching reverse-proxy redaction; the current logger includes raw URL paths. Keep passwords disabled even if delivery is absent.

Acceptance: same-second revoke/new issuance; in-flight login/refresh/password/email-change races; preexisting JWTs never revive after recovery; generation-zero migration; privileged batch routes also enforce state; missing/stale claims fail correctly; old user API behavior regression; own-session revoke cannot revoke another account's credential; raw legacy slugs absent from captured logs; containment succeeds without trusted email and with real queued delivery unavailable. Handoff: security service port and explicit distinction between subsequent rejection and already-authorized work.

### T04 — Durable jobs and email/push delivery foundation (L)

Dependencies: T02. Own: `internal/jobs/**` (new), delivery adapters under `internal/service/`, isolated worker tests; coordinator allocation for config/worker startup.

Implement leased PostgreSQL workers with context cancellation, graceful shutdown, bounded concurrency, backoff, attempt limits and registration of typed business handlers. Services enqueue inside caller transactions. Persist safe structured outcomes and redact provider errors. Implement encrypted short-lived token delivery payloads, key IDs, expiry and crash recovery. Keep token generation close to first delivery; retries use the same unexpired attempt. Auth queues get priority/capacity isolation from bulk campaigns. Token expiry/reissue may not silently undo an accepted sign-in email. No untracked goroutines or SMTP inside security DB transactions.

Acceptance: crash before/after send, accepted-but-ack-lost uncertainty, retry bounds, wrong key/missing key, token payload purge, revoked token not delivered, lease expiry/stale ack, cancellation, backpressure and shutdown. Missing SMTP/FCM is unavailable, not success. Fake transports plus local SMTP capture; no real providers. Handoff: enqueue/handler interfaces and outcome vocabulary.

### T05 — Independent admin identity and browser sessions (L)

Dependencies: T03 (T04 not required). Own: new admin auth service/handler/middleware and tests, operator bootstrap/enrollment command; coordinator window for config/CORS/session routes.

Implement stable memberships/capabilities and password+TOTP challenge sessions, replay prevention, shared rate limits, encrypted enrollment and revocable opaque cookies. Initial admin challenge throttle: 5 failed attempts per account/IP combination in 15 minutes plus per-IP/global caps, configurable and enforced by the T02 primitive; avoid a permanent attacker-triggered account lock. Operator bootstrap is explicit and idempotent; username matching cannot self-grant membership. Define local break-glass MFA recovery with audit, never public reset by magic link. Step-up binds freshness to session and required action. Apply the new cookie/MFA/capability gate to v2 and v3 admin endpoints; consumer JWTs, email links and UI visibility cannot bypass them. Preserve v2 request/response/send semantics, but intentionally retire its username/Bearer authorization. Enroll operators before gate activation and document/test the legacy admin-client authentication migration; no legacy username fallback flag.

Acceptance: normal JWT or magic login cannot mint admin cookie; enrollment/challenge theft/replay; revoked/demoted/compromised admin rejected each request; CSRF/Origin/CORS/cookie flags; idle/absolute expiry and recent MFA. Self-targeting invalidates session and pauses further job work. Handoff: browser transport/session restoration contract and local operator runbook.

### T06 — Consumer email login and restricted recovery services (L)

Dependencies: T03 + T04. Own: new `internal/service/email_login.go`, `account_recovery.go`, corresponding handlers/tests and server-owned mail templates. Shared auth/views edits remain under a scheduled T03 ownership transfer.

Implement generic request responses, abuse controls, exactly-one verified email lookup, purpose/generation/email-bound tokens, atomic POST exchange, canonical username result, and restricted recovery completion. Admin callers invoke the same issuance service through a typed port, never public HTTP loopback or raw email overrides. Recheck duplicates, current email and restrictions at issuance/delivery/redemption. Mail request must not reset passwords or kill sessions. Successful sign-in consumes sibling login tokens; compromise/recovery has stronger invalidation rules from the spec.

Acceptance: random/expired/used/wrong-purpose tokens, simultaneous redemption, email changes/duplicates, delivery outage, rate limits, enumeration-safe responses, compromised/no-email users, transaction rollback on refresh insertion failure, canonical username, no broad GET JWT. Handoff: complete public endpoints and fixtures for Flutter/browser tests.

### T07 — Audience resolution, bulk actions, users and audit (L)

Dependencies: T03 + T04 + T05 + T06. Own: new admin audience/job/user/audit service and handler files, tests; DB and OpenAPI changes via their owners.

Implement validated filters, immutable snapshots and payload binding, preview pagination, bounded materialization for large audiences, actor/action-bound commit and idempotency. Register handlers for session revocation, compromise, recovery resend, email, login links and push using shared ports. Recheck permissions per batch/item and recipient safety before action. Implement multi-device targeting and preference updates via compatible user endpoints, device ownership/rotation and invalid-token removal only on permanent provider errors. Render safe HTML/plain text, constrain content size and sanitize preview; arbitrary campaign HTML cannot access admin DOM credentials.

Acceptance: empty selection never broadcasts; selected/filter/all beyond first page; changed payload conflicts; revoked actor pauses; retries do not re-contain already recovered users or create extra credentials; cancellation bounds; opt-out/email change after preview shrinks recipients; no admin targets without explicit permission; mixed outcomes/account-vs-device counts; no secrets in audit/search/jobs. Handoff: fixture jobs and deterministic fake provider behavior.

### T08 — Persist reports and implement review workflows (M)

Dependencies: T08a milestone requires T02 + T05; T08b requires T08a + T04 + T07. Own: new report service/handler and tests, extracted report portion of `admin_servicer.go` by exclusive transfer; Flutter report submission not owned here. Keep this task open until both milestones pass.

T08a: persist legacy report requests independent of SMTP, derive reporter from authenticated identity, preserve free-text content, support additive structured target fields. Add cursor inbox, detail, assignee, notes, revision-checked resolve/dismiss/reopen and audit. Escape report content and bound size/rate. T08b: enqueue optional inbox mail transactionally using T04, register bulk report snapshot/job handlers using T07 and verify all-matching status updates. Historical inbox import is excluded.

Acceptance: SMTP down still persists exactly once when request idempotency provided; forged reporter cannot impersonate; deleted targets remain reviewable with bounded snapshots; concurrent edits yield conflict; unauthorized access rejected; multi-page filter bulk status keeps notes/history. Handoff: report DTO/domain fixtures and state transition table.

### T09 — Consumer Flutter email-link login (L)

Dependencies: T01 for mock work; T06 for final integration. Own: `features/email_login/{domain,data,presentation}/**`, focused tests, narrow session adapter; exclusive window for consumer `lib/main.dart`, bootstrap/launch-data adapter, existing auth screen, app router/session redirect and app wiring. Do not refactor all legacy auth. Admin entry/router files are exclusively T10's.

Add email entry, generic sent state, expiry/resend, explicit callback confirmation and restricted recovery forms. Use domain ports/use cases and wire adapters in app; feature presentation imports no generated DTOs or repository implementations. Capture fragment token before router refresh, remove it through a web-only adapter compatible with Wasm and JS fallback, never consume on GET/build or display/log it. Permit callback routes for signed-out, expired and signed-in users without weakening cleanupRequired handling. Before redemption warn that a link may target a different account; after exchange reveals its authoritative identity, require confirmation before accepting a different account and running destructive cleanup. Declining leaves the existing session untouched and revokes the unused new refresh credential where possible.

Implement capture before full production bootstrap, using a one-shot launch-data object/provider override into the feature. The canonical URL uses one fragment, `/#/email-login/callback?token=...`, not a second `#token`. Malformed URLs produce a generic invalid-link state; failure to scrub aborts exchange and avoids secret-bearing diagnostics. Extend architecture checks for the launch adapter and keep its native implementation inert.

Accept exchange through `GlobalDataService.updateData` with canonical username and captured generation. Preserve same-account drafts and failed credential-write recovery; different-account cleanup must finish. Handle exchange-success/local-save failure with a fresh-link retry and best-effort revocation of unused new credentials, not stale state writes. Let `AppSyncLifecycle` react to accepted sessions; do not call sync from callback/auth widgets. Dispose clients/subscriptions and fence late exchange responses after logout/account switch.

Acceptance: architecture checks, router initial/deep link and redirect refresh, scanner/rebuild no consumption, double submit, reload after secret removal, cleanup failure, stale response, same/different-account draft policy, expired restoration, one automatic sync, password-login and Android regressions. Browser E2E required. Handoff: route/test fixtures and architecture documentation of implemented seams only.

### T10 — Admin Flutter entry point, sessions and shared selection (L)

Dependencies: T01 + T05; final audience adapter after T07. Own: `lib/main_admin.dart`, `app/admin/**`, `features/admin_session/**`, `features/admin_users/**`, `features/admin_audience/**`, pure shared visual components and focused tests. Exclusive window for build tasks/manifests/architecture registrations.

Add minimal admin bootstrap and router in the same package; no consumer global session/Drift/sync/Firebase initialization or 450px consumer frame. Do not modify consumer `app_router.dart`, `session_redirect.dart` or `app.dart`. Use a conditional web transport with browser `withCredentials=true`, CSRF header injection and owned disposal; never `AccessTokenManager`, consumer refresh storage or secure-storage admin credentials. Restore through admin session GET. A 401 expires admin state and cancels work; 403 reports capability denial without logging out. Feature domains are pure Dart; app wiring supplies generated-client adapters. Add responsive keyboard-accessible navigation, user search/detail, selected IDs across pagination, matching-filter/all controls, preview/exclusion and explicit confirmation widgets. Polling is owned/disposed, and selection state is cleared or visibly invalidated on filter changes.

Add a dedicated build task using `--target lib/main_admin.dart` and output `build/admin_web`, separate from consumer `build/web`. Own the artifact layout and explicit admin HTML/manifest/CSP preparation; document whether the shell is reused or staged. Reconcile the existing local/CI Flutter pin mismatch with one recorded choice before building either artifact; use existing pinned versions, not a new upgrade. T13 packages/verifies this artifact, not a second competing build task. Extend `architecture_test.dart` and `support/architecture_rules.dart` to restrict `main_admin.dart` to admin bootstrap/Flutter and forbid the admin import graph from reaching consumer bootstrap, global session, account DB, sync, camera or Firebase. Include a runtime negative initialization test as well.

Acceptance: admin bootstrap does not start consumer plugins/sync, no JWT fallback, reload/expiry/403 capabilities, logout cancels late writes, selection across pages and search races, empty selection disabled, testable responsive states/accessibility. Handoff: stable components/domain interfaces, dedicated build command and admin session fixture.

### T11 — Admin report review UI and structured submissions (M)

Dependencies: T07 + T08 + T10 shell milestone. Own: `features/admin_reports/**`, report UI tests; exclusive small transfer for existing consumer `widgets/report_issue/` submission adapter and generated DTO mapping. Expose screen constructors/providers for T10's scheduled final composition pass; do not edit its router.

Implement paginated/filterable report inbox, detail/related target, assignment, notes, revision conflicts and selected/all-matching status actions using shared audience confirmation. Update consumer report submission to supply structured targets while retaining legacy textual semantics. Never trust body reporter ID. Render user content as text and handle deleted targets safely.

Acceptance: report submission compatibility; no-SMTP success; list/detail/errors/empty state, conflicting updates, pagination and bulk outcomes, permissions and keyboard flow. Handoff: report browser scenario.

### T12 — Admin communication, security actions and job monitoring UI (L)

Dependencies: T07 + T10 shell milestone. Own: `features/admin_campaigns/**`, `admin_security/**`, `admin_jobs/**`, `admin_audit/**` and focused tests. Expose screen constructors/providers for T10's scheduled final composition pass; do not edit its router. Shared component amendments go through T10's owner.

Build email/push/login-link composers, safe preview/test send, explicit selection/filter/all audiences, confirmation and progress. Security panel offers revoke, compromise and recovery resend, with reason, recent MFA, explicit admin inclusion and manual-recovery outcome. Job pages explain partial failures, uncertain provider acceptance, retry and cancellation. Display who/what/when in audit; never tokens or password values. Same behavior for one selected account as bulk, using one backend contract.

Acceptance: one/filter/all scope, count exclusions and stale snapshot, no duplicate commit on retries, failed MFA leaves job unsubmitted, compromised account never offered ordinary sign-in, delivery unavailable honest UI, cancellation warning, actor session expiry stops UI work. Handoff: complete browser scenarios and user-facing copy.

### T13 — Integrated contracts, browser verification and rollout package (L)

Dependencies: all previous tasks. Own: remaining composition/config/generation reconciliation via owners, `flutter/e2e/**`, local SMTP/fake push harness, build/deployment configuration examples and verification report/docs. No production operations.

Integrate reviewed tasks, rerun code generation from current sources and inspect churn, verify every route classification including batch/legacy adapters, and package/verify T10's admin build task/artifact using the reconciled Flutter version/package. Keep public login/web artifact separate from admin artifact; admin hosting cannot accidentally start consumer bootstrap. Add a separate artifact verifier, admin static server/base URL and port, isolated Playwright context, and runtime hosting example with SPA fallback/CSP. Preserve consumer image/publication behavior; no publishing is part of this task. Exercise public callback fallback and admin credentialed CORS on local distinct origins and local HTTPS hostnames for same-site subdomain cookie behavior. Update architecture/readme/config docs, feature flags, admin bootstrap/MFA recovery, delivery encryption key rotation, retention, worker shutdown, and generation-aware rollout/rollback constraints.

Acceptance: all checks below on integrated HEAD; whole-branch security/spec review; no critical unresolved issues; no secrets in artifacts/reports. Report unavailable services/platforms explicitly. Handoff: commits, generated-file evidence, checks, local services/browser versions, limitations and deployment instructions. Do not claim production delivery from fakes.

## 5. Scheduling with distributed subagents

Maximum available concurrency is four including the coordinator: use at most three worker/reviewer slots. A review occupies a slot; do not spawn idle dependent workers. Suggested waves:

| Wave | Lane A | Lane B | Lane C | Exit barrier |
| --- | --- | --- | --- | --- |
| 0 | T01 contracts | — | — | Reviewed interface examples, generated/scaffold compile |
| 1 | T02 schema | T09 mock domain/controller work only | — | Reviewed DB transaction APIs; no Flutter shared-file collision |
| 2 | T03 security | T04 jobs/delivery | T09 mocks or task review | Security/queue adapters integrated and containment exercised together; resume T02 owner for any DB amendments |
| 3 | T05 admin auth | T06 email auth | T09 public integration after T06 | Auth gates and replay/race tests |
| 4 | T07 bulk backend | T08a report backend | T10 admin shell/mock milestone | Shared UI and backend contracts reviewed |
| 4b | T08b report outbox/bulk integration | T01/T02 owner follow-ups as needed | Reviews | Report backend fully integrated; revised contracts/schema accepted |
| 5 | T11 reports UI | T12 campaigns/security UI | T09 remaining browser coverage or reviews | Feature screen interfaces reviewed |
| 5b | T10 owner follow-up: live adapters and final admin routes | Feature reviews/fixes | — | T10/T11/T12 integrated acceptance passed |
| 6 | T13 integration | Read-only task/final reviewers as slots allow | — | Integrated checks and final review |

T03/T04 use test doubles for ports frozen in T01 until integrated; neither owns the other's files. T08a has no hidden dependency on T07: T08b owns inbox outbox/bulk integration and is scheduled after T07. T10 publishes a reviewed shell milestone against frozen fake adapters in wave 4; it stays open until wave 5b integrates live adapters and T11/T12 screens. T11/T12 local tests use that shell contract; their final acceptance follows composition. Schema/contract amendments consume a slot and pause dependent work; resume T01/T02 owners, never let a feature worker regenerate their files. If a lane is too large, split it at a reviewed interface boundary into sequential subtasks under the same ownership; do not assign two workers to the same service because a task is taking time.

### Copyable worker dispatch template

```text
Task: Txx — <name>. This is implementation of only this task.
Worktree/base: <isolated path>, <integrated prerequisite SHA>.
Read: docs/specs/web-admin-and-email-login.md; this task's section of
docs/plans/web-admin-and-email-login.md; applicable AGENTS.md; <specific sources>.
Own: <exact files/directories and temporary shared-file allocation>.
Consume: <frozen DTOs/ports, dependency report paths and SHAs>.
Deliver: <implementation, meaningful tests, docs, required acceptance cases>.
You are not alone in the codebase. Do not revert other edits, edit outside
ownership, regenerate shared outputs, or spawn agents. Request ownership/schema/
contract changes from the coordinator. No production sends, push, deploy or PR.
Preserve compatibility and all session/security invariants in the spec.
Commit your task and write a report: changed files, interfaces, exact checks and
results, service availability, unresolved issues, and commit SHA. No secrets.
Reviewer is dispatched by the coordinator after your report.
```

## 6. Verification and release gates

Plan-only check: validate relative links/source references and run `git diff --check`; verify `origin/develop` is an ancestor. No full application test claim for this planning change.

For implementation, run narrow tests during each task; at T13 run:

```bash
# Root tasks use current mise pins; install missing tools via dependency skill.
mise run test
mise run build
cd go-server
mise exec -- go vet ./...
# Disposable PostGIS only; packages share truncating fixtures.
TEST_DATABASE_URL='<disposable-local-DSN>' mise exec -- go test -count=1 -p 1 ./...
```

Format only touched Go files. Regenerate SQL (`mise exec -- make gen-db`), embedded API (`mise exec -- make gen-api`), runtime server (`OPENAPI_GENERATOR_JAR=... make gen-server`) and Dart client using the pinned generator agreed in T01; verify no unexplained generated diff after rerunning. Do not edit generated code by hand. Do not commit `go-server/bin/server`.

```bash
# From repository root, after Flutter/API generation as applicable:
mise run flutter-analyze
mise run flutter-test
mise run flutter-api-test
mise run flutter-build-apk
E2E_API_URL=http://127.0.0.1:8081 mise run flutter-verify-web
# T10/T13 add equivalent admin build + Playwright tasks using main_admin.dart.
```

Read `docs/AGENT_LOCAL_STACK.md` first; use Compose only if available, otherwise native disposable PostgreSQL/PostGIS and foreground RustFS. Add local SMTP capture and fake FCM with deterministic failures. Serialize shared DB tests across agents or allocate distinct disposable databases. No real Firebase/SMTP account is needed or authorized for tests.

Required browser scenarios: fresh and expired email login from captured email; GET/scanner no consumption; replay/expiry; same-account drafts retained; different-account confirmation/cleanup; pending callback versus logout; one owned sync; password-login/group baseline; admin MFA/reload/expiry; cross-origin cookies/CSRF; reports submit/review; selected/filter/all campaign preview/commit; partial failures/retries; compromise and stale access/refresh rejection; recovery and no old-token revival. Exercise Wasm and JS fallback, reload/deep links, narrow/wide layout and accessible controls. Sanitized screenshots/traces must not retain secret-bearing URLs or email payloads.

Report Go/PostGIS/SMTP/fake-FCM/RustFS availability, commands/results, browser version/renderer, artifact paths and actual device coverage. Analysis warnings/infos are reportable, not silently described as a strict lint pass. APK compilation does not prove physical-device behavior. No implementation is ready for handoff until required checks or material blockers are explicitly recorded.

## 7. Completion checklist

- [ ] Reports persisted, legacy submissions compatible, review and bulk state changes audited.
- [ ] Selected/filter/all email, push, sign-in links, recovery and security actions use explicit frozen audiences.
- [ ] Public email-only login and admin sends work without privilege escalation or token disclosure.
- [ ] Compromise blocks old password/access/refresh and all legacy action-link bypasses, including races.
- [ ] Recovery is purpose-limited, delivery failure cannot undo containment, old JWTs never revive.
- [ ] New Flutter login preserves #509 lifecycle/session/draft invariants; admin bootstrap is independent within one package.
- [ ] Shared generators, migrations, composition and ownership integrated without unrelated churn.
- [ ] Real local stack/browser verification and task/final review recorded; rollout and limitations documented.
