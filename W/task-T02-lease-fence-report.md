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
- `ClaimJobItem` is a single-row `SELECT ... FOR UPDATE SKIP LOCKED` plus
  compare-and-set update. It returns the claimed item, including its fresh
  `LeaseOwner`, `LeaseToken`, and `LeaseUntil` values. Expired leases are
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

The focused test first failed to compile because the singular lease methods did
not exist. After implementation, it passed against a disposable local
PostGIS database and covers active-lease non-reclaim, deterministic forced
expiry, fresh-token reclaim, wrong-worker heartbeat rejection, stale finish /
heartbeat / retry rejection, fresh heartbeat and finish acceptance, cleared
terminal lease fields, and rejection of a partial lease tuple by the new
constraint.

```text
TEST_DATABASE_URL=<disposable local PostGIS DSN> mise exec -- go test -count=1 -p 1 ./internal/db -run '^TestT02AdminJobItemClaimFenceRejectsStaleWorkerAcknowledgements$'
ok   github.com/lrprojects/monaserver/internal/db

TEST_DATABASE_URL=<disposable local PostGIS DSN> mise exec -- go test -count=1 -p 1 ./internal/db
ok   github.com/lrprojects/monaserver/internal/db

TEST_DATABASE_URL=<disposable local PostGIS DSN> mise exec -- go test -count=1 -p 1 ./...
ok   all tested packages

mise exec -- make gen-db
PASS

mise exec -- go vet ./...
PASS

gofmt -w internal/db/admin_repository.go internal/db/admin_foundation_test.go
git diff --check
PASS
```

PostgreSQL/PostGIS was available on the local disposable instance. No SMTP,
FCM, object storage, deployment, or production provider was contacted.
