# Task T05 — admin identity and browser sessions

## Scope delivered

This milestone adds the independent admin authentication boundary in
`go-server/internal/service/admin_auth.go`, its request-time guards in
`go-server/internal/middleware/admin_session.go`, and the generated-service
adapter in `go-server/internal/handler/admin_session_servicer.go`.

The service enrolls operators by stable user ID, stores AES-GCM encrypted TOTP
secrets with a key ID, verifies password plus RFC 6238 TOTP challenges, stores
only SHA-256 hashes of opaque browser session values, rotates CSRF after MFA and
step-up, persists membership/user-scoped replay counters, applies idle and
absolute expiry, reloads security generation and membership on every request,
and revokes sessions on logout, demotion, compromise, or break-glass recovery.
Failed password/TOTP challenges use the T02 shared HMAC quota (account/IP, IP,
and global buckets) without changing the consumer login lock counter; each
dimension is checked atomically before password, initial MFA, and step-up
verification so correct credentials remain rejected during exhaustion. Recent
step-up state is persisted with its action binding.

The third review repair keeps consumer CORS behavior while dispatching every
v2/v3 admin path to the credentialed origin policy before wildcard headers can
be emitted. Mutating routes now have explicit recent-MFA action families;
action-union bodies are inspected with a bounded reader and restored before
generated decoding. Single-report transition bodies remain untouched by the
action guard. The pre-auth envelope carries its
issuance timestamp, which is bound by the CSRF HMAC and checked against the
configured TTL; bootstrap renewals preserve the original absolute deadline.
`WEB_ADMIN_API` defaults on so a deployment that protects v2 with browser
sessions can still bootstrap/login after upgrade.

The fourth review repair makes an initial MFA session actionless and therefore
unable to satisfy any mapped mutation guard until a capability-bound step-up
stores an explicit action. The contract now publishes the route-family actions
`jobs.control`, `messages.test`, and `reports.review`; the Go and Flutter
generated clients were regenerated from the same OpenAPI source. `WEB_ADMIN_API`
is passed to the migrated v2 group as well as every v3 admin group, so disabling
the flag returns the unavailable response before a handler can run. Trusted
proxy processing accepts `X-Real-IP` only for a configured proxy when
`X-Forwarded-For` is absent, while direct peers and malformed forwarded input
remain authoritative. All admin session TTLs and shared quota limits are now
loaded from configuration and the route guard uses the service's configured
recent-MFA TTL.

The final review repair keeps single-report PATCH transitions bound to the
`reports.review` route action, including resolved and dismissed status bodies;
the `report_resolve` and `report_dismiss` proofs remain reserved for bulk action
jobs. Break-glass recovery now requires a nonzero actor ID that resolves to a
live, active admin membership with `security.recovery_resend`; missing,
unknown, consumer, revoked, disabled, and insufficiently permissioned actors are
rejected before the target membership can change, and successful audits retain
the validated actor ID.

The runtime now constructs this service from configuration, mounts the concrete
admin session controller, applies the browser cookie gate to v2 and v3 admin
groups, and preserves the existing v2 payload handlers after authentication.
The middleware rejects Bearer-only admin access, enforces stable capability and
CSRF checks, fails closed for an unset admin origin, emits credentialed CORS only
for the configured origin, and trusts forwarded client IPs only from configured
proxy networks. Break-glass recovery requires an active, non-revoked membership
and preserves membership state.

`go-server/cmd/admin-auth` provides explicit `bootstrap`, `enroll`, and
`recover-mfa` operations. Enrollment is idempotent and prints a newly created
TOTP secret only as the deliberate one-time operator handoff; the HTTP API,
logs, and audit metadata never contain it. Break-glass recovery rotates the
secret, revokes browser sessions, and records the stable authorized actor and
target IDs. The `recover-mfa` command requires `--actor-id`; the service checks
that the ID belongs to an active operator with `security.recovery_resend`.

The OpenAPI source, generated Go API/server artifacts, and generated Flutter
action enum are changed together; consumer auth, jobs, and database schema are
unchanged in this repair. The reviewer-required database additions are forward
migrations for membership/user replay scope and action-bound recent MFA, with
sqlc output regenerated from the query source.

## Red/green evidence

The initial DB enrollment test was red at the service boundary because the
newly written test referenced the not-yet-implemented
`AdminAuth.EnrollAdminOperator` symbol. The implementation added that symbol.
The reviewer regression test for pre-verification throttle was also red until
the read-only shared quota facade and service admission gate were added. The
following full suite is green against the disposable PostGIS database. The
test DSN was sourced from the reviewed T03 environment file; its value is
intentionally omitted here.

