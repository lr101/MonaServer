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

## Fix round 2 — production-safe unnamed filter construction

Base: `57c838e`.

The unnamed const-compatible constructor now normalizes legacy account
criteria tagged with `resource: reports` back to the valid accounts resource;
it no longer relies on an assertion, so non-const production callers cannot
retain invalid report/account state. The existing `copyWith` transition and
resource-specific report criteria behavior remains unchanged.

### Verification

The independently rerun combined command and output were:

```text
mise exec -- dart format lib/features/admin_audience/domain/admin_audience_models.dart test/features/admin_audience/admin_audience_selection_test.dart && mise exec -- flutter test --no-pub test/features/admin_audience/admin_audience_selection_test.dart test/features/admin_audience/admin_audience_confirmation_test.dart && mise exec -- dart analyze lib/features/admin_audience/domain/admin_audience_models.dart test/features/admin_audience/admin_audience_selection_test.dart && git -C .. diff --check
PASS — formatting unchanged
PASS — 26/26 tests; All tests passed!
PASS — dart analyze exit 0; 6 existing info diagnostics, with no warnings or errors
PASS — git diff --check
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

## Fix round 3 — account-scoped unnamed filter construction

Base: `4d53f9c`.

Removed the `resource` parameter from the unnamed const-compatible
`AdminAudienceFilter` constructor, so it always constructs an account filter.
Report filters are constructed only through `AdminAudienceFilter.reports(...)`.
The existing `copyWith` cross-resource rejection and immutable, bounded report
criteria remain intact.

### Verification

The following combined command ran from `flutter/` in this worktree and
returned exit code 0:

```text
mise exec -- dart format lib/features/admin_audience/domain/admin_audience_models.dart test/features/admin_audience/admin_audience_selection_test.dart && mise exec -- flutter test --no-pub test/features/admin_audience/admin_audience_selection_test.dart test/features/admin_audience/admin_audience_confirmation_test.dart && mise exec -- dart analyze lib/features/admin_audience/domain/admin_audience_models.dart test/features/admin_audience/admin_audience_selection_test.dart && git -C .. diff --check
Formatted 2 files (0 changed) in 0.02 seconds.
00:00 +27: All tests passed!
Analyzing admin_audience_models.dart, admin_audience_selection_test.dart...
info - test/features/admin_audience/admin_audience_selection_test.dart:285:20 - The value of the argument is redundant because it matches the default value. Try removing the argument. - avoid_redundant_argument_values
info - test/features/admin_audience/admin_audience_selection_test.dart:304:33 - The value of the argument is redundant because it matches the default value. Try removing the argument. - avoid_redundant_argument_values
info - test/features/admin_audience/admin_audience_selection_test.dart:313:33 - The value of the argument is redundant because it matches the default value. Try removing the argument. - avoid_redundant_argument_values
info - test/features/admin_audience/admin_audience_selection_test.dart:324:33 - The value of the argument is redundant because it matches the default value. Try removing the argument. - avoid_redundant_argument_values
info - test/features/admin_audience/admin_audience_selection_test.dart:333:33 - The value of the argument is redundant because it matches the default value. Try removing the argument. - avoid_redundant_argument_values
info - test/features/admin_audience/admin_audience_selection_test.dart:353:53 - The value of the argument is redundant because it matches the default value. Try removing the argument. - avoid_redundant_argument_values
6 issues found.
```

The focused suite passed 28 tests. The six analyzer infos are existing
`avoid_redundant_argument_values` diagnostics; there were no warnings or
errors. `git diff --check` produced no output and passed.

## Fix round 4 — runtime legacy-constructor regression

Base: `a109fc3`.

Added a runtime API-surface regression for the unnamed constructor. Calling
its real constructor tear-off through `Function.apply` with the removed
`resource: reports` named argument now throws `NoSuchMethodError`. This
distinguishes the current account-only API from `4d53f9c`, whose former
constructor accepted that invocation and returned a report filter. Report
construction remains exclusively `AdminAudienceFilter.reports(...)`; no
production constructor behavior changed in this round.

### Mutation check

The focused test was run against the temporary prior constructor signature,
then the account-only constructor was restored before final verification. The
exact command and output were:

```text
mise exec -- flutter test --no-pub test/features/admin_audience/admin_audience_selection_test.dart --plain-name 'unnamed filters reject the legacy resource argument at runtime'; test_status=$?; test "$test_status" -ne 0
00:00 +0: loading /root/.t3/worktrees/MonaServer/t3code-59827f46/flutter/test/features/admin_audience/admin_audience_selection_test.dart
00:00 +0: unnamed filters reject the legacy resource argument at runtime
00:00 +0 -1: unnamed filters reject the legacy resource argument at runtime [E]
  Expected: throws <Instance of 'NoSuchMethodError'>
    Actual: <Closure: () => dynamic>
     Which: returned AdminAudienceFilter:<AdminAudienceFilter(criteria: false)>

  package:matcher                                                       expect
  package:flutter_test/src/widget_tester.dart 473:18                    expect
  test/features/admin_audience/admin_audience_selection_test.dart 14:5  main.<fn>

00:00 +0 -1: Some tests failed.

Failing tests:
  /root/.t3/worktrees/MonaServer/t3code-59827f46/flutter/test/features/admin_audience/admin_audience_selection_test.dart: unnamed filters reject the legacy resource argument at runtime
```

### Verification

The following command ran from `flutter/` in this worktree and returned exit
code 0:

```text
mise exec -- dart format lib/features/admin_audience/domain/admin_audience_models.dart test/features/admin_audience/admin_audience_selection_test.dart && mise exec -- flutter test --no-pub test/features/admin_audience/admin_audience_selection_test.dart test/features/admin_audience/admin_audience_confirmation_test.dart && mise exec -- dart analyze lib/features/admin_audience/domain/admin_audience_models.dart test/features/admin_audience/admin_audience_selection_test.dart && git -C .. diff --check
Formatted test/features/admin_audience/admin_audience_selection_test.dart
Formatted 2 files (0 changed) in 0.02 seconds.
00:00 +28: All tests passed!
Analyzing admin_audience_models.dart, admin_audience_selection_test.dart...

   info - test/features/admin_audience/admin_audience_selection_test.dart:294:20 - The value of the argument is redundant because it matches the default value. Try removing the argument. - avoid_redundant_argument_values
   info - test/features/admin_audience/admin_audience_selection_test.dart:313:33 - The value of the argument is redundant because it matches the default value. Try removing the argument. - avoid_redundant_argument_values
   info - test/features/admin_audience/admin_audience_selection_test.dart:322:33 - The value of the argument is redundant because it matches the default value. Try removing the argument. - avoid_redundant_argument_values
   info - test/features/admin_audience/admin_audience_selection_test.dart:333:33 - The value of the argument is redundant because it matches the default value. Try removing the argument. - avoid_redundant_argument_values
   info - test/features/admin_audience/admin_audience_selection_test.dart:342:33 - The value of the argument is redundant because it matches the default value. Try removing the argument. - avoid_redundant_argument_values
   info - test/features/admin_audience/admin_audience_selection_test.dart:362:53 - The value of the argument is redundant because it matches the default value. Try removing the argument. - avoid_redundant_argument_values
6 issues found.
```

`git diff --check` emitted no output and passed. The focused suite count is 28
tests; the analyzer returned exit 0 with the six existing informational
diagnostics and no warnings or errors. No services, browser, providers, or
external systems were started or used.
