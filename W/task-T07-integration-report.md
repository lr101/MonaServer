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
`8956f50`, and `ccc1f2685029913c960aa338c70e55b2dc963c01`
(`fix: persist MFA proof and close bulk safety gaps`), followed by
`286aa8ea476b30342e608005c4e5324bade39af8` (`fix: harden T07 lease loss and
takeover MFA`), followed by `9e17963ce9421c27933163ffa5c1e75b1599961b`
(`fix: align takeover command MFA and cancellation fencing`). The implementation
commit is based on the pre-T02 coordinator handoff at `2fc01f7`; this lane was
not rebased onto T02. A fresh comparison confirms that T02 integration commit
`28c078d` is not an ancestor of this branch (the merge base is `9ac9671`). Its
tree deletes the T07 service, handlers, tests, reports, and migration
`000030_admin_job_mfa_proof.up.sql`, while changing the shared migration
`000029_admin_job_item_lease_fence.up.sql` and DB query facade. Applying T07
after that commit therefore requires a real integration resolution: preserve
T07's service/report and migration 30, merge the compatible migration 29/DB
owner changes once, and retain T02's lease query changes. No local rebase was
attempted because it would remove the T07 lane and exceed this T07 fix scope.

No cherry-pick conflicts occurred. The existing generated API/server files,
T05/T06 admin session guards, and T08a report route/auth wiring remain intact;
the T07 handlers continue to implement the already-generated v3 interfaces.
Generation was rerun from the merged API and SQL sources and produced no
generated-file drift.

The first serial PostGIS check on this pre-T02 branch found that the report
referenced migration `000029_admin_job_item_lease_fence.up.sql`, but that file
was absent from the branch. The implementation commit restores the reviewed
lease-fence migration, adds `000030_admin_job_mfa_proof.up.sql`, and the
serial suite was rerun against a freshly recreated disposable database before
the commit was made.

## Mandatory execution handoff

`AdminAuth` now implements `AdminActorReloader`. Each reload reads the current
account security state and admin membership, including auth generation and
permissions. Revoked, demoted, deleted, disabled, or incomplete memberships
return an invalid actor so a running job pauses before another item; database
failures return an unavailable error and never produce a usable actor. The
bulk service captures the action-bound recent-MFA timestamp and action in the
durable job at the handler's `202` create boundary, then reconstructs that
proof after a worker restart. Missing, mismatched, or expired proof pauses a
security/report job or an unconstrained all-account email, login-link, or push
job before an item can run.

Execution identity is explicit. The creator may execute or resume with the
freshness of the durable creator proof. A takeover requires the executor's
own authenticated request, `jobs.execute_all` for execution and
`jobs.control_all` alongside `jobs.control` for retry/resume. Execution MFA is
bound to the job action; retry/resume MFA is bound to the route's
`jobs.control` command action. The service never copies the creator's proof
onto a takeover actor.

Bulk execution remains fail-closed at every entry point. A recipient
eligibility checker is mandatory and must return a complete result immediately
before delivery; a missing or incomplete checker cannot direct-send. Item
execution re-reads the immutable snapshot member and its include-admin
acknowledgement, so a target promoted after preview is skipped unless that
snapshot explicitly acknowledged administrator delivery and the current
actor still has the capability.

Before a provider, security, report, or invalid-device action call, the store
must implement the fenced lease claim/finish interface, renewal of the same
lease proof, the atomic item/audit commit, and the audit record boundary, and
must explicitly opt in to terminal `unknown_delivery` semantics. The worker
renews the lease until every action port returns and cancels the action context
if renewal fails or its parent request is cancelled. Lease loss then uses a
separate exact-token/fence terminal commit that tolerates expiry, records
`unknown_delivery` plus its audit intent atomically, and clears the claim so a
reclaim cannot repeat the side effect. Terminal cleanup detaches from parent
cancellation, and a delayed renewal cannot hold the worker past quarantine. If
that terminal commit is unavailable, the service pauses the job and fails
closed; paused items cannot be claimed. Credential actions also need keyed
idempotent ports. The existing legacy DB job methods are not adapted to these
stronger interfaces, so they cannot accidentally execute a job or send a
credential. Migration `000029_admin_job_item_lease_fence.up.sql` remains the
lease/fence DB-owner handoff after `000028`; migration
`000030_admin_job_mfa_proof.up.sql` and the generated query facade now carry
the durable MFA proof needed by the eventual executable DB adapter.