```text
set -a; source /root/.t3/worktrees/MonaServer/t3code-76e6aaef/.superpowers/sdd/web-admin-and-email-login/.env.test.T03; set +a
TEST_DATABASE_URL="$TEST_DATABASE_URL" mise exec -- go test -count=1 -p 1 ./...
ok  github.com/lrprojects/monaserver/cmd/admin-auth          0.009s
ok  github.com/lrprojects/monaserver/cmd/server               5.632s
ok  github.com/lrprojects/monaserver/internal/config           0.003s
ok  github.com/lrprojects/monaserver/internal/db              5.542s
ok  github.com/lrprojects/monaserver/internal/handler        11.608s
ok  github.com/lrprojects/monaserver/internal/image             0.097s
ok  github.com/lrprojects/monaserver/internal/jobs              0.072s
ok  github.com/lrprojects/monaserver/internal/middleware      0.004s
ok  github.com/lrprojects/monaserver/internal/password          0.224s
ok  github.com/lrprojects/monaserver/internal/service        21.707s
ok  github.com/lrprojects/monaserver/internal/token              0.003s
?    github.com/lrprojects/monaserver/internal/apperrors         [no test files]
?    github.com/lrprojects/monaserver/internal/gen/api           [no test files]
?    github.com/lrprojects/monaserver/internal/gen/db            [no test files]
?    github.com/lrprojects/monaserver/internal/gen/server        [no test files]
?    github.com/lrprojects/monaserver/internal/scheduler          [no test files]
```

The focused handler test drives the generated admin-session controller through
bootstrap, wrong-CSRF rejection, password challenge, MFA, cookie flags, GET
restoration, step-up CSRF rotation, stale-CSRF rejection, and logout. DB tests
also cover pre-verification password and MFA throttling/window recovery,
membership/user replay across sessions, IP/account/global throttling, consumer
counter isolation, encrypted idempotent enrollment, expiry, demotion,
compromise, self-target revocation/job pause, and active-membership-only
break-glass audit behavior. The real router test covers browser bootstrap/login,
Bearer denial, capability 403, v2 cookie-gated handling, mutation CSRF, and an
OPTIONS preflight through the production global CORS wrapper, including exact
origin/credential headers and wildcard rejection. Middleware tests cover
unmapped-action rejection, empty stored-action rejection, body-action binding,
body restoration, and direct/trusted `X-Real-IP` handling. The real router test
also performs an action-bound step-up before exercising the migrated v2 write,
and a disabled-flag test proves the v2 group stops at the feature gate. The
concurrent service-level step-up test records one winner for a moving factor
and rejects the simultaneous replay; the throttle test covers password,
initial MFA, and step-up exhaustion with recovery after the shared window. The
final review tests cover both single-report transition statuses through the
`reports.review` middleware capability and reject bulk proofs, while the
break-glass service test covers missing, consumer, and insufficient actor IDs,
no mutation on rejected calls, and successful audit attribution.

```text
mise exec -- go vet ./...
PASS (no diagnostics)

mise exec -- make gen-db
cd internal/db && sqlc generate
PASS (no generated drift)

git diff --check
PASS (no diagnostics)
```

The fourth-repair verification was run after the changes:

```text
mise exec -- make gen-api
OPENAPI_GENERATOR_JAR=/root/openapi-generator-cli.jar mise exec -- make gen-server
PASS (generated Go outputs stable)

java -jar ~/.cache/openapi-generator/openapi-generator-cli-7.9.0.jar generate ...
diff -ru ... flutter/api "$generated_api"
PASS (generated Flutter output matches)

cd flutter/api && mise exec -- flutter test --no-pub
PASS (203 tests)

cd flutter/api && mise exec -- flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
PASS (two pre-existing non-fatal warnings)

TEST_DATABASE_URL="$TEST_DATABASE_URL" mise exec -- go test -count=1 -p 1 ./...
PASS (all packages, disposable PostGIS database)

TEST_DATABASE_URL="$TEST_DATABASE_URL" mise exec -- go test -race -count=1 -p 1 ./internal/service -run '^TestAdminStepUpReplayIsRejectedAtServiceBoundaryConcurrently$'
PASS

mise exec -- go vet ./...
PASS

mise exec -- go build -o /tmp/monaserver-admin-t05 ./cmd/server
PASS
```

The final review repair was then rechecked with the focused middleware, CLI,
and service tests, followed by a fresh serial full suite against the same
disposable PostGIS database. Pinned Go API/server generation produced no diff;
pinned Dart generation also matched `flutter/api` after the repository
normalizer. The root Flutter contract fixtures passed after `flutter pub get`,
and the generated-client suite passed 203 tests. Dart analysis retained only
the two existing non-fatal generated-client warnings.

## Local service availability

PostgreSQL/PostGIS was available on `127.0.0.1:5432` and the disposable DB
tests ran serially with `-p 1`. Docker and Podman were unavailable. RustFS was
installed but not started because this slice has no object-storage dependency.
SMTP and Firebase were not configured or contacted; no real providers were
used.
