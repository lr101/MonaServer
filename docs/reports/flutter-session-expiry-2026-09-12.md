# Flutter session-expiry slice verification — 2026-09-12

Implemented the next composition-root increment from
[the architecture plan](../../flutter/ARCHITECTURE.md): explicit post-bootstrap
session status, terminal refresh rejection, durable expiry, safe reauthentication
and an owned reactive router. Auth remains in the legacy service pending its
feature-layer migration.

## Behavior

- Refresh endpoint 401/403 or missing access credentials reject that token
  manager once. Concurrent/queued refresh attempts cannot reuse rejected
  credentials; transient failures retain the session and can recover.
- Expiry revokes the account query/session fence, preserves identity and drafts,
  persists an expiry marker and attempts secure-token deletion. Restoration
  suppresses marked credentials even when secure-token deletion failed.
- Login shows an expiry notice. Reauthentication to the same account retains
  drafts, including when credential writes fail; switching accounts awaits
  destructive cleanup. Successful login clears the expiry marker only after
  credential writes succeed.
- The router observes status changes without recreation and disposes its router
  and refresh notifier. Its former import path remains a compatibility export.

## Verification

- Flutter 3.47.3 / Dart 3.13.3 from the pinned mise toolchain.
- `mise run flutter-test`: **203 passed**, including 17 new regression tests.
- `mise run flutter-analyze`: completed with **40 existing informational
  findings**, none introduced by this slice.
- Full `dart run build_runner build`: completed. Only the two affected Riverpod
  source-hash changes were retained; unrelated generated changes were restored.
- Release web build with `API_HOST=http://127.0.0.1:8081`: passed.
- `flutter/docker/test_web_build.sh flutter/build/web`: passed; Wasm/SkWasm and
  JavaScript/CanvasKit artifacts are present.
- Chromium 153.0.8010.12: **all five E2E scenarios passed in one final run**:
  login/logout, refresh rejection/reload/reauthentication, joined groups, public
  group pin/image loading and web camera access.
- A browser probe confirmed IPv6 loopback and byte-matched the served Wasm to
  this checkout's final build. Chromium loaded the Wasm/SkWasm target.
- Tests were observed failing before implementation, including failed secure
  deletion/restart and error-typing regressions from review. The new browser
  test failed against the previous build by remaining on Home after rejection,
  then passed against the implementation.
- Independent review: persistence finding fixed and rechecked; no remaining
  concrete findings. `git diff --check` passed.

## Environment and limits

Reused native PostgreSQL/PostGIS on port 5432, Go API on 8081, RustFS on 9100,
and the disposable fixture created for the previous slice. The other worktree's
IPv4 port 4173 server was left untouched. Tests used a separate IPv6 loopback
server with a local Playwright configuration pinning `localhost` to `::1`.
The owned server was stopped after verification; existing backend services
remain running. Fixture credentials and temporary test configuration are ignored.

JavaScript fallback was checked as an artifact, not executed. No Android device,
native camera, Firebase initialization or iOS validation was performed. The
existing `flutter_login` widget triggers a Flutter debug ListTile assertion;
login/expiry presentation was verified in the real release browser flow.

A unified session repository, observable restoring UI, owned app/sync lifecycle,
platform ports, durable uploads and broader storage/retention validation remain
future slices. If both local persistence stores fail, only in-memory expiry can
be guaranteed until storage becomes available; rejected credentials still cannot
be reused by the active token manager.
