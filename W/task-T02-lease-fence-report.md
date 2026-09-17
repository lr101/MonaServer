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
- `ClaimJobItem` uses a lock-first CTE plus compare-and-set update. A targeted
  claim waits for an in-flight transition, then rechecks the row and its lease
  deadline after the lock is released. Its deadline is based on PostgreSQL's
  wall clock via `clock_timestamp()`, so a delayed claim cannot create an
  already-expired lease. It returns the claimed item, including its fresh
  `LeaseOwner`, `LeaseToken`, and `LeaseUntil` values. Expired leases are
  reclaimable and receive a new UUID token.
- `FinishJobItem`, `HeartbeatJobItem`, and `RetryJobItem` acquire the item row
  before evaluating the worker, token, and `clock_timestamp()` expiry
  predicate. Their `RETURNING id` result is mapped to `false` on
  `pgx.ErrNoRows`, so an acknowledgement that waits past expiry, loses a
  reclaim, is duplicated, or comes from the wrong worker cannot mutate the
  current item.
- The plural item claim and the existing durable-job and outbox lease queries
  use the same wall-clock lease deadline and expiry semantics. Their public
  APIs remain unchanged.
- Descriptive `ClaimAdminJobItem`, `FinishAdminJobItemWithFence`,
  `HeartbeatAdminJobItem`, and `RetryAdminJobItem` facade aliases are provided
  for the T07 adapter. Existing plural admin-item methods and all T04
  `DurableJob` claim/heartbeat/finish/release methods remain API-compatible.

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
wrong-token rejection while the original lease is still unexpired. The new
real-expiry test holds the item row while the lease expires, then confirms the
queued acknowledgement is rejected without a reclaim; the delayed-claim test
confirms the resulting lease deadline is still in the future. Contention tests
also check the transaction error returned by `InTx`.

The earlier database contention repair is in commit
`ecc4ed0aadf08ce49fd17bdcbc176a69745cc1f0`; the integrated wall-clock lease
fix and regenerated SQLC are in commit
`b343ea3b8ae8abd5ab2f1f07d624b5f9de47b560`. The claim test holds the item row
in a separate transaction, observes both `ClaimJobItem` sessions waiting on
the row through `pg_locks` joined to `pg_stat_activity`, then releases the
holder and asserts exactly one winner. Each reclaim subtest starts the stale
worker transaction while its original lease is valid, waits for server-side
expiry, queues worker-b's reclaim before the stale acknowledgement, observes
both database lock waiters, then releases the holder. The fresh lease is
asserted unexpired when finish, heartbeat, or retry rejects the old token.

```text
$ git rev-parse HEAD
b343ea3b8ae8abd5ab2f1f07d624b5f9de47b560
$ TEST_DATABASE_URL=<disposable local PostGIS DSN> mise exec -- go test -count=1 -p 1 ./internal/db -run 'TestT02AdminJobItem(ClaimFenceRejectsStaleWorkerAcknowledgements|ConcurrentClaimsHaveOneWinner|ReclaimFencesOverlappingStaleAcknowledgements|RejectsWrongTokenWhileLeaseIsValid|AcknowledgementRejectsAfterRealExpiryWithoutReclaim|ClaimDeadlineUsesWallClockAfterLockWait)$' -v
=== RUN   TestT02AdminJobItemClaimFenceRejectsStaleWorkerAcknowledgements
--- PASS: TestT02AdminJobItemClaimFenceRejectsStaleWorkerAcknowledgements (0.29s)
=== RUN   TestT02AdminJobItemConcurrentClaimsHaveOneWinner
--- PASS: TestT02AdminJobItemConcurrentClaimsHaveOneWinner (0.30s)
=== RUN   TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements
=== RUN   TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements/finish
=== RUN   TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements/heartbeat
=== RUN   TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements/retry
--- PASS: TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements (3.98s)
    --- PASS: TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements/finish (1.31s)
    --- PASS: TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements/heartbeat (1.34s)
    --- PASS: TestT02AdminJobItemReclaimFencesOverlappingStaleAcknowledgements/retry (1.32s)
=== RUN   TestT02AdminJobItemRejectsWrongTokenWhileLeaseIsValid
--- PASS: TestT02AdminJobItemRejectsWrongTokenWhileLeaseIsValid (0.33s)
=== RUN   TestT02AdminJobItemAcknowledgementRejectsAfterRealExpiryWithoutReclaim
--- PASS: TestT02AdminJobItemAcknowledgementRejectsAfterRealExpiryWithoutReclaim (0.46s)
=== RUN   TestT02AdminJobItemClaimDeadlineUsesWallClockAfterLockWait
--- PASS: TestT02AdminJobItemClaimDeadlineUsesWallClockAfterLockWait (0.54s)
PASS
ok  	github.com/lrprojects/monaserver/internal/db	5.897s
```

```text
$ cd go-server && mise exec -- make gen-db
cd internal/db && sqlc generate

$ psql -h 127.0.0.1 -U monaserver -d monaserver_test -Atc 'SELECT PostGIS_Version();'
3.3 USE_GEOS=1 USE_PROJ=1 USE_STATS=1

$ TEST_DATABASE_URL=<disposable local PostGIS DSN> mise exec -- go test -count=1 -p 1 ./internal/db
ok  	github.com/lrprojects/monaserver/internal/db	11.188s

$ TEST_DATABASE_URL=<disposable local PostGIS DSN> mise exec -- go test -count=1 -p 1 ./...
ok  	github.com/lrprojects/monaserver/cmd/admin-auth	0.008s
ok  	github.com/lrprojects/monaserver/cmd/server	5.702s
?   	github.com/lrprojects/monaserver/internal/apperrors	[no test files]
ok  	github.com/lrprojects/monaserver/internal/config	0.003s
ok  	github.com/lrprojects/monaserver/internal/db	11.164s
?   	github.com/lrprojects/monaserver/internal/gen/api	[no test files]
?   	github.com/lrprojects/monaserver/internal/gen/db	[no test files]
?   	github.com/lrprojects/monaserver/internal/gen/server	[no test files]
ok  	github.com/lrprojects/monaserver/internal/handler	13.517s
ok  	github.com/lrprojects/monaserver/internal/image	0.128s
ok  	github.com/lrprojects/monaserver/internal/jobs	0.074s
ok  	github.com/lrprojects/monaserver/internal/middleware	0.003s
ok  	github.com/lrprojects/monaserver/internal/password	0.375s
?   	github.com/lrprojects/monaserver/internal/scheduler	[no test files]
ok  	github.com/lrprojects/monaserver/internal/service	42.180s
ok  	github.com/lrprojects/monaserver/internal/token	0.003s

mise exec -- go vet ./...

mise exec -- gofmt -d internal/db/admin_foundation_test.go

git diff --check

```

PostgreSQL/PostGIS was available on the local disposable instance. No SMTP,
FCM, object storage, deployment, or production provider was contacted.
