# Task T08a — persisted reports and review workflows

## Scope delivered

The legacy consumer report adapter persists a report before optional SMTP
delivery and derives the reporter from the authenticated context. Reports with
an `Idempotency-Key` now arbitrate the unique request row and consume account
and IP quota only in the transaction that wins the insert. Replays and racing
losers return the committed row without a second quota hit or audit event;
changed payloads return a conflict.

Target snapshots and user deletion share a transaction-scoped advisory lock,
and the snapshot query locks the target row first. The same user-row-then-
advisory lock order is used by `User.Delete`, `SoftDeleteUser`, and
`HardDeleteUser`, so report insertion and physical deletion cannot deadlock;
every report retains a deletion-safe target state.

Administrative report updates require `reports.review` for every individual
transition, including resolve and dismiss. `reports.resolve` and
`reports.dismiss` remain action capabilities for bulk report jobs. PATCH
assignment is tri-state: an omitted `assigneeUserId` preserves the assignment,
`null` clears it, and a UUID assigns a user. The generated request model keeps
presence information in an ignore-listed compatibility adapter.

Review audit events derive their action from the prior and new status and
include previous status, assignment changes, assignee IDs, assignment intent,
and whether a note was added. Report details remain bounded to 100 notes; the
new `GET /api/v3/admin/reports/{reportId}/notes` contract exposes the complete
newest-first history through a cursor page.

The OpenAPI contract, `oapi-codegen` output, OpenAPI Generator server output,
sqlc queries/output, handlers, and tests are synchronized. Runtime route
composition now installs `CaptureReportRequest` after trusted-real-IP
normalization, passes the configured report quota HMAC into the consumer
servicer, and mounts the concrete admin report servicer under `WEB_ADMIN_API`.
T08b bulk snapshot and job execution remains outside this task.

## Interfaces and integration seam

The service constructors are `service.NewReportService` (with an optional
`ReportServiceConfig`) and `service.NewReportReviewService`. The consumer
adapter accepts the same optional config, while
`handler.NewAdminReportsServicer` accepts a shared report service. The admin
handler implements the generated report methods, including
`ListAdminReportNotes`, and checks the request-time admin principal and
capability again for direct servicer use.

`cmd/server/main.go` passes the configured T05 HMAC key and key ID into
`NewReportServicer`, constructs the concrete `NewAdminReportsServicer(q)` for
the generated v3 admin reports controller, and registers it in the
authenticated v3 admin group. `CaptureReportRequest` wraps the authenticated
`/api/v2/report` route after trusted-real-IP normalization.

## Red/green evidence

The first focused run was intentionally red before the implementation slice:

```text
cd go-server
mise exec -- go test ./internal/service ./internal/middleware ./internal/handler
FAIL: missing AssigneeSet/ListReportNotes page types and the new atomic
      persistence behavior
```

The focused disposable-PostGIS run passed after the changes:

```text
cd go-server
TEST_DATABASE_URL='postgres://monaserver:monaserver@localhost:5432/monaserver_test?sslmode=disable' \
  mise exec -- go test -count=1 -p 1 ./internal/service ./internal/handler
PASS
```

The regression coverage includes concurrent same-key submissions with one
quota hit, repeated target-deletion races, concurrent revision checks,
omitted/explicit-null assignment, prior-status audit metadata, and 105-note
cursor paging with an appended note. The focused race run passed:

```text
TEST_DATABASE_URL='<disposable-local-DSN>' \
  mise exec -- go test -race -count=1 -p 1 ./internal/service -run '^TestReportService'
PASS
```

Generation and static verification commands:

```text
cd go-server
mise exec -- make gen-db
PASS: sqlc output is current

mise exec -- make gen-api
PASS: bundled API output is current

OPENAPI_GENERATOR_JAR=/root/openapi-generator-cli.jar \
  mise exec -- make gen-server
PASS: OpenAPI Generator 7.19.0 output is current and preserves the
      tri-state compatibility adapter

mise exec -- go vet ./...
PASS: no diagnostics

mise exec -- go build -o /tmp/monaserver-admin-t08a ./cmd/server
PASS

cd ..
git diff --check
PASS: no diagnostics
```

The final serial whole-server PostGIS suite passed across every package:

```text
cd go-server
TEST_DATABASE_URL='<disposable-local-DSN>' \
  mise exec -- go test -count=1 -p 1 ./...
PASS: cmd/admin-auth, cmd/server, internal/config, internal/db,
      internal/handler, internal/image, internal/jobs, internal/middleware,
      internal/password, internal/service, internal/token; packages without
      tests reported [no test files]
```

The final fix-round race checks passed serially:

```text
cd go-server
TEST_DATABASE_URL='<disposable-local-DSN>' \
  mise exec -- go test -race -count=1 -p 1 ./internal/service -run '^TestReportService'
PASS

TEST_DATABASE_URL='<disposable-local-DSN>' \
  mise exec -- go test -race -count=1 -p 1 ./cmd/server \
    -run 'TestEndpointReport|TestRealAdminRouterUsesBrowserSessionBoundary'
PASS

TEST_DATABASE_URL='<disposable-local-DSN>' \
  mise exec -- go test -race -count=1 -p 1 ./...
PASS: all Go packages
```

## Local service availability

PostgreSQL with PostGIS was available on the disposable local instance at
`127.0.0.1:5432`; database-backed tests use serial `-p 1`. Docker and Podman
were unavailable. No SMTP, FCM, RustFS, production provider, deployment, or
PR operation was used.

## Changed files

- `api/openapi.yaml`
- `docs/contracts/web-admin-and-email-login.md`
- `go-server/internal/db/admin_foundation.go`
- `go-server/internal/db/admin_repository.go`
- `go-server/internal/db/queries/admin_foundation.sql`
- `go-server/internal/gen/api/api.gen.go`
- `go-server/internal/gen/db/admin_foundation.sql.go`
- `go-server/internal/gen/db/querier.go`
- `go-server/internal/gen/server/.openapi-generator-ignore`
- `go-server/internal/gen/server/.openapi-generator/FILES`
- `go-server/internal/gen/server/api.go`
- `go-server/internal/gen/server/api/openapi.yaml`
- `go-server/internal/gen/server/api_admin_reports.go`
- `go-server/internal/gen/server/model_admin_report_note_page_dto.go`
- `go-server/internal/gen/server/model_admin_report_update_request_dto.go`
- `go-server/internal/handler/report_servicer.go`
- `go-server/internal/handler/report_servicer_test.go`
- `go-server/internal/handler/unavailable_v3.go`
- `go-server/internal/middleware/admin_session.go`
- `go-server/internal/middleware/admin_session_test.go`
- `go-server/internal/service/report.go`
- `go-server/internal/service/report_test.go`
- `go-server/cmd/server/main.go`
- `go-server/cmd/server/server_test.go`
- `go-server/cmd/server/admin_router_test.go`

Implementation commit SHA: current fix-round worktree `HEAD` (reported with the handoff).
