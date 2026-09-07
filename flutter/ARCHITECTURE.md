# Flutter architecture plan

Status: revised proposal; product decisions below remain open.

Reviewed on 2026-09-07 against `develop` at `5e95a8c`. This is a planning
revision, not evidence that the target architecture or release checks are
implemented. Existing constraints remain in force until explicitly changed.

Scope: the client in `flutter/`, with Android and web as the first production
targets. Existing iOS code and checks are outside this first release scope.

This document describes the target structure for bringing Stick-It into a
production-ready state. It is an incremental migration plan. It does not ask
the team to rewrite the app in one change.

## Decisions to use as the default

Unless an open question at the end of this document changes the direction, use
these defaults:

- Keep Flutter, Riverpod, Drift, and the generated OpenAPI client.
- Keep a single Flutter package for now. Enforce boundaries with directories,
  imports, tests, and review rules before considering a multi-package split.
- Organize code by product feature, then by layer inside the feature.
- Treat the server as the remote source of truth. Use Drift for local reads,
  offline drafts, and cache data with an explicit freshness policy.
- Keep access tokens in memory. Android refresh credentials use platform secure
  storage; the web credential mechanism is a separate unresolved decision.
- Adopt the target structure one vertical slice at a time. Move behavior and
  tests together.

These choices keep the useful parts of the current app while removing the
places where UI, business rules, persistence, and platform APIs currently call
each other directly.

## Confirmed project constraints

The current release plan narrows the first target:

- Android and web are the first-class platforms. iOS is outside the first
  production scope.
- Support the lowest Android and browser versions allowed by the current
  Flutter and package constraints. Keep the WebAssembly build. Whether native
  Wasm execution is mandatory, or the tested JavaScript fallback is supported,
  needs clarification; compilation mode is not a browser support matrix.
- Use a Samsung Galaxy S26 running Android 16 as the first Android testing
  target. Record the exact installed build and One UI patch in test evidence.
- Durable offline pin uploads are a main product feature. A pending upload must
  survive an app restart and retry later. Upload processing happens in the
  background; no edit, cancel, or discard workflow is required.
- The Go server and OpenAPI contract in this repository may change with the
  Flutter client.
- Web can deploy as soon as its own checks pass. Android has a separate build
  and test path, with testing before production promotion. A slow Android
  release must not block a valid web deployment.
- Web currently deploys directly to production. Staging is a future option,
  not a first-release requirement.
- Existing user privacy and data-retention requirements remain in force. New
  storage, retry, and operational diagnostic records must follow applicable
  German privacy requirements.

## What exists today

The current client has the main technical pieces, but its boundaries are loose.

- `lib/main.dart` performs environment loading, cache migration, Drift setup,
  map tile setup, secure-storage selection, Firebase setup, and Riverpod
  overrides before building the app.
- `lib/data/` contains Drift tables, cache entities, repositories, API client
  configuration, application state, feature state, network workflows, image
  loading, sync, and local preferences.
- `lib/features/` contains route-level screens. Some feature state is under
  `data/`, some is under `presentation/state/`, and some workflows are under a
  feature-level `service/` directory.
- `lib/widgets/` contains reusable widgets, but several widget folders also
  own Riverpod state and API-backed behavior.
- `lib/util/` contains routing, theme state, cache abstractions, migration
  code, and small helpers.
- `api/` is a generated Dart client from `../api/openapi.yaml`. It should remain
  generated and isolated from the rest of the app.
- Most local entities still use a generic Drift cache with hashed integer IDs,
  TTL values, hit counts, and keep-alive flags. Images already use stable
  composite cache keys and a schema migration; preserve this work.
- The app already has CI for analysis, Flutter tests, generated API tests, a
  web release build, an Android debug build, and an iOS release build.
- Focused tests now cover token refresh/client disposal, profile pin scope,
  group synchronization, feed layout, map/camera lifecycle, and image cache
  identity and migration. Their existence does not establish full flow coverage.
- `test/browser/` checks image persistence and migration in Wasm and JavaScript;
  `e2e/` provides a local Playwright login/group flow. The latter is deliberately
  outside GitHub Actions under the current Flutter guide.
- CI checks generated Dart output and web container artifacts, but analyzer
  warnings and infos are non-fatal. Web publication still depends on the job
  that builds Android; independent release paths are a remaining change.

The current structure is useful for finding a screen, but it does not tell a
developer who owns a rule or which dependencies are safe. For example:

- `data/service/pin_service.dart` performs API calls, writes the local cache,
  decides offline behavior, and displays snackbars.
- Presentation files read repositories, generated API DTOs, and data services
  directly.
- `features/map_home/data/map_state.dart` stores `flutter_map` `Marker` objects
  in application state, tying state to a rendering package.
- `util/routing/routing.dart` imports nearly every route screen and passes some
  required values through untyped `extra` data and string parsing.
- `main.dart` is the composition root, but it also owns product behavior such
  as cache migration.
- Phase 1 below replaces the historical six-task backlog with an audit of
  existing fixes and remaining failure paths. Do not repeat completed fixes.

## Target architecture

Use a feature-first structure with a one-way dependency flow.

```text
app / composition root
        |
        v
feature presentation  --->  feature domain  <---  feature data
        |                         |                   |
        v                         v                   v
  Flutter/Riverpod          pure Dart rules      API, Drift, platform
        |
        v
shared UI and core services
```

The arrows describe allowed knowledge, not call frequency. The domain defines
interfaces for data it needs. Data implements those interfaces. The app wires
the implementations into Riverpod at the composition root.

### Dependency rules

