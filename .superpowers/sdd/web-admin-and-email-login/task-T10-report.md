# T10 — admin Flutter entry point, sessions and shared selection

Status: first admin-web POC complete at the shell and transport-boundary
milestone. Base: `28c078d`.

## Delivered

- Added the independent `lib/main_admin.dart` entry point and `app/admin/`
  composition root. It creates only an admin API adapter, an in-memory session
  controller, and the admin app; it does not reach consumer bootstrap, Drift,
  sync, camera, Firebase, or secure-storage credentials.
- Added an admin session state machine for bootstrap, password challenge, MFA,
  restore, logout, 401 expiry/cancellation, and 403 capability denial. Password
  and MFA fields are cleared after submission and are never persisted or
  included in state diagnostics.
- Added a conditional browser transport using `BrowserClient.withCredentials`
  on web and an owned `http.Client` fallback elsewhere. The adapter injects and
  rotates CSRF values in memory, maps generated admin session/user DTOs into
  domain models, and redacts response bodies from typed failures.
- Added a responsive accessible shell with keyboard-friendly rail/drawer
  navigation, overview, users, reports and jobs destinations. Reports and jobs
  are honest placeholders for T11/T12 integration.
- Added bounded users search, cursor paging, selection persistence across pages,
  stale-search fencing, capability errors, and a user detail stub.
- Added pure selected/filter/all audience models, filter invalidation, frozen
  preview counts/exclusions, expiry handling, and a disabled empty-selection
  confirmation widget. The live audience preview/commit port is intentionally
  left for the T07/T12 integration seam.
- Registered the admin feature layers in architecture checks and added guards
  rejecting consumer session/storage/sync/camera/Firebase imports. Added the
  dedicated `flutter-build-admin-web` task targeting `lib/main_admin.dart` and
  writing `flutter/build/admin_web`.

## Interfaces

`AdminSessionTransport` is the session boundary consumed by
`AdminSessionController`; `AdminUsersRepository` supplies bounded list/detail
queries; `AdminAudiencePreviewPort` is the future server preview seam. The
generated `AdminSessionApi` and `AdminUsersApi` are used only inside
`AdminApiAdapter`.

## Verification

All commands ran from the stated worktree.

```text
mise exec -- dart format flutter/lib/main_admin.dart flutter/lib/app/admin \
  flutter/lib/features/admin_session flutter/lib/features/admin_users \
  flutter/lib/features/admin_audience flutter/test/app/admin_api_adapter_test.dart \
  flutter/test/app/admin_app_test.dart flutter/test/features/admin_audience \
  flutter/test/features/admin_session flutter/test/features/admin_users \
  flutter/test/architecture_test.dart flutter/test/support/architecture_rules.dart
PASS — 27 files checked; the final pass formatted the two newly amended widgets

cd flutter
mise exec -- flutter test --no-pub \
  test/architecture_test.dart test/app/admin_api_adapter_test.dart \
  test/app/admin_app_test.dart \
  test/features/admin_session/admin_session_controller_test.dart \
  test/features/admin_users/admin_users_controller_test.dart \
  test/features/admin_audience/admin_audience_selection_test.dart \
  test/features/admin_audience/admin_audience_confirmation_test.dart
PASS — 28 tests

mise exec -- flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
PASS — exit 0; 86 existing/info diagnostics remain, with no warnings or errors

cd ..
mise run flutter-build-admin-web
PASS — `flutter/build/admin_web` produced by `lib/main_admin.dart` (Wasm)

cd flutter
bash docker/test_web_build.sh build/admin_web
PASS

cd ..
git diff --check
PASS
```

## Availability and limitations

Flutter dependencies were installed by the existing `flutter-setup` task. No
PostgreSQL, Go server, SMTP, FCM, Firebase, or browser Playwright stack was
started, and no external provider was contacted. The generated admin transport
is ready for the T05/T07 backend contracts, but this POC has no live audience
preview/commit adapter. Reports/jobs remain navigation placeholders; CSP,
manifest/hosting staging and admin browser E2E belong to T13. The browser build
was compiled and its static artifact check passed, but no browser interaction
claim is made.

Implementation commit SHA: recorded in the handoff after commit.

## T10 report-audience follow-up

Base: `9b42875`.

Added the pure-Dart report audience seam: domain-owned `open`/`resolved`/
`dismissed` statuses, bounded immutable report types, trimmed optional assignee
IDs, report-aware actionability/copy/equality/hash behavior, and explicit
report scope summaries. Account filters retain their existing criteria and
summary behavior; report-only copy criteria are rejected for account filters.

### Verification

All commands ran from `flutter/` in this worktree.

```text
mise exec -- dart format lib/features/admin_audience/domain/admin_audience_models.dart test/features/admin_audience/admin_audience_selection_test.dart
PASS — 2 files checked; no changes

mise exec -- flutter test --no-pub test/features/admin_audience/admin_audience_selection_test.dart test/features/admin_audience/admin_audience_confirmation_test.dart
PASS — 22 tests

mise exec -- dart analyze lib/features/admin_audience/domain/admin_audience_models.dart test/features/admin_audience/admin_audience_selection_test.dart
PASS — exit 0; 6 existing info diagnostics in unchanged selection-test cases, with no warnings or errors

git -C .. diff --check
PASS
```

No services, browser, providers, or external systems were started or used.

## Fix round 1 — resource-discriminated filter invariant

Base: `b2d7d81`.

The unnamed const-compatible constructor now rejects `reports`, resource
transitions through `copyWith` are rejected, and both account-only and
report-only copy criteria are rejected outside their resource. This prevents
ignored criteria from creating invalid filter state or affecting stale-preview
equality.

### Verification

All commands ran from `flutter/` in this worktree.

```text
mise exec -- dart format lib/features/admin_audience/domain/admin_audience_models.dart test/features/admin_audience/admin_audience_selection_test.dart
PASS — 2 files checked; no changes

mise exec -- flutter test --no-pub test/features/admin_audience/admin_audience_selection_test.dart test/features/admin_audience/admin_audience_confirmation_test.dart
PASS — 26 tests

mise exec -- dart analyze lib/features/admin_audience/domain/admin_audience_models.dart test/features/admin_audience/admin_audience_selection_test.dart
PASS — exit 0; 6 existing info diagnostics in unchanged selection-test cases, with no warnings or errors

git -C .. diff --check
PASS
```
