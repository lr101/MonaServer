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

## Reviewer fix round

The reviewer follow-up is implemented in `ae1aaa5` (`fix: close v2 report
contract and quota configuration`). It keeps the v2 report success status at
200, declares the optional consumed `Idempotency-Key` header and 409/429
responses in both API authoring and bundled contracts, regenerates the Go and
Flutter report clients, and passes the header from the generated Go controller
to the report servicer. `ReportServiceConfig.Validate` rejects an empty or
whitespace-only HMAC key, and startup validates the decoded
`ADMIN_SESSION_HMAC_KEY` before migrations or route assembly. The startup
configuration test covers both rejection and successful decoding. Flutter
report note artifacts already required by the integrated T08a OpenAPI contract
were generated at the same time so the checked-in client matches the contract.

The final implementation SHA before this report update was:

```text
$ git rev-parse --short HEAD
ae1aaa5
```

The fix-round verification was rerun from the same worktree, with the
disposable native PostGIS database at `127.0.0.1:5432`:

```text
$ TEST_DATABASE_URL='<disposable-local-DSN>' mise exec -- go test -count=1 -p 1 ./cmd/server ./internal/handler ./internal/service
ok  github.com/lrprojects/monaserver/cmd/server       5.584s
ok  github.com/lrprojects/monaserver/internal/handler 13.259s
ok  github.com/lrprojects/monaserver/internal/service 38.572s

$ TEST_DATABASE_URL='<disposable-local-DSN>' mise exec -- go test -count=1 -p 1 ./...
ok  github.com/lrprojects/monaserver/cmd/admin-auth    0.008s
ok  github.com/lrprojects/monaserver/cmd/server        5.460s
ok  github.com/lrprojects/monaserver/internal/config   0.003s
ok  github.com/lrprojects/monaserver/internal/db       5.462s
ok  github.com/lrprojects/monaserver/internal/handler  14.080s
ok  github.com/lrprojects/monaserver/internal/image    0.107s
ok  github.com/lrprojects/monaserver/internal/jobs     0.086s
ok  github.com/lrprojects/monaserver/internal/middleware 0.004s
ok  github.com/lrprojects/monaserver/internal/password 0.564s
ok  github.com/lrprojects/monaserver/internal/service  36.840s
ok  github.com/lrprojects/monaserver/internal/token    0.004s

$ TEST_DATABASE_URL='<disposable-local-DSN>' mise exec -- go test -race -count=1 -p 1 ./...
ok  github.com/lrprojects/monaserver/cmd/admin-auth    1.035s
ok  github.com/lrprojects/monaserver/cmd/server        25.908s
ok  github.com/lrprojects/monaserver/internal/config  1.015s
ok  github.com/lrprojects/monaserver/internal/db      6.925s
ok  github.com/lrprojects/monaserver/internal/handler 33.064s
ok  github.com/lrprojects/monaserver/internal/image   2.291s
ok  github.com/lrprojects/monaserver/internal/jobs    1.086s
ok  github.com/lrprojects/monaserver/internal/middleware 1.014s
ok  github.com/lrprojects/monaserver/internal/password 5.778s
ok  github.com/lrprojects/monaserver/internal/service 126.860s
ok  github.com/lrprojects/monaserver/internal/token  1.013s

$ mise exec -- go vet ./...
$ mise exec -- go build -o /tmp/monaserver-admin-t08a ./cmd/server
$ git diff --check
PASS (no diagnostics)

$ mise exec -- make gen-api
oapi-codegen --config=internal/gen/api/oapi-codegen.yaml ../api/openapi.yaml

$ mise exec -- make gen-db
cd internal/db && sqlc generate

$ OPENAPI_GENERATOR_JAR=/root/.cache/openapi-generator/openapi-generator-cli-7.19.0.jar mise exec -- make gen-server
PASS (OpenAPI Generator 7.19.0)

$ java -jar /root/.cache/openapi-generator/openapi-generator-cli-7.9.0.jar generate ...
$ bash ../.github/scripts/normalize-openapi-generated.sh <generated> api
$ diff -ru --exclude=pubspec.yaml --exclude=pubspec.lock --exclude=.dart_tool --exclude=build --exclude=test api <generated>
PASS (exact workflow-equivalent generated Flutter diff; exit 0)
```

