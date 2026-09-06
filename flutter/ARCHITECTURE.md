# Flutter architecture plan

Status: proposed

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
- Keep access tokens in memory and refresh credentials in secure storage.
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
  Flutter and package constraints. Browser support must include the required
  WebAssembly build capabilities.
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
- The local data path is currently Drift repositories built on a generic cache
  abstraction. The cache uses hashed integer IDs, TTL values, hit counts, and
  keep-alive flags.
- The app already has CI for analysis, Flutter tests, generated API tests, a
  web release build, an Android debug build, and an iOS release build.
- The app test suite currently covers a small number of pure behaviors. The
  important auth, sync, cache, upload, lifecycle, and screen flows still need
  focused tests.

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
- The HTTP refresh path, logout cleanup, group synchronization, feed
  composition, and map/camera lifecycle already have concrete follow-up work
  recorded in the current Flutter follow-up backlog.

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

Repositories and infrastructure are accessed through domain ports and
use-case/controller boundaries. Enforce this rule in review and with an import
lint once the target directories exist.

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

Use cases are appropriate when they encode a policy or coordinate multiple
repositories. Do not create a one-line use case solely to rename a repository
method.

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
sources. The rest of the app should not import `package:openapi/api.dart`.
Similarly, Drift table classes and generated Drift data classes should not
escape local data sources.

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
- `StreamProvider` exposes a repository stream, usually a local database
  observation.
- `AsyncNotifier` owns an asynchronous query or a screen-level mutation.
- `Notifier` owns synchronous local state such as a selected tab or draft
  field.
- Keep-alive is explicit and reserved for app-wide state, durable sessions,
  and long-lived caches.
- Providers should not create unmanaged timers, subscriptions, or network
  requests in `build()`.
- Async commands use `ref.read` after an async gap and check their lifecycle
  before publishing UI state.
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

### Offline pin uploads

Treat an offline upload as a durable outbox item, not as an ordinary cached pin
with `lastSynced == null`.

An outbox record should contain:

- a client-generated operation ID
- an immutable copy of the draft fields and a durable image-store key
- the target group and account ID
- status such as pending, uploading, failed, or completed
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
valid outbox storage. Store the media type, size, and checksum with the image
metadata, and remove the image only after completion, permanent failure, expiry,
or account deletion.

The image write and database insert are coordinated as a recoverable two-step
operation: write the image with an operation-specific key, insert the outbox
row in a transaction, then reconcile unreferenced image files and rows with
missing images at startup. A missing image becomes a typed permanent failure;
an unexpired row in `uploading` state whose lease has expired returns to
`pending`.

Use this state machine:

```text
pending -> uploading -> completed
                    -> pending       (retryable failure or expired lease)
                    -> failed         (permanent failure)
```

The background scheduler claims only due `pending` rows. Claiming must be a
transactional conditional update that sets `uploading`, a unique lease owner,
and a lease expiry, then returns the claimed row. Foreground work and an
Android worker must compete through this same claim, so they cannot upload the
same row concurrently. Completion, retry, failure, and lease extension must
also update the row only when the caller still owns the lease; a stale worker
must discard its result. An expired lease may be reclaimed by a new owner.

Android should use a platform background worker where the package and OS permit
it. Web retries
while the app is active and on the next launch, resume, authentication, or
online transition; do not promise execution while a browser tab is closed
unless the supported browser set and Background Sync behavior are verified.
While a process is alive, schedule the next due attempt without creating an
unmanaged timer in a provider `build()` method.

Because uploads run in the background, the coordinator must pause when there
is no valid session. Under the selected privacy-first policy, logout removes
account-owned pending payloads and image files and stops further sync; a later
login starts a new outbox for that account. Account deletion also removes all
pending local payloads and image files and stops further sync. A token expiry or
transient refresh failure pauses the row without deleting it. No pending item
may reuse credentials from the previous session.

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
Only after that deadline may cleanup remove the row, and the client must expire
the operation ID at the same boundary. This makes the duplicate guarantee
explicitly bounded instead of silently reintroducing it after deletion.

