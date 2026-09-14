# Flutter sync lifecycle slice verification — 2026-09-14

Implemented the owned application/sync lifecycle increment from
[the architecture plan](../../flutter/ARCHITECTURE.md). The existing sync service
remains the metadata/upload worker; a pure Dart coordinator now owns trigger
serialization and an app-root widget owns lifecycle subscriptions.

## Behavior

- Restored sessions and successful login trigger sync explicitly. Resume uses a
  one-minute cooldown between attempts. Watching sync state or rebuilding
  navigation does not initiate requests.
- Concurrent triggers share one run. Session replacement and cache-reset
  restart wait for old work to settle and revoke its follow-up guard. Manual
  refresh bypasses cooldown. Unmount removes lifecycle/session listeners;
  provider-container disposal disposes the coordinator.
- Sync captures provider/account/run guards before asynchronous work and
  checks them before follow-up writes. Late metadata and upload responses
  cannot continue a superseded run.
- Automatic errors are contained; manual callers receive errors. Upload errors
  retain the draft and report failure instead of advancing the sync checkpoint.
  Sync no longer prints raw errors, user IDs or pin payloads.

## Verification

- Pinned Flutter 3.47.3 / Dart 3.13.3.
- `mise run flutter-test`: **220 passed** (17 more than the preceding slice).
  Coverage includes trigger coalescing, cooldown, account replacement, restart,
  disposal, widget lifecycle, real provider/cache-facade rebuilds, stale metadata
  and upload responses, and failure/draft retention without payload logging.
- `mise run flutter-analyze`: **40 existing informational findings**, no new
  diagnostics in the modified sync code/tests.
- Tests for the new coordinator, lifecycle, provider-build behavior, stale
  responses, upload failure and cache restart were observed failing before
  their implementations, then passing.
- Full `dart run build_runner build` completed. The sync provider source hash
  was regenerated; unrelated generated changes were restored. Prior slices'
  generated changes were preserved.
- Final release web build with `API_HOST=http://127.0.0.1:8081`: passed.
- `flutter/docker/test_web_build.sh flutter/build/web`: passed, including
  Wasm/SkWasm and JavaScript/CanvasKit artifacts.
- Chromium 153.0.8010.12 loaded `main.dart.wasm`; a browser probe confirmed
  IPv6 loopback and byte-matched the served Wasm to this checkout's final build.
  Its first attempt activated semantics too early and timed out; using the
  E2E suite's splash/semantics readiness wait resolved the probe.
- Chromium: **all six E2E scenarios passed in one final run**: login/logout,
  expiry/reload/reauthentication, exact sync request counts across login/reload
  and tab navigation, joined groups, public group pins/images and web camera.
- Independent read-only review found no blocking correctness issues. One minor
  follow-up is using monotonic elapsed time for cooldown: a backward device-clock
  adjustment can currently delay an automatic resume attempt.
- `git diff --check`: passed.

## Environment and limits

Used the native local stack: PostgreSQL/PostGIS on 5432, Go API on 8081 and
RustFS on 9100, with the existing disposable fixture. The other worktree's IPv4
port 4173 server was left untouched. Browser checks use this checkout's own IPv6
loopback server and an ignored configuration resolving `localhost` to `::1`.
The owned IPv6 server was stopped after verification; existing backend
services and the other worktree server remain running. Credentials and temporary
browser configuration remain ignored.

The coordinator is in-process only. It cannot cancel an already-started request
or guarantee atomic cancellation of an already-started write. Durable outbox
storage, server idempotency, connectivity triggers, scheduled retry and Android
worker integration remain future slices. The existing HTTP 409 draft-deletion
policy is preserved until that work. Broader typed failures, diagnostics,
platform ports and the unified session repository remain planned.

JavaScript fallback was checked as an artifact, not executed in a browser.
No native device, Android worker, Firebase or iOS validation was performed.
