# Separate web admin implementation plan

Status: amended 2026-09-23 to add simple campaign CRUD while keeping campaign
delivery out of scope. Repository realignment, the standalone UI, and bounded
server projections are implemented. Audience expansion, provider delivery,
workers, retries, and bulk execution remain intentionally excluded.

## Current implementation state

- Complete: Flutter admin composition, screens, tests, entry points, and
  admin-specific build artifacts are removed.
- Complete: the Go admin session boundary, authorization, database services,
  user/report/audit projections, and report review mutations remain in place.
- Complete: `admin-web/` has a dependency-free static CRUD application with
  bootstrap, restore, password/MFA flow, logout, CSRF handling, users,
  reports and notes, campaigns, permission-filtered audit history, cursor paging, typed
  error states, contract tests, and Docker packaging/CI.
- Complete: campaign persistence, API, authorization, and admin-web CRUD
  screens are implemented as a bounded resource with draft/active/archived
  lifecycle states, revision checks, CSRF, and capability enforcement.
- Deliberately excluded: audience snapshots, campaign sends, test delivery,
  job workers, provider adapters, lease fencing, and bulk action execution.

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
- Campaigns are content records only in this release. CRUD owns name, channel,
  subject/title, body, lifecycle status, and revision; it does not enqueue or
  deliver messages. A later delivery feature may consume active campaigns.
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

### 4. CRUD feature slices — complete

Implement each slice against the generated OpenAPI examples and server DTOs:

1. bounded users search and user detail;
2. report inbox, detail, revision-checked status/assignment updates, and
   notes;
3. campaign list/detail/create/update/archive/delete with revision checks;
4. permission-filtered audit history.

The browser keeps authorization and validation server-owned, renders bounded
server data safely, and treats report conflicts as reload-and-reapply rather
than overwriting newer state.

### 5. Server-side CRUD boundary — complete

The Go server exposes the existing session, users, reports, report notes, and
audit projections behind the admin middleware. Campaign records are stored and
mutated behind the same session, CSRF, capability, and revision checks. Bulk
audience/action execution is out of scope and remains unavailable; no provider
or worker is needed for campaign CRUD.

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

Complete `admin-web/src/api.js` for the session, users, reports, report notes,
and audit operations. Preserve cookies, CSRF rotation, bounded query
parameters, and typed HTTP failures. Add Node/browser contract tests for
request methods, headers, body binding, and error handling.

### Task 2 — session shell and navigation

Complete the session bootstrap, restore, login/MFA, logout, expiry, capability
states, responsive shell, and page state transitions. Keep all credentials and
CSRF values in memory. Add contract tests for 401, 403, CSRF rotation, and
authenticated navigation.

### Task 3 — users and reports

Implement bounded user search/detail and report inbox/detail workflows. Add
revision-checked report transitions, notes, and assignment tri-state. Render
server errors without exposing secrets and add focused browser tests.

### Task 4 — audit and CRUD integration

Implement permission-filtered audit history, report conflict handling, and
same-origin CRUD integration. Do not add audience composition, campaign sends,
test delivery, job controls, provider adapters, or worker lifecycle.

### Task 5 — campaign server CRUD — complete

Add a `campaigns` table and bounded repository/service/handler methods for
list, detail, create, update, archive, and delete. Use a small resource shape:
name, channel (`email` or `push`), subject/title, body, status (`draft`,
`active`, or `archived`), revision, timestamps, and creator. Require
`campaigns.read` for reads and `campaigns.write` for mutations. Enforce
field limits, revision checks, and archival semantics without introducing
audience expansion, provider calls, or durable jobs.

### Task 6 — campaign admin-web CRUD — complete

Add matching admin-web list/detail/editor flows and API contract tests. The
browser must never claim that saving a campaign sends it.

### Task 7 — explicit non-goal boundary — complete

Keep bulk execution routes fail-closed and document the boundary. No durable
job worker, provider delivery, lease/fence state machine, or campaign action
should be added to complete this CRUD release.

### Task 8 — integration and delivery verification — complete

Regenerate checked-in outputs, run Go and Flutter consumer checks, run the
admin-web checks and Docker smoke workflow locally when Docker is available,
validate the same-origin gateway path when the local gateway is available,
and perform a whole-branch review.

## Explicit non-goals

- Do not add admin routes to the consumer Flutter router.
- Do not reuse consumer auth/storage/sync/camera/Firebase dependencies.
- Do not duplicate the Go authorization or audience eligibility rules in the
  browser.
- Do not expose or claim provider delivery, campaign execution, or job
  completion from the CRUD application.