| Layer | May depend on | Must not depend on | Owns |
| --- | --- | --- | --- |
| `app` | all application layers, platform setup | product behavior hidden in bootstrap code | app startup, dependency wiring, routing, app shell |
| `presentation` | domain models and use-case APIs, `core/ui`, Flutter, Riverpod | repository ports and implementations, data sources, Drift, generated OpenAPI types, HTTP, secure storage, database rows, platform adapters | widgets, controllers, view state, user-facing effects |
| `domain` | pure Dart, `core/foundation`, pure capability ports | Flutter, Riverpod, Drift, OpenAPI, `BuildContext`, platform adapters | business rules, immutable models, repository ports, use cases |
| `data` | domain ports, `core`, generated API, Drift, platform adapters | widgets, `BuildContext`, snackbars, route changes | remote/local data sources, mappers, repository implementations, cache policy |
| `shared` | `core/ui`, Flutter, callbacks and display models | feature repositories and feature providers | reusable visual components with no product workflow |
| generated API | its generator contract | hand-written app behavior | wire models and endpoint clients only |

### Presentation import rule

Presentation code must never import repository ports or implementations, data
sources, generated OpenAPI types or clients, Drift tables or rows, HTTP
clients, secure storage, or platform adapters. It may depend on domain models,
use-case APIs, `core/ui`, Flutter, Riverpod, and other presentation code within
its feature.

Controllers consume domain use-case/query APIs, whose implementations can use
repository ports. The composition root wires providers without requiring the
screen to import data. Enforce this rule in review and with an import lint once
the target directories exist.

Cross-feature workflows use explicit domain APIs or ports wired by `app`; do
not import another feature's data or presentation internals. Pins owns upload
state and retry policy; `app/lifecycle` owns scheduling and calls the pin use
cases. A separate `features/sync` feature is unnecessary. Core network/storage
code must not import feature implementations; inject pure interfaces instead.
Legacy imports may remain on a documented allowlist during migration. Each
slice removes its entries; new code must satisfy the target rules.

### Platform port rule

Platform capability interfaces must be pure Dart and live under
`core/platform/ports` or the owning feature's domain layer. Their implementations
belong under `app/adapters` or feature data and may import Flutter plugins.
Presentation invokes a use case or controller; it does not call a camera,
location, notification, or storage adapter directly.

### Proposed directory layout

```text
lib/
  app/
    app.dart
    bootstrap.dart
    dependency_injection.dart
    adapters/
      platform/
    router/
      app_router.dart
      route_arguments.dart
    environment/
      app_config.dart
    lifecycle/
      app_lifecycle_controller.dart

  core/
    error/
      app_failure.dart
      failure_mapper.dart
    foundation/
      result.dart
      clock.dart
    network/
      api_client_factory.dart
      auth_interceptor.dart
      network_error_mapper.dart
    storage/
      secure_token_store.dart
      preferences_store.dart
      database/
        app_database.dart
        migrations.dart
    platform/
      ports/
        camera_port.dart
        location_port.dart
        notification_port.dart
    ui/
      feedback_controller.dart
      design_system/

  features/
    auth/
      domain/
        entities/
        repositories/
        use_cases/
      data/
        remote/
        local/
        mappers/
        repositories/
      presentation/
        controllers/
        pages/
        widgets/

    groups/
      domain/
      data/
      presentation/

    pins/
      domain/
      data/
      presentation/

    feed/
      domain/
      data/
      presentation/

    map/
      domain/
      data/
      presentation/

    camera/
      domain/
      data/
      presentation/

    ranking/
      domain/
      data/
      presentation/

    profile/
      domain/
      data/
      presentation/

    achievements/
      domain/
      data/
      presentation/

    settings/
      domain/
      data/
      presentation/

  shared/
    widgets/
    theme/
    formatting/
```

Do not create empty layers for every trivial widget. A feature can start with
only `presentation/` and add `domain/` or `data/` when it owns real behavior.
The point is to make dependencies visible, not to increase file count.

## Responsibilities by layer

### App and composition root

Split the current `main.dart` into two parts:

1. `bootstrap.dart` performs ordered startup and returns an application
   dependency container or provider overrides.
2. `app.dart` builds `MaterialApp.router`, the theme, localization, and app
   shell.

Bootstrap should own only cross-cutting startup concerns:

- environment validation
- secure storage and preferences
- database open and migrations
- API client construction
- minimal redacted operational diagnostics
- platform plugin setup
- provider overrides

Feature actions such as syncing user groups or requesting notification
permission belong to a feature coordinator or an app lifecycle controller. Do
not start them as an untracked side effect of a provider `build()` method.

### Domain

Domain code should be testable with the Dart test runner and no Flutter test
binding. It should contain:

- immutable product models such as `Pin`, `Group`, `User`, and `LikeSummary`
- value objects for IDs, coordinates, visibility, and upload status where
  validation is needed
- repository interfaces such as `PinRepository` and `SessionRepository`
- use cases for meaningful workflows such as `CreatePin`, `SyncAccount`,
  `JoinGroup`, and `UpdateProfile`
- pure filtering, sorting, validation, and retry decisions

Domain models must not be Drift rows or OpenAPI DTOs. Mappers translate those
types at the data boundary.

Use cases encode policies or coordinate repositories. For simple reads, expose
one small domain query API per feature (for example `WatchGroupPins`) that
hides the repository port from presentation. A thin query boundary is acceptable
where it enforces the presentation import rule; a class per repository method
is not required.

### Data

Each feature data layer should make its sources explicit:

```text
feature repository
  -> local data source (Drift)
  -> remote data source (generated OpenAPI client)
  -> mapper (wire/database type <-> domain type)
```

The repository decides which source to use according to a documented policy.
The UI should not need to know whether a value is cached or remote.

