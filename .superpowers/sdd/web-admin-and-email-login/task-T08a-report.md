# Task T08a — persisted reports and review workflows

## Scope delivered

The legacy consumer report adapter now persists a report before attempting the
optional SMTP notification. It derives the durable reporter from the
authenticated `middleware.UserID` context and rejects a mismatched DTO user ID.
When the report repository is present, no SMTP service is a successful-path
requirement; a configured SMTP failure cannot roll back the saved report.
The adapter accepts a bounded `Idempotency-Key`, returns the existing row for a
matching retry, and returns a conflict for a changed payload. `CaptureReportRequest`
also carries the trusted-real-IP result into the service and caps the request
body before generated JSON decoding.

`service.ReportService` owns bounded submission validation, optional HMAC-keyed
account/IP quotas, target snapshot capture, cursor-based inbox paging and
search, detail reads, assignment, append-only notes, and revision-checked
open/resolved/dismissed transitions. Submission and review audit events are
written in the same transaction as their changes. The target deletion
migration preserves target ID/name/deleted state for both soft and hard user
deletion. User content remains text in the DTO boundary and SMTP report bodies
use HTML escaping.

The generated API contract was unchanged. sqlc output was regenerated for the
new report queries and the updated reopen timestamp behavior. T08b's durable
inbox outbox and report bulk snapshot/job work remain outside this milestone.

## Interfaces and integration seam

The new service constructors are `service.NewReportService` (with an optional
`ReportServiceConfig`) and `service.NewReportReviewService`. The consumer
adapter constructor accepts the same optional config, while
`handler.NewAdminReportsServicer` accepts a shared report service. The admin
handler implements the frozen `genserver.AdminReportsAPIServicer` methods and
checks the stable admin principal/capabilities again for direct use.

The coordinator-owned `cmd/server/main.go` wiring must:

1. pass the configured T05 HMAC key and key ID into `NewReportServicer` so
   report quotas are enabled in production;
2. construct `NewAdminReportsServicer(q, reportService)`, create its generated
   admin reports controller, and register that controller in the authenticated
   v3 admin group; and
3. wrap the authenticated `/api/v2/report` route with
   `handler.CaptureReportRequest` after `TrustedRealIP` has normalized the
   client address.

The internal reopen audit action is recorded as `report_reopen` so reopening
is distinguishable from resolving and dismissing. The frozen admin action
enum currently names only `report_resolve` and `report_dismiss`; if the audit
API exposes report transition actions, the coordinator should reconcile that
contract with the T08 reopen requirement rather than silently changing the
generated contract in this milestone.

## Red/green evidence

The first service test run was intentionally red before implementation:

```text
cd go-server
mise exec -- go test ./internal/service -run 'TestReportService|TestReportCursor' -count=1
FAIL: undefined report service constructors/types referenced by the new tests
```

After implementation, the focused disposable-PostGIS run passed:

```text
cd go-server
TEST_DATABASE_URL='<disposable-local-DSN>' mise exec -- go test -p 1 ./internal/service ./internal/handler -run 'TestReportService|TestReportCursor|TestCreateReport|TestCaptureReport|TestAdminReport' -count=1
PASS
```

The final serial whole-server run passed for every Go package:

```text
cd go-server
TEST_DATABASE_URL='<disposable-local-DSN>' mise exec -- go test -count=1 -p 1 ./...
PASS: cmd/admin-auth, cmd/server, internal/config, internal/db,
      internal/handler, internal/image, internal/jobs, internal/middleware,
      internal/password, internal/service, internal/token; packages without
      tests reported [no test files]
```

Generation, formatting, static checks, build, and whitespace checks passed:

```text
cd go-server
mise exec -- make gen-db
PASS: sqlc generated output is current

mise exec -- gofmt -w internal/db/admin_foundation.go internal/db/admin_repository.go internal/handler/admin_servicer.go internal/handler/report_servicer.go internal/handler/report_servicer_test.go internal/service/report.go internal/service/report_test.go
PASS

mise exec -- go vet ./...
PASS: no diagnostics

mise exec -- go build -o bin/server ./cmd/server
PASS: server binary built as the ignored local artifact go-server/bin/server

cd ..
git diff --check
PASS: no diagnostics
```

No OpenAPI generation was run because `api/openapi.yaml` and generated API
files were unchanged. The sqlc command above was run after the final query
source edits.

## Local service availability

PostgreSQL with PostGIS was available on the disposable local instance at
`127.0.0.1:5432`; all database-backed tests used a serial `-p 1` run. Docker
and Podman were unavailable. No SMTP, FCM, or production provider was
contacted. RustFS was not needed for this report slice. No production sends,
deployment, or PR was performed.

## Changed files

- `go-server/internal/db/migrations/000028_report_target_deletion.up.sql`
- `go-server/internal/db/queries/admin_foundation.sql`
- `go-server/internal/db/admin_foundation.go`
- `go-server/internal/db/admin_repository.go`
- `go-server/internal/gen/db/admin_foundation.sql.go`
- `go-server/internal/gen/db/querier.go`
- `go-server/internal/handler/admin_servicer.go`
- `go-server/internal/handler/report_servicer.go`
- `go-server/internal/handler/report_servicer_test.go`
- `go-server/internal/service/report.go`
- `go-server/internal/service/report_test.go`

Implementation commit SHA: `f70cf41`.
