# T06 — consumer email login and restricted recovery

Status: implementation complete for the T06-owned service, handler, delivery
adapter, and focused tests. Base: `fd4b569`; fix round based on `fbe63f7`.
Worktree: `admin-t06-76e6aaef`.

## Implementation

- `internal/service/email_login.go` adds canonical verified-email lookup,
  shared HMAC-keyed address/IP/global quotas, generic request admission,
  generation/email/purpose-bound login actions, atomic POST exchange, sibling
  login-link revocation, canonical username results, typed admin issuance, and
  encrypted durable login delivery through caller-owned transactions. Public
  eligible, unknown, duplicate, and restricted outcomes remain generic
  accepted when enqueue delivery is unavailable, while committed HMAC quotas
  still apply. Quotas fail closed unless an explicit active HMAC key and key
  ID are configured; rate-limit decisions retain their retry boundary.
- `internal/service/account_recovery.go` adds password-policy validation and
  the public restricted-recovery boundary over T03's transaction-safe
  completion service. It also provides the typed encrypted recovery delivery
  adapter and manual-recovery result for unavailable or untrusted addresses.
  Recovery passwords follow the frozen v3 8–256 Unicode-string bounds, and
  the configurable delivery payload TTL is bounded by the action expiry.
- `internal/handler/email_auth_servicer.go` implements the generated
  `PublicAuthAPIServicer` methods with 202/200/204 success mappings and
  bounded v3 `ApiErrorDto` errors. `PublicAuthV3ErrorHandler` preserves the
  quota `Retry-After` header and body field. No GET action endpoint or
  JWT-bearing page was added; route registration remains with the coordinator.
- Login and recovery mail bodies are server-owned templates/content and keep
  raw action tokens only in encrypted delivery payloads. Durable jobs contain
  only delivery-attempt IDs. `ValidatedDeliveryAttemptStore` checks the
  encrypted action metadata under account → claim → token locks immediately
  before delivery, suppressing stale login/recovery messages after email
  changes, containment, completion, expiry, or sibling redemption while
  delegating ordinary T04 email/push payloads.

The recovery completion delegates generation advancement, token consumption,
credential invalidation, claim checks, and restriction clearing to T03's
`AccountSecurity`; T06 adds the consumer password policy and public error
mapping. Quota accounting commits before the account/action transaction so a
delivery outage cannot reset abuse limits. A public route must install
`genserver.WithPublicAuthAPIErrorHandler(handler.PublicAuthV3ErrorHandler)`;
the generated controller cannot carry response headers in `ImplResponse`, so
using the existing generic `V3ErrorHandler` would drop `Retry-After`. Trusted
route middleware must put its already-validated client IP into the request
context with `service.WithEmailLoginClientIP` before controller dispatch.

The second fix round keeps the 8–256 Unicode recovery contract while routing
passwords over bcrypt's 72-byte input limit through a domain-separated SHA-256
preparation; short-password and legacy hash verification remain compatible.
The delivery validation wrapper now returns typed terminal payload outcomes
for expiry, unavailable keys, and invalid/corrupt payloads, allowing the
dispatcher to persist the bounded failure code and clear the encrypted fields
without retrying or invoking a provider. Public login-link issuance propagates
enqueue failures out of the action transaction before normalizing them to the
generic accepted response, so failing and partially-writing enqueuers leave no
action, delivery-attempt, or durable-job rows while the already committed quota
still applies.

## Verification

The fix-round database checks used the disposable native PostgreSQL/PostGIS
database `monaserver_t3code_76e6aaef_t06` with the local task credentials from
the ignored `.env.test` source. Tests were serialized to avoid shared-database
truncation races.

```text
set -a; source /root/.t3/worktrees/MonaServer/t3code-76e6aaef/.env.test; set +a
export TEST_DATABASE_URL="postgres://…@127.0.0.1:5432/monaserver_t3code_76e6aaef_t06?sslmode=disable"
mise exec -- go test -count=1 -p 1 ./internal/service ./internal/handler
PASS — internal/service 29.305s; internal/handler 11.699s

set -a; source /root/.t3/worktrees/MonaServer/t3code-76e6aaef/.env.test; set +a
export TEST_DATABASE_URL="postgres://…@127.0.0.1:5432/monaserver_t3code_76e6aaef_t06?sslmode=disable"
mise exec -- go test -race -count=1 -p 1 ./internal/service \
  -run '^Test(EmailLoginExchangeIsSingleWinnerUnderConcurrentRedemption|AccountRecoveryRedemptionHasOneWinner|ValidatedDeliveryAttemptStore.*)$'
PASS — internal/service 8.270s

mise exec -- go vet ./...
PASS — exit 0

mise exec -- gofmt -w internal/service/email_login.go \
  internal/service/email_login_test.go internal/service/account_recovery.go \
  internal/service/account_recovery_test.go \
  internal/handler/email_auth_servicer.go \
  internal/handler/email_auth_servicer_test.go
PASS

git diff --check
PASS
```

The second fix round additionally passed `go test -count=1 -p 1 ./...` with the
same disposable database, `go test -race -count=1 -p 1 ./internal/service`
covering concurrent exchange/recovery redemption and all validated-delivery
tests, and `go vet ./...`. The changed Go files were formatted with `gofmt` and
`git diff --check` remained clean.

The focused database tests cover canonical/generic request behavior,
enumeration-safe unknown/duplicate/restricted suppression, address and IP
quotas, delivery-failure quota retention and eligible/unknown normalization,
rollback of action, delivery-attempt, and durable-job writes after failing or
partially-writing enqueuers,
missing quota-key fail-closed behavior, expiry, random and wrong-purpose
tokens, email changes, simultaneous exchange and recovery redemption,
single-use/sibling revocation, canonical username, refresh-insertion rollback,
8/256 password boundaries including end-to-end recovery with the contract
maximum, blocked claims, encrypted login/recovery attempts,
configurable payload TTL, durable job creation, missing delivery keys,
delivery-time suppression after email change/containment/sibling redemption or
completed recovery, and dispatcher terminal handling for expired, missing-key,
and corrupt payloads. Handler tests cover generated response mappings, trusted
client-IP context bridging, actual v3 error JSON, and `Retry-After` preservation.

## Availability and limits

PostgreSQL/PostGIS was available through the native local stack. Docker and
Podman were unavailable; RustFS was not needed. No SMTP, FCM, or other real
provider was contacted. Main/config/route composition remains deferred to the
coordinator; the coordinator must apply the two route bridges described above.
No API/OpenAPI/generated, DB/schema, T03, T05, Flutter, or shared
legacy-view files were changed; the dispatcher classification hook is part of
the T06 delivery validation integration.
