# Flutter architecture

Status: incremental migration in progress. Reviewed against repository code on
2026-09-10, through `4fe7790`. This is the current architecture and remaining
plan; implemented reliability work does not mean the target layers exist yet.

Start here for ownership and design decisions. Use [README.md](README.md) for
setup, [AGENTS.md](AGENTS.md) for change and verification rules, and
[the local stack guide](../docs/AGENT_LOCAL_STACK.md) for services.

## Current state after the first two slices

The initial behavior-hardening work and architecture quick wins are implemented
in the existing structure. Later changes strengthen those paths. Auth and groups
are still the **planned first feature-layer migrations**, not completed
`domain`/`data`/`presentation` slices.

| Area | Implemented behavior and source | Regression coverage in `test/` |
| --- | --- | --- |
| Session HTTP | [`openapi_config.dart`](lib/data/config/openapi_config.dart) owns a client and in-memory token manager per host/user/refresh credential. Refresh is serialized; a request gets one refresh/replay on 401, not on 403. Disposal fences queued work and response streams and closes the refresh transport. | `openapi_config_test.dart` |
| Account cleanup | [`global_data_service.dart`](lib/data/service/global_data_service.dart) coordinates logout, account switching, and successful account deletion. [`AccountCleanup`](lib/data/service/account_cleanup_service.dart) clears all Drift tables, including likes and offline pictures, plus platform caches. Cleanup failure blocks login until cleanup succeeds. | `account_cleanup_test.dart`, `global_data_repository_test.dart` |
| Local session isolation | [`AccountSession`](lib/data/database/account_session.dart) revokes old database access; [`accountDatabaseProvider`](lib/data/repository/drift_repo.dart) supplies disposable facades over the bootstrap connection. Services capture `accountOperation(ref)` before async work to suppress stale follow-up actions. | `account_cleanup_test.dart` |
| Groups and sync | Group updates are awaited and preserve local activation. [`group_details_service.dart`](lib/data/service/group_details_service.dart) shares metadata, pins, and image state across entry points. Public unjoined groups load from search; media loading/failure does not block metadata or membership actions. | `group_service_test.dart`, `syncing_service_test.dart`, `group_search_test.dart`, `user_group_overview_test.dart` |
| Feed and images | Profile pin reads use the requested user. Feed slivers and grid loading are corrected. Image streams subscribe before refresh; metadata-only updates preserve byte identity, and retained image refresh keeps downloaded bytes. | `pin_user_service_test.dart`, `feed_layout_test.dart`, `image_grid_test.dart`, `image_service_test.dart`, `image_repository_test.dart`, image widget tests |
| Map and camera | Animation/zoom callbacks have lifecycle guards. Camera flows handle permission, empty device/group lists, device selection, browser capture, and preview orientation, framing, and mirroring. | `map_camera_lifecycle_test.dart`, `camera_permissions_test.dart`, `camera_selector_test.dart`, `camera_web_capture_test.dart` |
| Web and diagnostics | Web ships Wasm plus JavaScript fallback, with artifact/serving checks and safe-area handling. Local Playwright verifies login/group flows. PostHog integration was removed. | `web_shell_test.dart`, `docker/test_web_build.sh`, `e2e/` |

These are coverage locations, not a claim that tests ran for this documentation
update or that every production failure path is covered.

## Where code lives now

```text
flutter/
  lib/main.dart            startup, provider overrides, MyApp and web shell
  lib/data/
    config/               generated API client wiring and HTTP lifecycle
    database/             Drift schema and account-session query guards
    entity/               cache models and DTO conversion
    repository/           cache persistence, images, credentials/preferences
    service/              feature workflows, synchronization and global state
  lib/features/           route screens, feature state and some services
  lib/widgets/            shared-looking UI, often with feature state/workflows
  lib/util/               routing, theme, cache abstractions and helpers
  api/                    generated Dart OpenAPI package
  test/                   app regression tests
  e2e/                    local Playwright flow verification
```

`main.dart` still loads configuration, opens Drift, runs legacy cache cleanup,
selects secure storage, initializes native map tiles/Firebase, and wires
Riverpod. `GlobalDataService` still combines session and platform concerns.
Screens still import repositories and generated DTOs; map state still contains
`flutter_map` markers. There is no `lib/app/` or `lib/core/` split or automated
architecture import check yet.

Drift remains the local cache, using hashed IDs, TTL/hit counts and keep-alive
flags. The bootstrap database owns migrations and the physical connection;
repositories use account-scoped facades. This is session isolation over a shared
cache, not a durable multi-account database design. The legacy `hiveVersion`
cleanup marker is not a Drift schema migration mechanism.

## Rules for the next change

