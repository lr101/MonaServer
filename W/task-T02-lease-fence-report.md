# Task T02 amendment — durable admin job-item lease fencing

## Scope delivered

This amendment adds the singular, durable admin item lease boundary needed by
T07 while preserving the existing T04 durable-job APIs. PostgreSQL remains the
source of truth for ownership and acknowledgement:

- Migration `000029_admin_job_item_lease_fence.up.sql` repairs partially
  populated `admin_job_items` lease columns and adds an all-or-nothing
  worker/token/expiry check constraint. Migration 000029 follows the 000028
  report-target migration present in the T08a lane; keep that order when
  integrating the branches.
- `ClaimJobItem` is a single-row `SELECT ... FOR UPDATE` plus compare-and-set
  update. A targeted claim waits for an in-flight transition and rechecks the
  row after the lock is released. It returns the claimed item, including its
  fresh `LeaseOwner`, `LeaseToken`, and `LeaseUntil` values. Expired leases are
  reclaimable and receive a new UUID token.
- `FinishJobItem`, `HeartbeatJobItem`, and `RetryJobItem` all require the
  worker and exact lease token returned by the claim. Their `RETURNING id`
  result is mapped to `false` on `pgx.ErrNoRows`, so an expired, reclaimed,
  duplicate, or wrong-worker acknowledgement cannot mutate the current item.
- Descriptive `ClaimAdminJobItem`, `FinishAdminJobItemWithFence`,
  `HeartbeatAdminJobItem`, and `RetryAdminJobItem` facade aliases are provided
  for the T07 adapter. Existing plural admin-item methods and all T04
  `DurableJob` claim/heartbeat/finish/release methods remain unchanged.

The T07-facing facade contract is:

```text
ClaimJobItem(ctx, jobID, itemID, worker, lease)
    -> (*AdminJobItem, claimed bool, error)
FinishJobItem(ctx, itemID, worker, leaseToken, outcome, errorCode, providerReference)
    -> (accepted bool, error)
HeartbeatJobItem(ctx, itemID, worker, leaseToken, lease)
    -> (accepted bool, error)
RetryJobItem(ctx, itemID, worker, leaseToken)
    -> (accepted bool, error)
```

`AdminJobItem.LeaseToken` is the per-claim fence. T07 should retain it with
the in-flight item and pass both it and the worker identity to every finish,
heartbeat, or retry acknowledgement. A failed acceptance must stop any
post-lease result from being applied.

## Verification

The focused tests pass against a disposable local PostGIS database and cover
active-lease non-reclaim, fresh-token reclaim, wrong-worker rejection, stale
finish / heartbeat / retry rejection, fresh acknowledgement acceptance,
cleared terminal lease fields, partial lease tuple rejection, and same-worker
wrong-token rejection while the original lease is still unexpired.

The database contention repair is in commit
`ecc4ed0aadf08ce49fd17bdcbc176a69745cc1f0`. The claim test holds the item row
in a separate transaction, observes both `ClaimJobItem` sessions waiting on
the row through `pg_locks` joined to `pg_stat_activity`, then releases the
holder and asserts exactly one winner. Each reclaim subtest starts the stale
worker transaction while its original lease is valid, waits for server-side
expiry, queues worker-b's reclaim before the stale acknowledgement, observes
both database lock waiters, then releases the holder. The fresh lease is
asserted unexpired when finish, heartbeat, or retry rejects the old token.

```text
$ git rev-parse HEAD
ecc4ed0aadf08ce49fd17bdcbc176a69745cc1f0
$ TEST_DATABASE_URL=<disposable local PostGIS DSN> mise exec -- go test -count=1 -p 1 ./internal/db -run 'TestT02AdminJobItem(ConcurrentClaimsHaveOneWinner|ReclaimFencesOverlappingStaleAcknowledgements|RejectsWrongTokenWhileLeaseIsValid)$' -v
=== RUN   TestT02AdminJobItemConcurrentClaimsHaveOneWinner
--- PASS: TestT02AdminJobItemConcurrentClaimsHaveOneWinner (0.29s)
=== RUN   TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements
=== RUN   TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements/finish
=== RUN   TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements/heartbeat
=== RUN   TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements/retry
--- PASS: TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements (3.96s)
    --- PASS: TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements/finish (1.33s)
    --- PASS: TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements/heartbeat (1.31s)
    --- PASS: TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements/retry (1.32s)
=== RUN   TestT02AdminJobItemRejectsWrongTokenWhileLeaseIsValid
--- PASS: TestT02AdminJobItemRejectsWrongTokenWhileLeaseIsValid (0.31s)
PASS
ok  	github.com/lrprojects/monaserver/internal/db	4.557s
```

```text
TEST_DATABASE_URL=<disposable local PostGIS DSN> mise exec -- go test -count=1 -p 1 ./internal/db
ok  	github.com/lrprojects/monaserver/internal/db	10.210s

TEST_DATABASE_URL=<disposable local PostGIS DSN> mise exec -- go test -count=1 -p 1 ./...
ok  	github.com/lrprojects/monaserver/cmd/admin-auth	0.008s
ok  	github.com/lrprojects/monaserver/cmd/server	5.472s
?   	github.com/lrprojects/monaserver/internal/apperrors	[no test files]
ok  	github.com/lrprojects/monaserver/internal/config	0.003s
ok  	github.com/lrprojects/monaserver/internal/db	10.582s
?   	github.com/lrprojects/monaserver/internal/gen/api	[no test files]
?   	github.com/lrprojects/monaserver/internal/gen/db	[no test files]
?   	github.com/lrprojects/monaserver/internal/gen/server	[no test files]
ok  	github.com/lrprojects/monaserver/internal/handler	12.275s
ok  	github.com/lrprojects/monaserver/internal/image	0.109s
ok  	github.com/lrprojects/monaserver/internal/jobs	0.074s
ok  	github.com/lrprojects/monaserver/internal/middleware	0.003s
ok  	github.com/lrprojects/monaserver/internal/password	0.374s
?   	github.com/lrprojects/monaserver/internal/scheduler	[no test files]
ok  	github.com/lrprojects/monaserver/internal/service	32.645s
ok  	github.com/lrprojects/monaserver/internal/token	0.003s

mise exec -- make gen-db
cd internal/db && sqlc generate

mise exec -- go vet ./...

mise exec -- gofmt -d internal/db/admin_foundation_test.go

git diff --check

```

PostgreSQL/PostGIS was available on the local disposable instance. No SMTP,
FCM, object storage, deployment, or production provider was contacted.
