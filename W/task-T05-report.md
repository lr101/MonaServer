# Task T05 — admin identity and browser sessions

## Scope delivered

This milestone adds the independent admin authentication boundary in
`go-server/internal/service/admin_auth.go`, its request-time guards in
`go-server/internal/middleware/admin_session.go`, and the generated-service
adapter in `go-server/internal/handler/admin_session_servicer.go`.

The service enrolls operators by stable user ID, stores AES-GCM encrypted TOTP
secrets with a key ID, verifies password plus RFC 6238 TOTP challenges, stores
only SHA-256 hashes of opaque browser session values, rotates CSRF after MFA and
step-up, persists replay counters, applies idle and absolute expiry, reloads
security generation and membership on every request, and revokes sessions on
logout, demotion, compromise, or break-glass recovery. Failed password/TOTP
challenges use the T02 shared HMAC quota (account/IP, IP, and global buckets)
without changing the consumer login lock counter. The middleware rejects
Bearer-only admin access, enforces stable capability checks, fails closed for
an unset admin origin, and emits credentialed CORS only for the configured
origin.

`go-server/cmd/admin-auth` provides explicit `bootstrap`, `enroll`, and
`recover-mfa` operations. Enrollment is idempotent and prints a newly created
TOTP secret only as the deliberate one-time operator handoff; the HTTP API,
logs, and audit metadata never contain it. Break-glass recovery rotates the
secret, revokes browser sessions, and records the stable actor and target IDs.

No OpenAPI, generated API/server, database schema/query, consumer auth, jobs,
Flutter, or server `main.go` files were changed. Route/config/CORS composition
remains allocated to the coordinator.

## Red/green evidence

The initial DB enrollment test was red at the service boundary because the
newly written test referenced the not-yet-implemented
`AdminAuth.EnrollAdminOperator` symbol. The implementation added that symbol
and the following focused suite is green against the disposable PostGIS
database. The test DSN was sourced from the reviewed T03 environment file;
its value is intentionally omitted here.

```text
set -a; source /root/.t3/worktrees/MonaServer/t3code-76e6aaef/.superpowers/sdd/web-admin-and-email-login/.env.test.T03; set +a
TEST_DATABASE_URL="$TEST_DATABASE_URL" mise exec -- go test -count=1 -p 1 ./internal/service ./internal/middleware ./internal/handler ./cmd/admin-auth
ok  github.com/lrprojects/monaserver/internal/service       19.299s
ok  github.com/lrprojects/monaserver/internal/middleware     0.003s
ok  github.com/lrprojects/monaserver/internal/handler       11.624s
ok  github.com/lrprojects/monaserver/cmd/admin-auth          0.008s
```

The focused handler test drives the generated admin-session controller through
bootstrap, wrong-CSRF rejection, password challenge, MFA, cookie flags, GET
restoration, step-up CSRF rotation, stale-CSRF rejection, and logout. DB tests
also cover replay, IP/account/global throttling, consumer counter isolation,
encrypted idempotent enrollment, expiry, demotion, compromise, self-target
revocation/job pause, and break-glass audit attribution.

```text
mise exec -- go vet ./internal/service ./internal/middleware ./internal/handler ./cmd/admin-auth
PASS (no diagnostics)

git diff --check
PASS (no diagnostics)
```

## Local service availability

PostgreSQL/PostGIS was available on `127.0.0.1:5432` and the disposable DB
tests ran serially with `-p 1`. Docker and Podman were unavailable. RustFS was
installed but not started because this slice has no object-storage dependency.
SMTP and Firebase were not configured or contacted; no real providers were
used.