Keep Flutter, Riverpod, Drift, the generated OpenAPI client, and a single Flutter
package. Migrate behavior and tests together, one feature at a time; do not
create empty layers or combine unrelated fixes with directory moves.

Target dependency flow:

```text
presentation -> domain <- data
                  ^
          app wires implementations
```

| Target location | Responsibility and dependency boundary |
| --- | --- |
| `app/` | Bootstrap, configuration, dependency wiring, router, shell and lifecycle. Own cross-cutting startup, not feature business rules. |
| `features/<feature>/domain/` | Pure Dart models, repository ports, meaningful use cases, validation and retry policies. No Flutter, Riverpod, Drift, OpenAPI or plugin imports. |
| `features/<feature>/data/` | Remote/local sources, mappers, repository implementations and cache policy. Implements domain ports; no widgets, navigation or snackbars. |
| `features/<feature>/presentation/` | Controllers, view state, screens and UI effects. Uses domain models/use cases, Flutter, Riverpod and shared UI; no repository ports/implementations, DTOs, database rows, HTTP or platform adapters. |
| `core/` | Small cross-cutting foundations, typed failures, network/storage infrastructure and pure platform capability ports. Plugin adapters belong in `app/adapters/` or feature data. |
| `shared/` | Visual components, theme and formatting using data/callbacks; no feature repositories or providers. |
| `api/` | Wire clients/models generated from `../api/openapi.yaml`; no hand-written application behavior. |

These boundaries apply to new and migrated code. Existing violations are
migration debt, not patterns to extend. Add import checks with the first target
folders. Keep database rows and DTO conversion at data boundaries; avoid trivial
use cases that merely rename repository methods.

Riverpod conventions:

- `Provider`: dependency or derived value; `StreamProvider`: stable observation;
  `AsyncNotifier`: async screen query/command; `Notifier`: synchronous UI state.
- Keep providers alive only for deliberate session/cache lifetimes. Own and
  dispose every client, subscription, timer and platform controller.
- Use immutable view state and explicit controller commands/listeners for UI
  effects. Do not start untracked feature work in provider/widget `build()`.
- For media, subscribe before refreshing, use stable IDs and `select`, preserve
  equal byte identity, and test metadata-only updates. `gaplessPlayback` is a
  visual safeguard, not a replacement for stable providers.
- Use the account database facade for repositories; reserve the bootstrap
  database for setup/cleanup. Capture session guards before async gaps and
  recheck before provider reads or follow-up effects. Never reuse old credentials.

## Session, cache and sync policy

The server is the remote source of truth. Drift supplies local reads, cache data
and current offline drafts. Document freshness, stale reads, miss fetching,
eviction/size limits, offline behavior and logout retention for each repository
as it migrates. Use collision-safe product identities and real Drift migrations
for schema changes; await cache initialization and cleanup.

Access tokens stay in memory; refresh credentials use the platform secure-storage
wrapper. Invalid refresh credentials clear the token manager; refresh endpoint
401/403 responses are credential failures. Transient refresh errors propagate.
A unified session repository/state machine and consistent router response to
expiry remain work to do. Target explicit restoring/signed-out/signed-in/expired
states and typed, validated route arguments instead of unchecked `extra`/parsing.

Logout removes account-owned cache and pending payloads; successful account
deletion uses the same local cleanup. Preserve this policy in future outbox work.
Token expiry/transient refresh failure should pause future outbox processing,
not delete its payloads. No production analytics or third-party crash reporting;
keep operational diagnostics minimal and redact credentials, headers, payloads,
images, precise coordinates and personal data. Existing sync logs still need
review as part of that work.

[`SyncingService`](lib/data/service/syncing_service.dart) still starts work from
`build()` and retries cached pins with `lastSynced == null`. It is **not** a
durable outbox or a fully serialized, restart-safe sync coordinator. Move triggers
to an owned coordinator: restored session, successful login, resume with cooldown,
manual refresh, online transition, next due retry and Android worker wake-up.

## Durable offline upload design — not implemented

Durable uploads remain a main product requirement. Processing is automatic with
read-only status; no edit/cancel/discard workflow is required.

- Persist an operation ID, account/group, immutable draft, durable image key,
  media type/size/checksum, status, attempts, next retry, lease owner/expiry,
  typed failure, resulting server pin ID and creation/update/expiry times.
- Write the image to app-owned persistent storage before inserting the outbox
  row. Temporary camera paths, browser object URLs and memory buffers are not
  durable. Reconcile orphan images and missing references at startup; missing
  images become permanent failures. Clean images after completion, permanent
  failure, expiry or account cleanup.
- Use `pending -> uploading -> completed`, returning to `pending` for retryable
  failure/expired leases, or `failed` for permanent failure. Claim due rows with a
  transactional conditional update and unique lease owner. Completion/retry/lease
  extension must still match that owner; stale workers cannot commit results.
