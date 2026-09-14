# Merge and UI exploration — 2026-09-10–11

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

- **Fixed:** during logout, still-mounted widgets rebuilt the coalescer after
  credentials were cleared and sent anonymous batch requests (401). The
  coalescer now rejects signed-out reads before transport. A regression test
  proves signed-in reads work, signed-out reads send nothing, and a new session
  resumes reads.
- **Fixed test interaction:** immediate browser text entry could lose the first
  password character or the username when Flutter's editing client attached
  after DOM focus. The test now focuses the field, allows the editor to attach,
  types through keyboard events, and verifies the value before submitting.
  The focused logout/relogin test passes, including a full reload.

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
- Flutter: 156 tests passed; release Wasm/JavaScript build passed. Analyzer
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

The final isolated Playwright run completed with **4 passed, 0 skipped** in
1.2 minutes: logout/relogin (including a full reload), login/group rendering,
public-unjoined group search/gallery, and camera capture chooser. All seven
Node test-harness tests passed. The browser error assertions passed for every
flow. Earlier failures were investigated and addressed as described above.

## Security check investigation

GitGuardian was green at `329b184` and turned red after the merge. Its GitHub
check reports one secret across the PR history but exposes no file/line
annotations; its details link requires the GitGuardian dashboard.

A local Gitleaks 8.30.1 scan of `329b184..HEAD`, with all values redacted, found
one match: `generic-api-key` in `go-server/internal/gen/api/api.gen.go:413` in
upstream commit `4fe7790`. This is the generated `UserUpdateResponseDto` example:
the sample refresh token equals the sample user ID and is the same placeholder
UUID repeated 73 times in the OpenAPI contract. That local finding is a
documentation false positive, not a credential. It plausibly explains the
GitGuardian failure, but that cannot be confirmed without GitGuardian's own
finding details. No scanner bypass or history rewrite was added.