The generated API package remains an implementation detail of remote data
sources and core network setup. Composition-root wiring may construct those
implementations; presentation and domain must not import
`package:openapi/api.dart`. Drift rows stay within feature data and core database
code and are mapped before reaching domain or presentation.

Data code must return typed failures or a typed result. It must not return
English UI strings, show snackbars, or navigate.

### Presentation

Presentation has three responsibilities:

- render a state snapshot
- translate user input into controller commands
- render a user-facing outcome such as a dialog, snackbar, or route change

Screens should consume immutable view state. A controller may expose domain
values directly for simple reads, but it should expose a view model when the
screen needs loading, empty, error, pagination, or action state.

Keep side effects out of `build()`. Use controller methods and deliberate
Riverpod listeners for effects such as navigation and snackbars.

Examples for this codebase:

- Move upload messages out of `PinService`. The upload controller returns a
  typed result; the upload page chooses the message and navigation.
- Replace map state containing `Marker` with a domain or presentation model
  such as `MapMarkerModel`. Build `Marker` widgets at the map boundary.
- Move camera, EXIF, location, and image-cropping calls behind ports. The
  camera page coordinates the flow without implementing every platform detail.

### Shared UI

`shared/widgets` must be reusable without knowing the current user, group,
router, repository, or API. Pass data and callbacks in. If a widget needs a
feature provider, it belongs inside that feature.

The current `widgets/` directory can be migrated gradually. A visual
component can move first while its feature-specific controller remains in the
feature until the workflow is extracted.

## State management rules

Riverpod remains the dependency injection and state delivery mechanism. Use it
consistently:

- `Provider` exposes a dependency or a pure derived value.
- A presentation `StreamProvider` exposes a domain query stream, usually backed
  by a local database observation through a repository.
- `AsyncNotifier` owns an asynchronous query or a screen-level mutation.
- `Notifier` owns synchronous local state such as a selected tab or draft
  field.
- Keep-alive is explicit and reserved for app-wide state, durable sessions,
  and long-lived caches.
- Providers should not create unmanaged timers, subscriptions, or network
  requests in `build()`.
- Capture dependencies and the session identity before awaiting. After an
  async gap, check disposal and session generation before reading `ref` or
  publishing state. `ref.read` alone does not make a stale command safe.
- State is immutable. Do not mutate a list or entity in place and then call
  `notifyListeners()` to force a rebuild.
- A mutation provider owns its in-flight state. Expose `isSubmitting`,
  `failure`, and retry information instead of making screens infer them from a
  separate service.

Use a consistent state shape for screen controllers:

```text
initial/loading
ready(data)
empty
failure(AppFailure)
```

`AsyncValue` is acceptable for simple cases. Use a feature-specific immutable
state when one screen has multiple independent values or commands.

## Data, cache, and offline behavior

The current cache combines persistence, eviction, request deduplication,
Flutter image memory caching, and feature policy. Split those concerns.

### Local database

- Keep one Drift database, but organize tables and queries by feature.
- Add real Drift schema migrations for every schema change. Do not reuse the
  old `hiveVersion` marker for Drift migrations.
- Use stable string IDs or collision-safe keys for product records. A fast hash
  may be an index, but it should not be the only identity for a pin, user,
  group, or image.
- Scope account-owned records by account ID where a device can hold data from
  more than one session.
- Keep database row classes and converters inside the local data layer.
- Make cache startup and cleanup awaitable. A repository must not begin an
  untracked async cleanup in its constructor and then serve reads before it
  finishes.

### Cache policy

Document cache policy per repository:

- freshness duration
- whether stale data is shown
- whether a miss triggers a remote fetch
- whether the record survives logout
- maximum size and eviction rule
- behavior when the device is offline

Images need a separate image cache abstraction. It may use a disk cache and a
Flutter memory cache, but the feature repository should not know about
`MemoryImage`.

Preserve the media guarantees in [AGENTS.md](AGENTS.md): subscribe before
refresh, select stable provider inputs, preserve byte-buffer identity on
metadata-only updates, and suppress equal byte events. Use gapless playback
where replacement must preserve the frame. Keep the existing repository,
provider, widget, and browser image regressions with each migrated slice.

### Offline pin uploads

Treat an offline upload as a durable outbox item, not as an ordinary cached pin
with `lastSynced == null`.

An outbox record should contain:

- a client-generated operation ID
- an immutable copy of the draft fields and a durable image-store key
- the target group and account ID
- status: pending, uploading, blockedAuth, failed, expired, or completed
- attempt count and the next retry time
- an upload lease or lease expiry for crash recovery
- a unique upload lease owner/token for conditional state updates
- the last typed failure
- the server pin ID once the operation succeeds
- creation, update, and expiry timestamps

The sync coordinator processes the outbox with bounded retries and idempotent
behavior. It must survive an app restart, process death, token expiry,
transient network failure, and a partially completed image upload. The server
change below provides the stable identity needed to recognize a retry as a
duplicate.

Queueing must copy the image into an app-owned durable `ImageStore` before the
outbox row references it. Android uses an app-private persistent file; web uses
the persistent storage mechanism supported by the WASM database/build. Camera
temporary paths, browser object URLs, and memory-only byte buffers are not
valid outbox storage. Browser persistence is conditional: request persistence,
handle denial and quota errors, and verify storage on the deployed origin.
User-cleared data and storage eviction can destroy unsent items; do not promise
unconditional survival. Report queued only after the durable writes succeed.
Keep pending images outside ordinary cache eviction and set both byte and item
limits before accepting work. A full queue rejects a new submission with a
clear result; it must not evict an accepted pending upload. See
[MDN storage limits](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria).

Store the media type, size, and checksum with the image metadata. Completion
and confirmed account deletion permit payload cleanup. Permanent-failure,
expiry, and explicit-logout cleanup follow D2; resolve that decision before
implementing destructive outbox cleanup.