- Android uses an OS background worker where supported. Web retries while active
  and on next launch/resume/login/online transition; closed-tab execution is not
  promised. Schedule due retries with an owned lifecycle and bounded backoff.

The approved server direction remains an **optional** `Idempotency-Key` header
on pin creation; it is not present in the bundled contract yet. The operation ID
must remain stable across retries. Existing duplicate detection and a `409`
without a server pin ID are insufficient for reliable reconciliation.

Server implementation requirements:

- Scope keys to the authenticated caller (separate from the target creator).
  Store a server-computed, versioned canonical request hash covering creator,
  group, coordinates, description, UTC date and image checksum; no raw payload.
- A dedicated table with unique caller/key stores state, result ID, timestamps,
  expiry and deletion tombstone. Same key/body returns the same result without
  duplicate XP/image writes; changed body or deleted result returns a permanent
  conflict. Keep existing behavior when the header is absent.
- Make pin creation, XP and idempotency state atomic; concurrent duplicate work
  must wait or return a retryable outcome. Object storage remains nontransactional
  and needs explicit failure/orphan cleanup.
- Retain tombstones for the maximum client outbox lifetime plus accepted request
  delay, and expire client operation IDs consistently. Account deletion is
  immediate. The retention constant still needs a privacy-reviewed decision.
- Add new SQL migrations/queries, update the authoring and bundled OpenAPI
  contracts consistently, reconcile create response statuses, and regenerate Go
  and Dart clients. Follow the API/database guides when implementing this work.

Test restart, lease recovery/ownership, missing images, duplicate/concurrent
requests, changed payload, deleted result, caller isolation, old clients,
retention/cleanup and session changes before claiming durable delivery.

## Remaining migration order

1. **Composition root and guardrails:** split bootstrap/app rendering; validate
   configuration; introduce typed failures, redacted diagnostics, session state,
   platform ports and owned lifecycle; add import checks and fake-startup tests.
2. **Auth and groups:** move login/signup/recovery/logout and group queries,
   commands/membership into domain/data/presentation. Reuse current session fences
   and shared group loading behavior; add controller/use-case/source-policy tests.
3. **Pins, feed and upload:** build the outbox/server idempotency contract above;
   separate reads, mutations, likes, image storage and feed query policies.
4. **Map, camera and platform:** store marker data rather than widgets, move
   camera/location/EXIF/notification/review behind ports, and debounce/cancel stale
   queries. Preserve permission and lifecycle regressions.
5. **Profile, settings and shared UI:** centralize settings/account flows; remove
   feature dependencies from reusable widgets; add localization/accessibility.
6. **Release hardening:** verify real artifacts, storage persistence, cache bounds,
   migration paths, performance, rollout/rollback and diagnostic ownership.

The original high-risk fixes have regression coverage now; do not reopen them as
unimplemented tasks. Their broader architectural replacements above remain open.

## Verification and release constraints

For changed Dart behavior, run focused regression tests plus
`mise run flutter-analyze` and `mise run flutter-test` from the repository root.
Run `mise run flutter-api-test` when generated client behavior changes, and the
relevant web/APK build for platform changes. Analysis tasks currently allow
warnings/infos; report them rather than treating the task as a strict lint gate.
For docs-only changes, check links, source accuracy and `git diff --check`.

CI runs analysis, app/generated API tests, Android debug and web release builds
with web artifact/serving checks; an iOS release compilation job also remains.
Browser flow tests run locally through
`mise run flutter-verify-web`; follow [AGENTS.md](AGENTS.md) and the local stack
guide first. The [browser image probe](test/browser/README.md) covers browser
image-processing behavior. Report what actually ran and any unavailable services
or device capabilities; test-file presence is not release evidence.

Android and web are first-class; iOS is outside the first production scope.
Web builds include Wasm and JavaScript fallback: Wasm-only browser support is no
longer the policy. Record tested browser versions, selected renderer and persistent
storage behavior, including fallback. Resolve the Android minimum from the actual
Flutter/package build; use Samsung Galaxy S26 on Android 16 as the first real
Android target and record its installed build/One UI patch. Also test the resolved
Android lower bound and supported browser lower/current versions.

Use pinned build configuration, but check pins across workflows: currently
`mise.toml` uses Flutter 3.47.3 while GitHub Actions uses 3.47.2. Web production
release remains independent of Android testing/promotion; staging is optional.
Existing German privacy and retention requirements remain in force.

Open product decisions: the first-release performance budget (startup, map,
feed or upload) and maximum pending-upload lifetime/idempotency retention.
Production readiness still requires measured performance/cache limits, durable
upload recovery, deterministic session failures, localization/accessibility,
release smoke evidence, and documented rollout/rollback ownership.
