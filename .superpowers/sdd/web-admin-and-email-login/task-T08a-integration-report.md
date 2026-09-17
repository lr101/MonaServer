# T08a integration report

Status: the reviewed T08a report series is integrated onto `cbcb51d`, the
reviewed T05/T06 base. The integration worktree is
`admin-t08a-integrate-76e6aaef`.

## Applied commits

The reviewed commits were applied in their dependency order:

```text
f70cf41  feat: persist reports and add review workflow
ef710b4  docs: record T08a verification commit
d320a9a  fix: harden report review races and history
ea27914  fix: wire report routes and normalize deletion locks
2d48ce8  test: prove report lock ordering and routed quota wiring
```

The resulting implementation commits are `c27f81c`, `6c2a955`, `b79fd6d`,
`d76cdd5`, and `cfeae15`; this report is recorded in the follow-up commit.

## Conflict resolution

- `api.gen.go` was regenerated with the checked-in `oapi-codegen` 2.8.0
  command from the merged `api/openapi.yaml`, retaining the T05/T06 auth
  contract and the T08a report operations.
- The admin middleware test keeps both T05/T06 browser-auth assertions and
  T08a report capability, action, and empty-action checks, including trusted
  `X-Real-IP` handling.
- `main.go` keeps the complete T05 `AdminAuthConfig` and its configurable
  TTLs, passes the configured report HMAC key and key ID into the consumer
  report service, wraps the v2 report routes after trusted-real-IP
  normalization, and wires the concrete v3 admin report service through the
  existing browser-admin route groups.
- Route tests keep the T05 `WEB_ADMIN_API` toggle and deterministic admin
  clock while adding report capability and trusted proxy coverage.

## Migration boundary

The integrated T08a tree adds
`000028_report_target_deletion.up.sql` and does not rewrite an existing
migration. The later reviewed T02 lease amendment is
`000029_admin_job_item_lease_fence.up.sql` on the separate
`admin-t02-lease` branch (`157db9c`); it remains a subsequent integration
input and therefore follows 000028 when the coordinator applies that branch.
A read-only `git merge-tree --write-tree HEAD
t3code/admin-t02-lease-76e6aaef` check completed without conflicts, and its
merged tree lists 000028 before 000029.

## Verification

All commands ran from `go-server/` against disposable native PostgreSQL 15
with PostGIS on `127.0.0.1:5432`, using serial package execution where the
database was involved. Docker and Podman were unavailable.

```text
mise exec -- make gen-api
PASS; no worktree changes

mise exec -- make gen-db
PASS; no worktree changes

OPENAPI_GENERATOR_JAR=/root/openapi-generator-cli.jar \
  mise exec -- make gen-server
PASS; OpenAPI Generator 7.19.0, no worktree changes

TEST_DATABASE_URL='<disposable-local-DSN>' \
  mise exec -- go test -count=1 -p 1 ./internal/service ./internal/handler
PASS — internal/service 35.721s; internal/handler 13.615s

TEST_DATABASE_URL='<disposable-local-DSN>' \
  mise exec -- go test -count=1 -p 1 ./cmd/server \
    -run 'Test(EndpointReport|RealAdminRouterUsesBrowserSessionBoundary|WebAdminAPI|V3)'
PASS — cmd/server 0.739s

TEST_DATABASE_URL='<disposable-local-DSN>' \
  mise exec -- go test -race -count=1 -p 1 ./internal/service \
    -run '^TestReportService'
PASS — internal/service 5.177s

TEST_DATABASE_URL='<disposable-local-DSN>' \
  mise exec -- go test -race -count=1 -p 1 ./cmd/server \
    -run 'Test(EndpointReport|RealAdminRouterUsesBrowserSessionBoundary|WebAdminAPI)'
PASS — cmd/server 5.664s

TEST_DATABASE_URL='<disposable-local-DSN>' \
  mise exec -- go test -count=1 -p 1 ./...
PASS — all Go packages

mise exec -- go vet ./...
PASS — no diagnostics

mise exec -- go build -o /tmp/monaserver-admin-t08a ./cmd/server
PASS

gofmt on changed Go files; git diff --check
PASS — no diagnostics
```

The resulting worktree was clean before adding this report.
