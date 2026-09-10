# Merge and UI exploration — 2026-09-10

PR #495 (`perf/request-batching`) merged `origin/develop` at `4fe7790`.
The sole conflict was the embedded/generated Go API specification. Regenerating
it from the merged contract preserved `/api/v3/batch` and develop's removal of
legacy object-storage migration fields. Merge commit: `4364ed1`.

## Environment and coverage

Tested the merged branch's release Flutter Wasm build in Chromium, with its own
Go API on loopback port 8081, disposable native PostGIS database
`mona_ui_merge`, and RustFS on port 9100 with wildcard CORS. The web app used
port 4173 and direct API/storage requests. No reverse proxy was involved.
The collaborative browser host and this branch's external preview launcher were
unavailable, so testing used the repository's documented local Playwright stack.

Fixtures included three users, joined/public-unjoined/private/empty groups,
five baseline pins and 45 additional viewer pins in the joined group.

## Findings and changes

- **Fixed:** whole-number API coordinates (for example longitude `8`) decoded
  as integers and failed `as double` casts in `PinEntity.fromDto`. Startup sync
  raised an exception, the feed/profile appeared empty, and group galleries
  displayed “Unable to load images.” Numeric conversion now accepts integer
  and fractional coordinates. A regression test failed before the fix and
  passed afterward.
- **Updated browser check:** the public-unjoined gallery test required individual
  pin-image API calls, although metadata and batching now supply image URLs.
  It checks successful object downloads and the rendered gallery count instead.
- **Remaining finding:** fixture users without uploaded avatars received storage
  404s for profile-image URLs. Adding avatars to those local fixture accounts
  allowed the other flows to be tested. The missing-avatar behavior is not fixed
  by this PR's follow-up.
- Direct cross-origin authenticated API requests still generate successful
  OPTIONS preflights. Wildcard storage CORS permits direct image loads; it does
  not eliminate API preflights.

- **Remaining finding:** the isolated logout/relogin browser regression timed
  out returning to the home route and recorded two HTTP 401 errors. A batch
  request returned 401 during that flow in the API logs. The cause has not been
  established; do not treat session reuse across logout as verified.

## Limits

The map displayed its empty “Unknown Region / No ranking data available” state:
this disposable database has no administrative geography dataset. Populated
regional leaderboards were not verified. Browser camera verification exercises
the capture chooser, not a physical device. These checks do not verify deployed
TLS, production storage policy, email, or push notifications.

## Verification evidence

- Go package checks, full unit suite, and `go vet ./...`: passed.
- Fresh database-backed Go suite (`-count=1 -p 1 ./...`), using separate
  disposable database `mona_merge_checks`: passed.
- Flutter: 155 tests passed; release Wasm/JavaScript build passed. Analyzer
  completed with no errors under the repository's nonfatal warning/info policy
  (41 warnings/information messages).
- Exploratory joined-group gallery and profile: all 47 distinct pin images
  downloaded once; zero extra requests when returning to the gallery's top;
  two batch calls with three successful items; no browser errors or HTTP failures.
- Exploratory feed, groups, profile and scrolling: 46 pin downloads, 11 batch
  calls with 13 successful items, no browser errors or HTTP failures. Small
  one-item batches still occurred while slowly scrolling the feed, so batching
  does not collapse every subsequent viewport into a single request.

The image fixtures are one-pixel PNGs: these checks validate loading, pagination,
and caching, not photographic rendering quality.

The final isolated Playwright run completed with **3 passed, 1 failed**:
login/group rendering, public-unjoined group search/gallery, and camera capture
chooser passed; logout/relogin failed. All seven Node test-harness tests passed.
The search interaction now clicks the input before filling it, allowing
Playwright's stability checks to settle the Flutter route transition.

## PR status

The merge and coordinate fix are pushed to PR #495 (fix commit `645f085`).
GitHub reports the PR as mergeable. At the audit handoff, build checks were
running and GitGuardian reported one secret across the PR history. The GitHub
check exposed no file/line annotations; its details link points to the
GitGuardian dashboard. That finding remains unresolved and is not evidence
that the coordinate fix introduced a credential.
