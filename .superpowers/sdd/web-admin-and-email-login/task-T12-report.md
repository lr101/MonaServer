# T12 report — Admin communication, security actions, jobs, and audit UI

## Scope delivered

- Added pure-Dart domain models and ports plus presentation controllers/screens
  for campaigns, security actions, jobs, and audit history under the four T12
  feature directories.
- Campaigns support email, push, and login-link drafts; explicit selected,
  filtered, or all-account audiences; frozen preview counts/exclusions; a
  single-recipient safe test-send result; confirmation; stale-preview refusal;
  concurrent-commit coalescing; and a stable per-preview idempotency key for
  uncertain commit retries.
- Security actions require a reason and recent MFA, require a separate
  acknowledgement for administrator inclusion, support revoke/compromise/
  recovery resend, and never offer ordinary sign-in after containment. Manual
  recovery is shown as an outcome.
- Job monitoring explains partial failures, uncertain provider acceptance, and
  cancellation limits. Retry/cancel commands are coalesced and cancellation
  needs a warning acknowledgement.
- Audit models only represent actor, target, action, time, and bounded outcome;
  they intentionally have no credential, token, password, provider-payload, or
  arbitrary audit-value fields.
- Every controller fences late responses and future UI work after actor-session
  expiry. No feature domain imports generated DTOs or repository implementations.

## Changed files

- `flutter/lib/features/admin_campaigns/{domain,presentation}/...`
- `flutter/lib/features/admin_security/{domain,presentation}/...`
- `flutter/lib/features/admin_jobs/{domain,presentation}/...`
- `flutter/lib/features/admin_audit/{domain,presentation}/...`
- `flutter/test/features/admin_campaigns/admin_campaign_controller_test.dart`
- `flutter/test/features/admin_security/admin_security_controller_test.dart`
- `flutter/test/features/admin_jobs/admin_jobs_controller_test.dart`
- `flutter/test/features/admin_audit/admin_audit_controller_test.dart`

## Interfaces for final T10 composition

- Screen constructors: `AdminCampaignScreen`, `AdminSecurityScreen`,
  `AdminJobsScreen`, and `AdminAuditScreen`.
- Pure ports: `AdminCampaignRepository`, `AdminSecurityRepository`,
  `AdminJobsRepository`, and `AdminAuditRepository`.
- `AdminCampaignRepository.commit` receives an
  `AdminCampaignCommitCommand`, preserving a client-generated idempotency key
  for a frozen snapshot retry.

The current T10-owned `app/admin/AdminApiAdapter`, shell, and composition root
only wire session/users. T10's final composition pass must adapt the existing
T07 generated admin audience/message/job/audit endpoints to these ports, pass
the shared audience selection and authenticated test-recipient ID into the
screens, connect recent-MFA/session-expiry callbacks, and preserve CSRF plus
the commit idempotency key. Those owner files were intentionally not edited.

## Verification

TDD red evidence was recorded before implementation:

```text
mise exec -- flutter test --no-pub test/features/admin_campaigns test/features/admin_security test/features/admin_jobs test/features/admin_audit
exit 1: T12 model/port/controller libraries did not yet exist.
```

Focused final checks:

```text
cd flutter
mise exec -- dart format lib/features/admin_campaigns lib/features/admin_security lib/features/admin_jobs lib/features/admin_audit test/features/admin_campaigns test/features/admin_security test/features/admin_jobs test/features/admin_audit
mise exec -- flutter test --no-pub test/features/admin_campaigns test/features/admin_security test/features/admin_jobs test/features/admin_audit
exit 0: 18 tests passed.
```

Additional checks:

```text
mise run flutter-analyze
exit 0: 97 existing repository-wide informational diagnostics; no diagnostics in T12 paths.

mise run flutter-build-admin-web
build artifact produced at flutter/build/admin_web.

test -f flutter/build/admin_web/index.html && test -f flutter/build/admin_web/main.dart.js && test -f flutter/build/admin_web/main.dart.wasm && bash flutter/docker/test_admin_web_build.sh flutter/build/admin_web
exit 0.
```

The full suite was also run with `mise run flutter-test`. It reached 311 tests
with one failure. The coordinator supplied this as a T10 dependency baseline;
it reproduces directly with exit 1:

```text
cd flutter
mise exec -- flutter test --no-pub test/features/admin_session/admin_session_controller_test.dart
expected ['logout', 'bootstrap', 'login']
actual   ['logout', 'bootstrap', 'bootstrap', 'login']
```

No Go API, PostGIS, RustFS, SMTP, fake FCM, browser, or external provider was
started. This is an uncomposed Flutter-only feature slice; no real delivery was
attempted.

## Commit

Commit SHA is added after the task-scoped commit is created.

## Fix round 1 — review findings

### Changes

- Job retry and cancellation ports now receive an `AdminJobCommand` with a
  client-generated idempotency key. The controller retains that key after an
  unconfirmed/failed command result and removes it only after a confirmed
  success, so the next intentional operation receives a new key.
- Composer input changes call `updateDraft`, invalidating the preview and its
  commit key. The confirmation control is disabled until a new frozen preview
  is prepared.
- The jobs screen opens an explicit cancellation confirmation dialog and calls
  `confirmCancellation(acknowledged: true)` only when it is accepted.
- Job records now expose `updatedAt` relative to controller load time, and
  unknown delivery copy says provider acceptance is unconfirmed.
- Audit outcomes now map `provider_accepted`, `unknown_delivery`, and unknown
  future wire values into bounded safe display states.

### TDD and verification evidence

The added regressions were first run red:

```text
cd flutter
mise exec -- flutter test --no-pub test/features/admin_campaigns/admin_campaign_controller_test.dart
exit 1: edit-after-preview committed once (expected 0, actual 1).

mise exec -- flutter test --no-pub test/features/admin_jobs/admin_jobs_controller_test.dart
exit 1: AdminJobCommand, updatedAt, idempotencyKey, and clock contracts were absent.

mise exec -- flutter test --no-pub test/features/admin_audit/admin_audit_controller_test.dart
exit 1: provider/unknown audit outcome mapping was absent.
```

Final focused command and output:

```text
cd flutter
mise exec -- dart format lib/features/admin_campaigns lib/features/admin_jobs lib/features/admin_audit test/features/admin_campaigns test/features/admin_jobs test/features/admin_audit
mise exec -- flutter test --no-pub test/features/admin_campaigns test/features/admin_security test/features/admin_jobs test/features/admin_audit
Formatted 15 files (0 changed).
exit 0: 23 tests passed.
```

No broad suites, services, browser sessions, or external providers were run in
this fix round.

## Fix round 2 — review findings

### Changes

- `AdminCampaignScreen.didUpdateWidget` now synchronizes a changed audience
  into the controller. Any audience transition invalidates the frozen preview,
  including an A-to-B-to-A transition.
- Campaign composer fields are disabled during preview, commit, and test-send
  work. `updateDraft` also refuses to mutate state during a submission, so a
  delayed edit callback cannot clear the in-flight state or fence an accepted
  result.
- Each job card now renders the record's `updatedAt` relative to the most
  recent controller refresh. Unknown deliveries remain explicitly described as
  unconfirmed provider acceptance.
- Audit screen coverage now renders `provider_accepted`, `unknown_delivery`,
  and a forward-compatible unknown outcome through the safe bounded summary.

### TDD and verification evidence

The behavioral regressions were run before the production changes:

```text
cd flutter
mise exec -- flutter test --no-pub test/features/admin_campaigns/admin_campaign_controller_test.dart test/features/admin_jobs/admin_jobs_controller_test.dart test/features/admin_audit/admin_audit_controller_test.dart
exit 1:
- A-to-B-to-A audience mutation committed once (expected 0, actual 1).
- An edit during a pending commit lost the late accepted job (expected job-1,
  actual null).
- The jobs screen did not render "Updated 2 minutes before this refresh.".
The new audit display path passed against the existing bounded summary render.
```

Targeted green verification after the implementation:

```text
cd flutter
mise exec -- dart format lib/features/admin_campaigns/presentation/admin_campaign_controller.dart lib/features/admin_campaigns/presentation/admin_campaign_screen.dart lib/features/admin_jobs/presentation/admin_jobs_screen.dart test/features/admin_campaigns/admin_campaign_controller_test.dart test/features/admin_jobs/admin_jobs_controller_test.dart test/features/admin_audit/admin_audit_controller_test.dart
mise exec -- flutter test --no-pub test/features/admin_campaigns/admin_campaign_controller_test.dart test/features/admin_jobs/admin_jobs_controller_test.dart test/features/admin_audit/admin_audit_controller_test.dart
Formatted 6 files (3 changed).
exit 0: 23 tests passed.
```

Final all-T12 focused verification:

```text
cd flutter
mise exec -- dart format lib/features/admin_campaigns/presentation/admin_campaign_controller.dart lib/features/admin_campaigns/presentation/admin_campaign_screen.dart lib/features/admin_jobs/presentation/admin_jobs_screen.dart test/features/admin_campaigns/admin_campaign_controller_test.dart test/features/admin_jobs/admin_jobs_controller_test.dart test/features/admin_audit/admin_audit_controller_test.dart
mise exec -- flutter test --no-pub test/features/admin_campaigns test/features/admin_security test/features/admin_jobs test/features/admin_audit
Formatted 6 files (0 changed).
exit 0: 27 tests passed.
```

No services, browser sessions, or external providers were needed for these
widget/controller checks.

## Fix round 3 — in-flight audience and test-send review

### Changes

- Campaign draft/audience changes received while preview, commit, or test-send
  work is submitting are now queued rather than discarded. The latest queued
  value wins, so A-to-B-to-A still invalidates the frozen preview after the
  operation completes.
- Reconciliation preserves the accepted commit job or test-send result while
  clearing the frozen preview and commit idempotency key. A completed
  operation cannot silently make its old snapshot confirmable again.
- Test-send calls now coalesce while one is in flight, matching commit
  behavior and preventing a second accepted test send from being started.
- Added controller coverage for queued commit invalidation and accepted
  test-send completion, plus a widget regression for `didUpdateWidget`
  audience rebinding during commit.

### TDD and verification evidence

The new regressions were run before the implementation:

```text
cd flutter
mise exec -- flutter test --no-pub test/features/admin_campaigns/admin_campaign_controller_test.dart
exit 1:
- A-to-B-to-A audience mutation left the old preview present (expected null,
  actual AdminAudiencePreview).
- A queued audience change after preview completion was discarded (expected the
  second audience, actual the first audience instance).
- Editing during test-send started duplicate work (expected testSendCount 1,
  actual 2).
```

Final focused verification:

```text
cd flutter
mise exec -- dart format lib/features/admin_campaigns/presentation/admin_campaign_controller.dart test/features/admin_campaigns/admin_campaign_controller_test.dart
mise exec -- flutter test --no-pub test/features/admin_campaigns test/features/admin_security test/features/admin_jobs test/features/admin_audit
Formatted 2 files (0 changed).
exit 0: 31 tests passed.
```

No broad suites, services, browser sessions, or external providers were run in
this fix round.