## Verification

All database commands used the dedicated disposable native PostgreSQL 15 /
PostGIS database for this worktree and ran serially with `-p 1`. No provider,
SMTP, Firebase, object storage, deployment, or PR was used.

```text
TEST_DATABASE_URL=<dedicated disposable PostGIS DSN> \
  mise exec -- go test -count=1 -p 1 ./...
PASS — all Go packages

The first run stopped during migration setup with `no migration found for
version 29`; after restoring migration 29 and recreating the disposable test
database, the command above passed across all packages.

TEST_DATABASE_URL=<dedicated disposable PostGIS DSN> \
  mise exec -- go test -count=1 -p 1 ./internal/service ./internal/handler ./cmd/server \
  -run '^(Test(Admin|Bulk|T07|Report|EndpointReport|RealAdminRouterUsesBrowserSessionBoundary|WebAdminAPI|V3))'
PASS — focused bulk/admin/report and route tests

TEST_DATABASE_URL=<dedicated disposable PostGIS DSN> \
  mise exec -- go test -race -count=1 -p 1 ./internal/service ./internal/handler ./cmd/server \
  -run '^(Test(Bulk|Admin|T07|Report|EndpointReport|RealAdminRouterUsesBrowserSessionBoundary|WebAdminAPI|V3))'
PASS — focused race checks

`TestAdminJobServicerPersistsActionBoundMFAProofOnAcceptedCreate`, missing and
incomplete eligibility checks, promoted-after-preview handling, the long
action lease renewal race, and restart/missing-proof recovery checks all pass.

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

The pre-fix implementation source commit covered by the initial integration
verification was:

```text
$ git rev-parse ccc1f2685029913c960aa338c70e55b2dc963c01
ccc1f2685029913c960aa338c70e55b2dc963c01
```

The follow-up fix commit was verified in this worktree after formatting:

```text
$ git rev-parse 9e17963ce9421c27933163ffa5c1e75b1599961b
9e17963ce9421c27933163ffa5c1e75b1599961b

$ (cd go-server && mise exec -- go test -count=1 ./internal/service)
PASS — github.com/lrprojects/monaserver/internal/service

$ (cd go-server && mise exec -- go test -race -count=3 ./internal/service -run '^(TestBulkLeaseLoss|TestBulkTakeover|TestBulkRestartRequiresDurable)')
PASS — lease-loss terminal/reclaim/fail-closed, takeover execution/resume,
and all-account restart MFA tests

$ (cd go-server && mise exec -- go test -race -count=1 -p 1 ./internal/service ./internal/handler ./cmd/server ./internal/middleware -run '^(Test(Bulk|Admin|T07|Report|EndpointReport|RealAdminRouterUsesBrowserSessionBoundary|WebAdminAPI|V3))')
PASS — focused service, handler, server route, and middleware race checks

$ (cd go-server && mise exec -- go test -count=1 -p 1 ./...)
PASS — all Go packages

$ (cd go-server && mise exec -- go vet ./...)
PASS

$ git diff --check
PASS
```

This follow-up changes the bulk service, focused service tests, and a
middleware route test; the earlier disposable PostGIS serial evidence remains
applicable because no DB, SQL, migration, API, generated, handler, or router
implementation file changed in this fix.

The focused and serial suite also cover the concrete actor reload boundary,
session-MFA handoff, lease/fence rejection, atomic audit commit requirement,
terminal unknown-delivery gate, keyed credential requirement, report routing,
and existing browser-admin authorization behavior.