The image write and database insert are coordinated as a recoverable two-step
operation: write the image with an operation-specific key, insert the outbox
row in a transaction, then reconcile unreferenced image files and rows with
missing images at startup. A missing image becomes a typed permanent failure;
an unexpired row in `uploading` state whose lease has expired returns to
`pending`. Reconciliation must coordinate with active image writers across
workers/tabs and allow a staging grace period; an image awaiting its outbox
insert is not an orphan merely because a concurrent scan finds no row.

Use this state machine:

```text
pending -> uploading -> completed
                    -> pending       (retryable failure or expired lease)
                    -> blockedAuth   (session cannot be restored)
                    -> failed        (permanent failure)
blockedAuth -> pending                (same account authenticates)
any nonterminal state -> expired     (operation deadline reached)
```

A transport timeout is an unknown server outcome, so retry the same operation
ID. Do not mint a new ID to escape a conflict. Retry network errors, throttling,
and transient server errors with capped exponential backoff and jitter; honor
`Retry-After`. Validation, lost membership, missing images, and key conflicts
are terminal. Authentication recovery is bounded and does not loop on invalid
credentials. Cleanup must run for failed and expired rows even while signed out;
photo deletion and the lifetime of a minimal failure notice require decision D2.
If the app never runs again, local physical deletion cannot occur on schedule.
Expiry stops new attempts; it cannot undo an in-flight remote commit. Preserve
an unknown-outcome notice when appropriate and reconcile through server sync;
do not describe a timed-out or expired attempt as proof that no pin was posted.

The background scheduler claims only due, unexpired `pending` rows. Claiming is
a transactional conditional update that sets `uploading`, a unique lease owner,
and a lease expiry, then returns the claimed row. Foreground work and an
Android worker must compete through this same claim, so they cannot upload the
same row while the lease is valid. A timed-out request can still be executing
when a lease expires, so server idempotency remains necessary. Browser tabs
must use the same transactional claim too. Completion, retry, failure, and
lease extension update the row only when the caller still owns the lease; a stale worker
must discard its result. An expired lease may be reclaimed by a new owner.

