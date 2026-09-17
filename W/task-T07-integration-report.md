# Task T07 integration report

## Integration

The reviewed T07 chain is integrated onto coordinator base `9ac9671`, which
already contains the T05/T06 browser-admin boundary, T08a report workflow, and
migration `000028_report_target_deletion.up.sql`. The commits were applied in
the requested order:

```text
5e7ae94  feat: add admin audience and bulk action services
3b81f67  fix: close admin bulk safety findings
9f6fdf5  fix: enforce admin bulk execution safety
6283bbe  fix: fence stale admin job acknowledgements
```

The resulting implementation commits are `f2c014b`, `bd2968d`, `25e32f3`,
and `8956f50`. The integration follow-up adds the coordinator handoff in the
current worktree.

No cherry-pick conflicts occurred. The existing generated API/server files,
T05/T06 admin session guards, and T08a report route/auth wiring remain intact;
the T07 handlers continue to implement the already-generated v3 interfaces.
Generation was rerun from the merged API and SQL sources and produced no
generated-file drift.

## Mandatory execution handoff

`AdminAuth` now implements `AdminActorReloader`. Each reload reads the current
account security state and admin membership, including auth generation and
permissions. Revoked, demoted, deleted, disabled, or incomplete memberships
return an invalid actor so a running job pauses before another item; database
failures return an unavailable error and never produce a usable actor. The
bulk service keeps the authenticated session's recent-MFA proof while taking
membership, generation, and capabilities from the fresh reload.

Bulk execution remains fail-closed at every entry point. Before a provider
call, the store must implement the fenced lease claim/finish interface, the
atomic item/audit commit, and the audit record boundary, and must explicitly
opt in to terminal `unknown_delivery` semantics. Credential actions also need
keyed idempotent ports. The existing legacy DB job methods are not adapted to
these stronger interfaces, so they cannot accidentally execute a job or send
a credential. Migration `000029_admin_job_item_lease_fence.up.sql` and the
durable DB adapter remain the subsequent DB-owner handoff after `000028`.

## Verification

All database commands used the dedicated disposable native PostgreSQL 15 /
PostGIS database for this worktree and ran serially with `-p 1`. No provider,
SMTP, Firebase, object storage, deployment, or PR was used.

```text
TEST_DATABASE_URL=<dedicated disposable PostGIS DSN> \
  mise exec -- go test -count=1 -p 1 ./...
PASS — all Go packages

TEST_DATABASE_URL=<dedicated disposable PostGIS DSN> \
  mise exec -- go test -count=1 -p 1 ./internal/service ./internal/handler ./cmd/server \
  -run '^(Test(Admin|Bulk|T07|Report|EndpointReport|RealAdminRouterUsesBrowserSessionBoundary|WebAdminAPI|V3))'
PASS — focused bulk/admin/report and route tests

TEST_DATABASE_URL=<dedicated disposable PostGIS DSN> \
  mise exec -- go test -race -count=1 -p 1 ./internal/service ./internal/handler ./cmd/server \
  -run '^(Test(Bulk|Admin|T07|Report|EndpointReport|RealAdminRouterUsesBrowserSessionBoundary|WebAdminAPI|V3))'
PASS — focused race checks

mise exec -- make gen-api
PASS — no API generated drift

mise exec -- make gen-db
PASS — no DB generated drift

OPENAPI_GENERATOR_JAR=/root/openapi-generator-cli.jar \
  mise exec -- make gen-server
PASS — no server generated drift

mise exec -- go vet ./...
PASS

mise exec -- go build -o /tmp/monaserver-admin-t07 ./cmd/server
PASS

gofmt on changed Go files; git diff --check
PASS
```

The focused and serial suite also cover the concrete actor reload boundary,
session-MFA handoff, lease/fence rejection, atomic audit commit requirement,
terminal unknown-delivery gate, keyed credential requirement, report routing,
and existing browser-admin authorization behavior.