The Flutter CLI and Dart SDK are not installed in this agent image, so Flutter
analyze and Flutter test were unavailable; Java-based client generation and
the exact normalized diff completed successfully. Docker and Podman also
remain unavailable.

## Retry-After fix round

The final POC follow-up is implemented in `1c2c5ef` (`fix: expose report
quota retry header`). A typed report quota error now carries the database
window boundary, and the existing `CaptureReportRequest` composition retains
the response writer long enough for the v2 handler to emit an integer
`Retry-After`. The same positive value is present as `retryAfterSeconds` in
the `rate_limited` error body. The routed test fills the configured account
quota and asserts the 429 status, body, positive integer header, and equality
between header and body.

The final implementation SHA before this report update was:

```text
$ git rev-parse --short HEAD
1c2c5ef
```

The new wire test first failed with the existing behavior:

```text
quota error body = genserver.ApiErrorDto{Code:"rate_limited", Message:"too many reports", RetryAfterSeconds:(*int32)(nil)}, want rate_limited with retry seconds
FAIL
```

After the fix, the focused test passed:

```text
$ TEST_DATABASE_URL='<disposable-local-DSN>' mise exec -- go test ./cmd/server -run '^TestEndpointReport$/POST /api/v2/report quota response$' -count=1
ok  github.com/lrprojects/monaserver/cmd/server 0.470s
```

The exact post-fix rerun from the native PostGIS stack produced:

```text
$ TEST_DATABASE_URL='<disposable-local-DSN>' mise exec -- go test -count=1 -p 1 ./cmd/server ./internal/handler ./internal/service
ok  github.com/lrprojects/monaserver/cmd/server        5.636s
ok  github.com/lrprojects/monaserver/internal/handler 13.314s
ok  github.com/lrprojects/monaserver/internal/service 35.392s

$ TEST_DATABASE_URL='<disposable-local-DSN>' mise exec -- go test -count=1 -p 1 ./...
ok  github.com/lrprojects/monaserver/cmd/server        5.673s
ok  github.com/lrprojects/monaserver/internal/db       5.446s
ok  github.com/lrprojects/monaserver/internal/handler 13.436s
ok  github.com/lrprojects/monaserver/internal/service 37.556s

$ TEST_DATABASE_URL='<disposable-local-DSN>' mise exec -- go test -race -count=1 -p 1 ./...
ok  github.com/lrprojects/monaserver/cmd/server        26.207s
ok  github.com/lrprojects/monaserver/internal/db       6.973s
ok  github.com/lrprojects/monaserver/internal/handler 32.809s
ok  github.com/lrprojects/monaserver/internal/service 126.907s

$ mise exec -- go vet ./...
$ mise exec -- go build -o /tmp/monaserver-admin-t08a ./cmd/server
$ git diff --check
PASS (no diagnostics)

$ mise exec -- make gen-api
oapi-codegen --config=internal/gen/api/oapi-codegen.yaml ../api/openapi.yaml

$ mise exec -- make gen-db
cd internal/db && sqlc generate

$ OPENAPI_GENERATOR_JAR=/root/.cache/openapi-generator/openapi-generator-cli-7.19.0.jar mise exec -- make gen-server
gofmt -w internal/gen/server/

$ java -jar /root/.cache/openapi-generator/openapi-generator-cli-7.9.0.jar generate ...
$ bash ../.github/scripts/normalize-openapi-generated.sh <generated> api
$ diff -ru --exclude=pubspec.yaml --exclude=pubspec.lock --exclude=.dart_tool --exclude=build --exclude=test api <generated>
flutter generated diff: PASS (exit 0)
```

The Flutter CLI and Dart SDK remain unavailable in this agent image; the
Java-based generation and normalized diff completed successfully.
