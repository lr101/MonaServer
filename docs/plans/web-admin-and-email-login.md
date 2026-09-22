# Separate web admin implementation plan

Status: amended 2026-09-22 by the product decision to keep the admin interface
out of Flutter. Repository realignment and the standalone UI feature slices
are implemented; provider-backed Go execution remains deliberately fail-closed
pending its durable worker/provider prerequisites.

## Current implementation state

- Complete: Flutter admin composition, screens, tests, entry points, and
  admin-specific build artifacts are removed.
- Complete: the Go admin contract, session boundary, authorization, database
  services, and structural safety work remain in place.
- Complete: `admin-web/` has a dependency-free static application with
  bootstrap, restore, password/MFA flow, logout, CSRF handling, users,
  reports, audience previews, campaigns/security actions, jobs, recipients,
  audit views, cursor paging, typed error states, contract tests, and Docker
  packaging/CI.
- Remaining: production provider/lease/audit execution wiring in Go. The web
  UI correctly exposes accepted/unavailable states without pretending that a
  disabled provider-backed mutation completed.

## Decision

The consumer Flutter application remains consumer-only. The admin interface is
a sibling application at `admin-web/`, next to `flutter/` and `go-server/`.

The first implementation uses plain HTML, CSS, and browser JavaScript modules.
This is the best fit for the current scope: it keeps the bundle small, avoids a
second framework/runtime, works with the existing API contract, and can be
served by the existing gateway or any static-file host. A framework may be
introduced later only if the UI complexity justifies it.

## Boundaries

- `api/openapi.yaml` remains the wire-contract authority.
- `go-server/` retains the admin session, authorization, audience, report,
  audit, and job services. Generated Go output remains generated.
- `flutter/` retains the consumer app, its existing architecture, and the
  generated API contract package. Admin Flutter composition, screens,
  controllers, tests, entry points, and admin-specific web build hooks are
  removed.
- `admin-web/` owns browser state, API mapping, forms, navigation, and admin
  presentation. It must not import Flutter or consumer app code.
- The browser uses the opaque admin cookie and in-memory CSRF token. It never
  stores consumer JWTs, refresh credentials, passwords, MFA codes, or action
  tokens.

## Implementation phases

### 1. Repository realignment

Completed in this change:

- Removed the Flutter admin POC and the later Flutter admin feature slices.
- Removed the Flutter admin web artifact/build hooks.
- Removed the old SDD task reports/review handoffs for this plan.
- Kept the OpenAPI admin contract and Go-side service/database architecture.

### 2. Static application foundation — scaffold complete

Create:

```text
admin-web/
  index.html
  README.md
  src/
    api.js       # fetch boundary, CSRF, cookies, typed HTTP failures
    state.js     # session and page state
    main.js      # composition, navigation, rendering, event handlers
    styles.css
  Dockerfile     # nginx static runtime image
  nginx.conf     # SPA fallback and static-container boundaries
```

Add a root `mise` check that syntax-checks the JavaScript modules without
introducing a package manager. The app is served same-origin or behind a
reverse proxy that maps `/api` to the Go server.

The initial files, `admin-web-check` task, nginx image, and dedicated CI
Buildx/smoke-test workflow are implemented. Add focused browser/contract tests
before expanding the feature surface.

### 3. Session and shell — complete

The initial implementation covers bootstrap, restore, password login, MFA
completion, logout, session expiry, CSRF rotation, and a responsive shell.
Capability-specific rendering, action-bound reauthentication, and explicit 403
states are implemented. All secrets remain in current-page memory. A 401
clears the local CSRF value and returns the user to login.

### 4. Feature slices — complete

Implement each slice against the generated OpenAPI examples and server DTOs:

1. bounded users search and user detail;
2. report inbox, revision-checked updates, notes, assignment tri-state, and
   report audience preview/confirmation;
3. campaign/security audience selection, preview binding, stable idempotency,
   and queued-job messaging;
4. job list/detail/recipient progress, retry and cancellation warnings;
5. permission-filtered audit history.

The browser treats `202` as accepted/queued, never completed. Server action and
payload bindings are authoritative; pending previews cannot invent counts or
actions. Replayed job commands reuse the same idempotency key for that logical
operation.

### 5. Go execution completion

The current production composition intentionally fails action mutations closed
until concrete provider, eligibility, fenced lease, and audit execution ports
are wired. Complete this separately by:

- wiring provider adapters and recipient re-checks;
- wiring durable lease/fence/audit transitions;
- enabling production mutation routes only after those ports are present;
- running disposable PostgreSQL/PostGIS verification for snapshot, job,
  idempotency, report-date, and recipient-device-count behavior.

Read-only admin projections and report review remain usable independently.

### 6. Verification and delivery

- `admin-web`: JavaScript syntax check, contract-focused browser tests, and
  same-origin static serving check; CI also builds the nginx image and curls
  its health, entrypoint, module, fallback, and security-header paths;
- Go: generated API/DB outputs, format, vet, unit tests, and disposable DB
  tests for database behavior;
- Flutter: consumer-only analyzer/tests/build, with no admin target;
- browser validation through the native preview/gateway when available.

## Execution tasks

### Task 1 — browser transport and contract tests

Complete `admin-web/src/api.js` for every v3 admin operation, including
reauthentication, report notes, audience reads, test messages, and job retry or
cancellation. Preserve cookies, CSRF rotation, bounded query parameters,
idempotency keys, 202 semantics, and typed HTTP failures. Add Node/browser
contract tests for request methods, headers, body binding, and error handling.

### Task 2 — session shell and navigation

Complete the session bootstrap, restore, login/MFA, logout, expiry, capability
states, responsive shell, and page state transitions. Keep all credentials and
CSRF values in memory. Add contract tests for 401, 403, CSRF rotation, and
authenticated navigation.

### Task 3 — users and reports

Implement bounded user search/detail and report inbox/detail workflows. Add
revision-checked report transitions, notes, assignment tri-state, and explicit
report audience preview/confirmation. Render server errors without exposing
secrets and add focused browser tests.

### Task 4 — audiences, campaigns, jobs, and audit

Implement selected/filter/all audience construction, preview binding and
confirmation, campaign/security actions, stable idempotency keys, queued-job
messaging, job detail/recipient progress, retry/cancel warnings, and filtered
audit history. Keep action authorization and eligibility server-owned.

### Task 5 — Go execution readiness

Complete concrete provider, eligibility, durable lease/fence, and audit wiring
where repository interfaces and local implementations exist. Keep unavailable
provider mutations fail-closed, verify idempotency and stale-worker behavior,
and add serial disposable-database coverage for changed SQL.

### Task 6 — integration and delivery verification

Regenerate checked-in outputs, run Go and Flutter consumer checks, run the
admin-web checks and Docker smoke workflow locally when Docker is available,
validate the same-origin gateway path, and perform a whole-branch review.

## Explicit non-goals

- Do not add admin routes to the consumer Flutter router.
- Do not reuse consumer auth/storage/sync/camera/Firebase dependencies.
- Do not duplicate the Go authorization or audience eligibility rules in the
  browser.
- Do not claim provider delivery completion from an HTTP acceptance response.