Android should use a WorkManager-backed adapter if closed-app retries are
required (D1). Validate plugin initialization, shared Drift access, credential
access, and cross-isolate refresh coordination in an early device spike. An
in-memory Riverpod singleton or mutex does not coordinate isolates or tabs.
Scheduling is subject to OS constraints, not an exact execution deadline; test
process death, reboot, stopped work, and force-stop/relaunch recovery. See
[Android persistent work](https://developer.android.com/develop/background-work/background-tasks/persistent).
Web retries while active and on next launch, resume, authentication, or online
transition; closed-browser execution is outside the proposed guarantee.
While a process is alive, schedule the next due attempt without creating an
unmanaged timer in a provider `build()` method.

Because uploads run in the background, the coordinator must pause when there
is no valid session. The existing plan selected removal of account-owned pending
payloads and images on explicit logout, with a new outbox on later login. Keep
that as the proposal for D2; confirm its data-loss consequence before introducing
the durable outbox cleanup. Regardless of D2, logout stops further sync, and
confirmed account deletion removes all pending local payloads and image files. A token expiry or
transient refresh failure pauses the row without deleting it. No pending item
may reuse credentials from the previous session.

Before cleanup, invalidate the session generation and stop new claims. All
worker completions check lease ownership and session identity; refresh
completions check session identity before publishing credentials. Await cleanup and invalidate
account-scoped providers; an old response must not repopulate erased caches.
Logout cannot undo a request already committed remotely. Define that outcome
in the UI and test logout during a request. Account deletion must serialize with
server mutations so an old authenticated request cannot recreate deleted data.
Deletion performed on another device requires an authoritative server signal
before local cleanup; a generic invalid refresh response alone cannot distinguish
deletion from credential revocation. Specify that signal in the account contract.
Until deletion is confirmed, pause account work and apply the outbox expiry policy.

### Server support for idempotent pin creation

This is possible in the current Go server without breaking clients that do not
yet send an idempotency key.

The current `POST /api/v2/pins` flow accepts a `pinRequestDto`, checks for a
matching user, location, and creation time, generates a new server UUID, adds
XP, and stores the image. The Flutter offline pin already has a local UUID,
but the request DTO does not send it. If the first request reaches the server
and its response is lost, the retry can receive `409` while the client still
does not know the server pin ID. That is not sufficient for a durable outbox.

Use an optional `Idempotency-Key` header on `POST /api/v2/pins`:

1. Flutter sends the outbox operation ID as the header. The operation ID is
   stable across every retry.
2. The server scopes the key to the authenticated caller, separately from the
   target `creator_id` in the request, and stores a hash of the normalized
   request. This distinction is required when an administrator can create a
   pin for another user.
3. A repeat with the same caller, key, and request hash returns the existing
   pin and does not add XP or store a second image.
4. The same key with a different request returns `409` and the client marks
   the outbox item as a permanent conflict.
5. Requests without the header keep the current behavior during migration.

Use a dedicated `pin_creation_idempotency` table rather than columns on
`pins`. It should contain the authenticated caller ID, idempotency key, request
hash, state, resulting pin ID, creation time, expiry time, and a deletion
tombstone. Enforce uniqueness on `(authenticated_caller_id, idempotency_key)`.
Do not store the image or raw request in this table; include an image checksum
in the normalized request hash instead. The target creator, group, coordinates,
description, date, and image checksum must all be covered by the hash.

The server computes the hash; it must not trust a client-supplied hash. Define
one canonical encoding with a version: stable field ordering, normalized IDs,
UTC timestamps, the agreed coordinate precision, and the image checksum. Store
the hash version with the row so a future normalization change cannot silently
turn a retry into a different request.

Keep the idempotency row after pin deletion until its retention deadline. A
retry for a deleted result returns a permanent `409` or equivalent conflict;
it must not recreate the pin or award XP. The retention deadline must cover
the maximum client outbox lifetime plus the maximum accepted request delay.
Measure server retention from first receipt; client expiry runs from local
queue creation. The server window must conservatively cover the client lifetime
plus an agreed in-flight delay and clock-skew allowance. Never extend client
expiry on retry, reload, or authentication. A device clock change must not revive
an expired operation. Retention alone cannot reject an arbitrary replay after
its row is deleted: the proposed guarantee covers conforming clients within the
window. If rejection of every late replay is required, design a server-verifiable
operation deadline or longer-lived tombstone before implementation (D2).

The insert, idempotency state transition, pin creation, and XP update must be
atomic. If an identical request arrives while the first request is processing,
the unique key must make it wait or return a retryable response; it must never
run the mutation twice. The object-storage write is still non-transactional,
so orphan cleanup and an explicit storage failure policy remain necessary.
Proposed policy: for an image-bearing request, complete the object write before
committing pin, XP, and idempotency success together. Object failure rolls back
the database work; commit failure may leave an orphan. Preserve the existing
`PinKey(pinID)` object-key format. Each new creation attempt uses its own candidate
pin UUID; a committed keyed replay reuses the recorded UUID. Reconcile old
unreferenced candidate objects after a grace period longer than a live request.
An ambiguous commit must be resolved from database/idempotency state before
cleanup; never delete an object that a successful attempt references. Never acknowledge a completed upload with a missing required image.

The server work belongs in a new migration, the named sqlc queries and facade,
the pin service, and the pin handler. Add the optional header to both the
authoring API fragments and the bundled `api/openapi.yaml`, then regenerate
the Go and Dart clients. The fragment currently documents a `201` create
response while the bundled contract says `200`; reconcile that mismatch in
the same contract change before generation. The current handler returns `201`;
preserve that observed success behavior for first creation and keyed replay,
and align the contract to it. Replay returns the same pin identity, not an
expired stored image URL. Authenticate and check current access before replay.
Document machine-readable key-conflict/deleted-result outcomes and a retryable
in-progress response. Allow `Idempotency-Key` in browser CORS preflight and
verify that proxies forward it.

The first server tests should prove that:

- the first keyed request creates one pin and one XP update
- a retry returns the same server pin ID
- a retry does not add XP twice
- concurrent identical requests do not create two pins
- a reused key with a different body returns `409`
- an administrator key is isolated from the target creator ID
- a retry after pin deletion cannot recreate the pin or award XP
- an old request without the header still works
- authorization scopes the key to the authenticated caller
- object-write failure rolls back pin, XP, and successful idempotency state
- a lost response and a database commit failure recover without duplicate XP
- revoked membership and account deletion cannot be bypassed through replay
- the browser preflight and generated clients preserve the header

This design gives the Flutter outbox a reliable mapping from its local
operation ID to the server pin ID. Its duplicate guarantee is bounded by the
documented idempotency retention period. It does not make object storage
transactional, so image orphan cleanup still needs a separate failure policy.

### Synchronization

Create one `SyncCoordinator` with explicit triggers:

- app startup after session restoration
- app resume, subject to a cooldown
- user-initiated refresh
- successful authentication
- an online transition
- the next due retry while the app process is alive
- an Android background-worker wake-up for due rows

The coordinator calls feature use cases. It does not make widgets subscribe to
one another or depend on route lifetime. Each sync operation should be
idempotent, awaited, observable, and safe to run once at a time. Web does not
promise execution while the browser is closed; the next launch is a required
recovery trigger.

## Authentication and networking

Make session state a first-class feature rather than a nullable field read by
the router.

```text
unknown -> restoring -> signedOut
                     -> signedIn(user/session)
                     -> expired
```

Recommended ownership:

- `SessionRepository` restores and clears credentials.
- `AuthRemoteDataSource` calls the generated auth endpoints.
- On Android, `SecureTokenStore` persists only the refresh credential and account
  identity required to restore a session. Web persistence follows D4.
- `AuthInterceptor` supplies the in-memory access token.
- One refresh operation is shared by concurrent requests.
- A 401 allows one refresh and at most one replay, only for a replayable
  request under its mutation policy. Invalid refresh credentials clear the
  active session and require sign-in; transient refresh failures preserve the
  refresh credential and paused outbox and return a retryable failure. Neither
  case invokes explicit-logout payload deletion.
- Automatic transport retries must be limited to safe reads and explicitly
  idempotent mutations. A generic retry wrapper must not replay an unkeyed pin
  creation after an ambiguous failure.
- A 403 is treated as an authorization/domain error unless the backend
  contract explicitly says otherwise.
- Request and response logs redact tokens, image data, credentials, and
  personal data. Production code must not log every request.
- Every client and stream subscription has an owned lifecycle and a clear
  disposal path.

### Web session decision

The current `WebSecureStorage` wraps `flutter_secure_storage`, whose web
implementation uses browser storage; it does not provide an HttpOnly credential
boundary. See the [package documentation](https://pub.dev/packages/flutter_secure_storage).
Choose D4 before the auth slice: retain this model explicitly, use a same-origin
server-managed HttpOnly refresh cookie, or require sign-in after restart. The
cookie proposal needs a web-specific refresh/logout contract, Secure/SameSite
settings, CSRF and origin checks, credentialed requests, and a verified deployment
origin. Keep Android bearer authentication compatible. Coordinate refresh and
logout across tabs for whichever model is selected.

The router observes session state and redirects from it. Route builders should
parse typed arguments and show a controlled error for an invalid deep link.
Required screen data should not rely on `state.extra!` or unchecked
`double.parse` calls.

## Feature boundaries and migration mapping

The first pass can keep the current product names while moving ownership.

| Current area | Target owner | First change |
| --- | --- | --- |
| `data/service/global_data_service.dart` | `app` plus `features/auth` and `core/platform` | split session, camera discovery, preferences, and location into separate services |
| `data/config/openapi_config.dart` | `core/network` | create and dispose one configured client; isolate refresh behavior |
| `data/database/` and root repositories | `core/storage` plus feature `data/local` | keep Drift centralized, move queries and mappers behind feature repositories |
| `data/service/group_service.dart` | `features/groups` | split group queries, group commands, and sync coordination |
| `data/service/pin_service.dart` | `features/pins` plus `app/lifecycle` | separate pin queries, upload commands, and UI feedback |
| `data/service/syncing_service.dart` | `app/lifecycle` plus feature sync use cases | make triggers, concurrency, and errors explicit |
| `data/service/image_service.dart` and `image_repository.dart` | `core/storage` plus feature image sources | separate image bytes, URL fetching, disk cache, and Flutter memory cache |
| `features/*/data/` state providers | feature `presentation/controllers` or feature `domain` | classify each provider by whether it owns UI state or a product rule |
| `widgets/*/data` and `widgets/*/service` | feature presentation or `shared` | move product workflows into the owning feature; leave visual state with widgets |
| `util/routing/routing.dart` | `app/router` | typed routes, session-driven redirects, controlled deep-link failures |
| `util/theme/` | `app/theme` or `shared/theme` | keep persistence behind a settings repository |
| `api/` | generated boundary | regenerate only from `../api/openapi.yaml`; do not edit by hand |

Do not move a file only because its name contains `service`. Decide whether it
is a repository, data source, use case, controller, coordinator, or platform
adapter, then move the behavior with tests.

## Production migration plan

### Phase 0: agree on constraints and add guardrails

- Record the confirmed platform, offline, API, release, and privacy
  constraints in this document.
- Assign each remaining decision below to its dependent slice. Resolve platform
  feasibility early and retention before implementing the outbox; baseline
  performance before accepting release budgets.
- Capture a baseline for `flutter analyze`, `flutter test`, generated API
  tests, Android builds, and web release builds in an environment with Flutter
  installed.
- Record the numeric Android `minSdk` resolved by Flutter and all browser
  versions used by the WebAssembly smoke matrix in the release evidence.
- Add a short dependency rule to review guidelines and reject new presentation
  imports of Drift, OpenAPI, repositories, or platform plugins.
- Add an architecture check or import-lint rule once the first target folders
  exist.
- Define a typed `AppFailure` vocabulary and a logging redaction policy.

Exit criteria: the team can review a new feature and identify its layer,
source of truth, error path, and test level.

### Phase 1: fix high-risk behavior before moving large areas

Audit the former six-task backlog against existing implementation and tests:

| Area | Existing evidence under `test/` | Remaining gate |
| --- | --- | --- |
| Logout/deletion | Logout currently clears preferences and stored credentials | Await all cleanup; erase account rows/media; prevent stale completions from restoring data |
| Profile pin scope | `pin_user_service_test.dart` | Preserve requested-user and public-group behavior during migration |
| Feed/media | `feed_layout_test.dart`, `feed_image_test.dart`, `image_grid_test.dart`, image repository/provider tests | Preserve failure states, byte identity, and cache migration across web reload |
| Group sync | `group_service_test.dart`, `syncing_service_test.dart` | Verify whole-sync concurrency, partial failure, and account switch |
| Authentication | `openapi_config_test.dart` | Verify logout during refresh, cross-context coordination, and safe mutation replay |
| Map/camera | `map_camera_lifecycle_test.dart`, `global_data_repository_test.dart` | Verify real-device permissions, process lifecycle, and measured performance |

Use [the local browser image probe](test/browser/README.md) and the
[agent-local stack guide](../docs/AGENT_LOCAL_STACK.md) for relevant browser
validation. Existing tests are evidence to preserve, not a claim that these
remaining gates have passed.

Each task needs a focused regression test and a full Flutter test and analysis
run. Keep these fixes behavior-focused. Do not combine them with a broad
directory move.

Exit criteria: session expiry, logout, account deletion, sync, feed rendering,
camera permission, and map movement have known outcomes and tests for their
failure paths. Offline-upload behavior is covered when the outbox is
introduced in Phase 4.

### Phase 2: establish the composition root

- Split `main.dart` into bootstrap and app rendering.
- Add typed environment configuration with validation for API, Firebase, and
  map settings.
- Add a session repository and a single auth state used by the router.
- Add core error mapping, logging, and platform ports.
- Make all long-lived resources disposable.

Exit criteria: startup can be tested with fake dependencies, and no feature
needs to import `main.dart` or initialize a plugin itself.

### Phase 3: migrate auth and groups as the first vertical slices

- Move login, signup, recovery, logout, group list, group search, group create,
  group edit, and group membership behind controllers and use cases.
- Add remote data sources, local data sources, mappers, and repository ports.
- Replace UI reads of generated DTOs with domain models or view models.
- Add unit tests for validation and use cases, data tests for repository source
  selection, and widget tests for loading, error, and success states.

Auth establishes the session boundary. Groups establish the local database and
sync pattern used by the rest of the app.

### Phase 4: migrate pins, feed, and image upload

Order this work as independently reviewable prerequisites:

1. Resolve D1/D2 and prove worker/database and browser-storage feasibility.
2. Implement server idempotency, migration, contract, CORS, generators, and
   disposable PostGIS/object-store failure tests.
3. Deploy backward-compatible server support and verify keyed replay on the
   target environment. Gate the new client outbox on that capability; never
   silently downgrade a keyed retry to an unkeyed request.
4. Introduce the durable upload outbox behind pin use cases and platform
   schedulers, then migrate its screens and media reads.

Pin server idempotency support as a minimum backend version while clients can
hold queued operations. Rollback must preserve that support and database rows;
rolling back to an unkeyed server is not a safe outbox rollback.

- Introduce the durable upload outbox schema and migration.
- Copy images into the durable `ImageStore` before queueing and reconcile
  orphaned files or missing image references on startup.
- Implement the outbox state machine, lease recovery, due-time scheduling,
  Android worker trigger, web active-session/next-launch trigger, and account
  deletion cleanup.
- Split pin reads, pin mutations, likes, image storage, and feed composition.
- Keep filtering and sorting as pure domain functions or explicit query
  policies.
- Make upload status visible as read-only state and retry automatically in the
  background.
- Add tests for app restart, expired upload leases, missing images, duplicate
  retries, concurrent claim ownership, stale-worker completion, idempotency
  retention, image cleanup, hidden users/posts, paging, logout, account
  deletion, account-scoped data, browser multi-tab claims, quota failure,
  persistence denial, clock changes, and expiry while signed out.

Exit criteria: an accepted upload survives supported restart scenarios; lost
responses produce one pin and one XP award; unsupported storage never reports
successful queueing; failures and expiry follow the agreed user-visible policy.

### Phase 5: migrate map, camera, ranking, and platform flows

- Store map data, not `flutter_map` widgets, in state.
- Move camera, location, EXIF, notification, and app-review calls behind
  platform ports.
- Make permission denial, unavailable hardware, empty groups, and disposed
  screens normal states.
- Debounce map queries and cancel stale requests through a domain/data policy.
- Add integration coverage for a real camera or a fake platform implementation.

### Phase 6: migrate profile, settings, achievements, and shared UI

- Move profile and settings persistence behind repositories.
- Centralize theme, locale, notification, and account deletion state.
- Remove feature providers from reusable widgets.
- Add localization resources and accessibility checks before release.

### Phase 7: release hardening

- Test Android and web release artifacts with production-like settings.
- Split the existing combined CI job into shared analysis/tests, web build and
  artifact validation, and Android build/test jobs. Web publication depends only
  on shared and web gates. Android failure/delay must not block web; shared
  failures still block both. Preserve the existing iOS check outside first-release
  promotion gates. Promote Android through its testing track before production.
- Preserve local browser E2E verification under the current agent guide. Run it
  against the exact candidate artifact as release evidence; moving it into CI
  is a separate workflow decision. Pin the generator as well as Flutter.
- Use this first release smoke matrix:

  | Target | Required baseline |
  | --- | --- |
  | Android real device | Samsung Galaxy S26 on Android 16 |
  | Android lower bound | An emulator or device at the numeric `minSdk` resolved by the Flutter/package dependency set |
  | Web lower bound | The lowest tested versions of each supported engine that pass startup, media, auth, and persistent-storage checks; record actual Wasm or JavaScript execution and exact versions in release evidence (D3) |
  | Web current stable | Current stable Chrome, Edge, Firefox, and Safari versions, in addition to the lower-bound matrix |

- Distinguish Wasm build compatibility from runtime support. Flutter's
  [Wasm build includes a JavaScript fallback](https://docs.flutter.dev/platform-integration/web/wasm).
  Preserve and test both outputs until D3 changes that policy. Record browser
  OS as well as engine; a browser brand alone is insufficient. If durable storage
  is unavailable, explain the upload limitation before accepting an offline pin.
  Native iOS scope does not by itself decide whether mobile Safari is supported.
- Keep production configuration explicit and validated at startup. Add a
  staging environment and smoke-test tenant later if the release process
  requires them.
- Keep operational diagnostics minimal and redacted.
- Add release version checks, artifact retention, rollout ownership, and a
  rollback procedure.
- Keep any operational diagnostics free of sensitive payloads.

## Testing strategy

Test behavior at the narrowest useful boundary.

| Test level | What belongs there |
| --- | --- |
| pure Dart unit | validators, value objects, sorting/filtering, retry decisions, mappers, use cases |
| data tests | Drift queries and migrations, repository cache policy, fake remote errors, outbox recovery |
| controller tests | state transitions, command locking, refresh, retry, and one-shot effects |
| widget tests | screen states, user actions, route arguments, accessibility semantics, reusable UI |
| integration tests | restore session, login/logout, offline upload and retry, account deletion, deep links, permissions |
| contract tests | generated client stays synchronized with `api/openapi.yaml`; error/status mapping stays compatible |

Critical paths need failure tests, not only success tests. At minimum, cover
invalid credentials, expired access tokens, invalid refresh credentials,
transient network failure, empty local data, stale cache, duplicate upload,
logout during sync, denied permissions, and app restart with a pending upload.

CI should eventually enforce:

- generated API diff checks
- formatting with `dart format --set-exit-if-changed`
- analyzer and lint rules
- unit, data, controller, widget, and integration suites appropriate to the
  changed area
- Android and web release compilation for the first production scope
- dependency and license review
- no secrets or unredacted sensitive values in logs or artifacts

Do not choose a coverage percentage before collecting a baseline. Set targets
per critical flow after Phase 1, then raise them as each vertical slice moves.

## Production readiness checklist

The app is ready for a production release when all of these are true:

### Architecture

- Screens depend on controllers and domain models, not API clients, Drift, or
  repositories.
- Domain code runs without Flutter bindings.
- Generated API and Drift code stay behind data boundaries.
- Every feature has an identified source of truth and cache policy.
- New cross-layer imports fail review or an automated architecture check.

### Reliability

- Session restore, refresh, expiration, logout, and account deletion are
  deterministic and tested.
- Sync is serialized, awaited, idempotent, observable, and restart-safe.
- Offline uploads survive restart and have a visible retry/failure state.
- Database migrations are tested from the previous shipped schema.
- Plugin permissions and lifecycle failures show controlled states.
- Network requests have timeouts, bounded retries, cancellation, and typed
  errors.

### Security and privacy

- Android refresh credentials use secure storage; web credentials follow the
  explicitly selected browser session model. Access tokens are never logged.
- Production logs redact request headers, bodies, image data, and PII.
- Product analytics and third-party crash reporting are not part of the
  production client.
- Build configuration contains no credentials.
- Account-owned data and image caches are cleared or retained according to an
  explicit account policy.

### Privacy and diagnostics

The production client does not include product analytics or third-party crash
reporting. Keep operational diagnostics minimal and redacted, and follow the
applicable privacy and data-retention requirements.

Never send image contents, precise coordinates, credentials, headers, or raw
API payloads to diagnostic services.

### User experience and performance

- All user-facing strings are localized or deliberately marked as
  non-localized system content.
- Screens expose loading, empty, error, and retry states.
- Map and feed rendering do not rebuild or fetch more work than needed.
- Image memory and disk caches have measured bounds.
- Key interactions have accessibility labels, focus behavior, and adequate
  contrast.

### Release operations

- Android and web artifacts build from pinned toolchains.
- Production configuration is explicit and validated at startup. If staging
  is introduced, its configuration is separate.
- A smoke test runs against the release artifact.
- Server availability/API failure alerts and support reports have an owner.
  Do not assume automatic client crash alerts while third-party crash reporting
  is excluded; use reproducible local diagnostics and user-initiated reports.
- Versioning, rollout, rollback, and data-migration procedures are written
  down.

## Proposed performance acceptance criteria

These are starting budgets for decision D5, not measured results or confirmed
product requirements. Measure release/profile builds, never debug builds.
Record OS/browser, refresh rate, fixture size, cache state, network profile,
and at least 30 repeat runs for latency percentiles.

| Experience | Proposed gate |
| --- | --- |
| Map and feed | At least 95% of frames within one refresh interval during a 60-second pan/scroll with 500 visible pin records and 100 feed items; no marker blanking on metadata updates |
| Cached startup | p95 at most 2 seconds to usable cached screen on S26; record network bootstrap separately |
| Cold web startup | p95 at most 5 seconds to usable shell on a fixed 10 Mbps / 100 ms RTT profile; remote data readiness measured separately |
| Upload recovery | While active, start a due attempt within 5 seconds of session/network recovery when no server backoff applies; no completion deadline under arbitrary network or OS scheduling |
| Storage | Provisional queue ceiling of 100 items or 250 MiB, whichever comes first; decide image normalization limits from server constraints before implementation |

Repeat map/feed measurements on a representative constrained Android device;
an API-minimum emulator verifies compatibility, not real-device performance.
Measure image-cache memory and disk use before choosing eviction budgets. D5
must identify the lower-performance device and browser hardware used for gates.

## Remaining decisions

Previously recorded constraints remain: Android/web first, durable uploads,
no edit/cancel/discard workflow, coordinated Go/API evolution, independent web
and Android promotion, direct production web deployment, no product analytics
or third-party crash reporting, and unchanged privacy requirements. The optional
`Idempotency-Key` header remains the approved server direction. The Samsung
Galaxy S26 / Android 16 remains the first Android test target.

The following need explicit answers. Recommendations are proposals only; an
unanswered decision is not approval. Resolve each before its dependent slice,
without blocking independent documentation and existing-behavior fixes.

| ID | Decision and concrete question | Proposal / consequence | Needed before |
| --- | --- | --- | --- |
| D1 | Must Android upload while the app is closed, or only while active and on next launch? Is OS-delayed execution acceptable? | WorkManager retries when permitted, next-launch recovery always; web active/next-launch only | Worker feasibility spike and outbox scheduling |
| D2 | How long may an unsent photo survive? Does logout still erase it? Is automatic deletion after permanent failure/expiry acceptable, with only a visible failure notice? | Propose 7-day queue lifetime, preserve the existing erase-on-logout policy pending an explicit change; agree server delay/skew allowance, terminal-notice retention, and whether every late replay must be rejected | Outbox schema, deletion UX, and server retention migration |
| D3 | Should a browser that passes storage and behavior tests be supported through JavaScript fallback? Is mobile Safari included despite native iOS being out of scope? | Keep the tested fallback; publish an OS/engine/runtime matrix rather than require native Wasm everywhere | Browser support promise and release matrix |
| D4 | May web refresh credentials remain accessible to app JavaScript, or should the server use an HttpOnly cookie? Can web and API be served under one origin? | Prefer same-origin HttpOnly refresh cookie if deployment supports it; retain Android bearer flow | Auth slice and deployment contract |
| D5 | Which performance failures block release first: map, startup, feed, or upload recovery? Which constrained device and browser hardware are available? Are the proposed queue limits acceptable? | Prioritize map/media stability; baseline the proposed budgets above before accepting them | Performance gate and storage limits |
| D6 | Who owns production smoke evidence, alerts, and rollback, and what is the maximum acceptable rollback time? | Identify one named release owner and backup; preserve idempotency and schema compatibility during rollback | Independent publication/promotion changes |

The first useful delivery is the Phase 1 gap audit plus lifecycle/account cleanup,
followed by composition-root/auth work and the server-backed upload slice. Move
one behavior and its tests per pull request; keep the app working after each
slice. Directory completion alone is not a release gate.
