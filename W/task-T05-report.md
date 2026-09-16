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
secret, revokes browser sessions, and records the stable actor and target IDs.

No OpenAPI or generated API/server files, consumer auth, jobs, or Flutter files
were changed. The reviewer-required database additions are forward migrations
for membership/user replay scope and action-bound recent MFA, with sqlc output
regenerated from the query source.

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
ok  github.com/lrprojects/monaserver/cmd/admin-auth          0.008s
ok  github.com/lrprojects/monaserver/cmd/server               6.076s
ok  github.com/lrprojects/monaserver/internal/db              5.379s
ok  github.com/lrprojects/monaserver/internal/handler        13.738s
ok  github.com/lrprojects/monaserver/internal/middleware      0.003s
ok  github.com/lrprojects/monaserver/internal/service        21.503s
ok  github.com/lrprojects/monaserver/internal/image             0.095s
ok  github.com/lrprojects/monaserver/internal/jobs              0.073s
ok  github.com/lrprojects/monaserver/internal/password          0.217s
ok  github.com/lrprojects/monaserver/internal/token              0.002s
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
Bearer denial, capability 403, v2 cookie-gated handling, and mutation CSRF.

```text
mise exec -- go vet ./...
PASS (no diagnostics)

mise exec -- make gen-db
cd internal/db && sqlc generate
PASS (no generated drift)

git diff --check
PASS (no diagnostics)
```

## Local service availability

PostgreSQL/PostGIS was available on `127.0.0.1:5432` and the disposable DB
tests ran serially with `-p 1`. Docker and Podman were unavailable. RustFS was
installed but not started because this slice has no object-storage dependency.
SMTP and Firebase were not configured or contacted; no real providers were
used.