The insert, idempotency state transition, pin creation, and XP update must be
atomic. If an identical request arrives while the first request is processing,
the unique key must make it wait or return a retryable response; it must never
run the mutation twice. The object-storage write is still non-transactional,
so orphan cleanup and an explicit storage failure policy remain necessary.

The server work belongs in a new migration, the named sqlc queries and facade,
the pin service, and the pin handler. Add the optional header to both the
authoring API fragments and the bundled `api/openapi.yaml`, then regenerate
the Go and Dart clients. The fragment currently documents a `201` create
response while the bundled contract says `200`; reconcile that mismatch in
the same contract change before generation.

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
- `SecureTokenStore` persists only the refresh credential and account identity
  required to restore a session.
- `AuthInterceptor` supplies the in-memory access token.
- One refresh operation is shared by concurrent requests.
- A 401 triggers one refresh and one replay. A failed refresh clears the
  session and routes to sign-in. A transient refresh failure returns a retryable
  failure without silently replaying an old token.
- A 403 is treated as an authorization/domain error unless the backend
  contract explicitly says otherwise.
- Request and response logs redact tokens, image data, credentials, and
  personal data. Production code must not log every request.
- Every client and stream subscription has an owned lifecycle and a clear
  disposal path.

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
| `data/service/pin_service.dart` | `features/pins` and `features/sync` | separate pin queries, upload commands, and UI feedback |
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
- Resolve the remaining decisions below, especially the performance budget and
  the maximum outbox/idempotency retention period.
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

Use the existing six-task Flutter follow-up plan as the starting backlog:

1. clear account-owned local data on logout and account deletion
2. scope profile pin fetching to the requested user
3. fix feed sliver composition and image-grid loading
4. make group synchronization idempotent and awaited
5. make authentication refresh and HTTP client lifecycle explicit
6. make map and camera lifecycle behavior safe

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

- Introduce the durable upload outbox.
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
  deletion, and account-scoped data.

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
- Keep web deployment independent from Android build duration. Promote Android
  through its testing track before production release.
- Use this first release smoke matrix:

  | Target | Required baseline |
  | --- | --- |
  | Android real device | Samsung Galaxy S26 on Android 16 |
  | Android lower bound | An emulator or device at the numeric `minSdk` resolved by the Flutter/package dependency set |
  | Web lower bound | The lowest tested Chrome, Edge, Firefox, and Safari versions that pass the Flutter WebAssembly build and persistent-storage smoke test; resolve and record exact versions in CI |
  | Web current stable | Current stable Chrome, Edge, Firefox, and Safari versions, in addition to the lower-bound matrix |

- Treat browsers that cannot run the WebAssembly build or required persistent
  storage as unsupported and show a controlled compatibility message.
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

- Refresh credentials use secure storage and access tokens are never logged.
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
- Crash and API failure alerts have an owner.
- Versioning, rollout, rollback, and data-migration procedures are written
  down.

## Remaining decisions

The following constraints are confirmed: Android and web are first-class;
support targets are the lowest versions allowed by the packages; browsers must
support the WebAssembly build; durable offline pin uploads are a main feature;
uploads run in the background without edit/cancel/discard actions; the first
Android test target is a Samsung Galaxy S26 running Android 16;
the Flutter client and Go server may evolve together; web currently deploys
directly to production; Android goes through testing before production; and
current privacy and data-retention requirements remain unchanged. The
optional `Idempotency-Key` header is the approved server direction.

Please confirm these implementation details:

1. Which performance budget should drive the first release: startup, map
   interaction, feed scrolling, or upload completion? The S26 is the initial
   test device. The numeric Android `minSdk` and browser lower bounds are
   resolved from the locked Flutter/package set and the WebAssembly storage
   smoke matrix in Phase 0, then recorded as release inputs.
2. What maximum lifetime should a pending offline upload have? Set this as a
   privacy-reviewed product constant. The server's idempotency tombstone must
   cover that full client lifetime plus the maximum accepted request delay;
   account deletion remains immediate and is not delayed by this retention.

The recommended delivery remains small, reviewable pull requests with a
working app after each vertical slice.
