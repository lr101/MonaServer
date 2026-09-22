# T11 — Admin report review UI and structured submissions

## Status

Implementation complete; the final scoped task review is approved at
`fe7aa75` by both the quality and specification reviewers with no Critical or
Important findings. The slice is based on the reviewed contract amendment at
`922a12d` and keeps generated/API, Go, router, and T10 shared files unchanged.

## Changed files

- `flutter/lib/features/admin_reports/domain/admin_report_models.dart`
  - Pure report status, target, note, page/query, update, bulk command/outcome,
    and transport-error models.
- `flutter/lib/features/admin_reports/domain/admin_report_ports.dart`
  - Feature-owned `AdminReportsRepository` port, including the shared audience
    preview port.
- `flutter/lib/features/admin_reports/presentation/admin_reports_controller.dart`
  - Cursor paging, search/status filtering, selection, detail loading, notes,
    assignment/status updates, revision conflicts, permission/session errors,
    audience preview/commit, and list/detail/bulk generation fences.
- `flutter/lib/features/admin_reports/presentation/admin_reports_screen.dart`
  - Constructor-only report inbox/detail screen with loading, empty, error,
    permission, deleted-target, keyboard/semantics, assignment, notes, and
    selected/all-matching controls.
- `flutter/lib/widgets/report_issue/report_issue_submission.dart`
  - Consumer report adapter preserving legacy `userId`/`report`/`message`
    semantics while mapping optional `targetId`/`targetKind` to generated
    `ReportDto` at the adapter boundary.
- `flutter/lib/data/service/global_data_service.dart`
  - Adds the narrow `reportDto` transport seam while preserving the legacy
    `report(String, String)` entry point.
- `flutter/lib/widgets/report_issue/presentation/report_issue_page.dart`
  - Uses the structured adapter in the live consumer submit path.
- `flutter/test/features/admin_reports/admin_reports_controller_test.dart`
  - Paging/filter races, detail updates/notes, blank-assignee clearing,
    revision conflict, serialized detail mutations, selected/all-matching
    previews, stale bulk work and outcomes, duplicate-commit protection, text
    search scope protection, and capability denial.
- `flutter/test/features/admin_reports/admin_reports_screen_test.dart`
  - Deleted target, detail controls, permission denial, loading/empty/error,
    assignment preservation, capability-gated controls, keyboard search, and
    text-search bulk-action accessibility.
- `flutter/test/features/admin_reports/report_issue_submission_test.dart`
  - Legacy compatibility and generated structured-target mapping.
- `flutter/test/features/admin_reports/report_issue_transport_test.dart`
  - Proves the live service seam forwards structured target fields.

## Ports and behavior

`AdminReportsRepository` is the only dependency of the controller. T10/T13 can
map `AdminReportsApi` DTOs and transport errors behind that port without
leaking generated types into report presentation. Bulk status actions use
`AdminAudiencePreviewRequest`, `AdminAudiencePreview`, and
`AdminAudienceCommitRequest`; selected IDs remain explicit across cursor pages.

The controller treats bulk preview/commit as an in-flight operation, clears an
old preview before replacement, prevents duplicate confirmation, and reloads
the current inbox after a successful commit. It reports a completed outcome
even when a newer inbox operation supersedes the commit generation.

The controller rejects all-matching actions while free-text search is active,
because the current shared report snapshot filter carries status/type/assignee
criteria but not report text search. This prevents a search-scoped UI action
from silently expanding to a broader server snapshot. Status-filtered
all-matching actions remain supported, and an unfiltered all-matching action
uses an explicit reports-wide audience selection.

Deleted or unavailable targets are rendered only as text. Reporter, report,
legacy context, target and note content are passed to text widgets; no body
reporter value is treated as authenticated identity by this client seam.

## Checks and results

- `mise exec -- flutter pub get` — passed; restored the missing locked Flutter
  package cache/package configuration. No dependency versions were changed.
- `mise exec -- dart format lib/features/admin_reports/presentation/admin_reports_controller.dart lib/features/admin_reports/presentation/admin_reports_screen.dart lib/widgets/report_issue/report_issue_submission.dart lib/widgets/report_issue/presentation/report_issue_page.dart lib/data/service/global_data_service.dart test/features/admin_reports` — passed.
- `mise exec -- flutter test --no-pub test/features/admin_reports` — passed,
  29 tests at the approved implementation head.
- `mise exec -- flutter analyze lib/features/admin_reports lib/widgets/report_issue lib/data/service/global_data_service.dart` — passed with no issues.
- `mise exec -- flutter test --no-pub test/features/admin_audience test/features/admin_campaigns test/architecture_test.dart` — passed, 56 tests.
- `mise run flutter-analyze` — passed with 101 non-fatal informational
  findings; the scoped T11 library analysis had no issues.
- `mise run flutter-test` — reached 376 tests with 2 skips and failed only at the known
  pre-existing T10 test:
  `test/features/admin_session/admin_session_controller_test.dart: a login started during logout waits for the fresh CSRF bootstrap`.
- `git diff --check` — passed.
- Final review package `.superpowers/sdd/web-admin-and-email-login/review-e1ea548..fe7aa75.diff` — both fresh reviewers approved; no Critical or Important findings.

No Go/API/DB generation was needed for this Flutter-only slice. No API,
PostGIS, RustFS, SMTP, push, or browser stack was started. The transport test
uses a fake `ReportApi`; live SMTP-unavailable persistence and browser
verification remain integration checks for T10/T13. No production
credentials or provider payloads were accessed.

## Unresolved T10/T13 composition seams

- T10/T13 must provide the live `AdminReportsRepository` adapter, admin session
  capability wiring, and route/composition registration; this slice exposes
  the screen/controller constructor seam and does not edit the router.
- T10/T13 should retain the constructor-only report screen seam and provide the
  live `AdminReportsRepository` plus capability flags. The consumer page now
  uses `ReportIssueSubmission.toReportDto()` through `AuthService.reportDto()`;
  no generated client files were changed.
- The shared audience contract does not encode report free-text search, so
  text-search all-matching actions are intentionally disabled as documented
  above until that shared/API contract is extended by its owner.
