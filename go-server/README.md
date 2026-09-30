# MonaServer

Go backend for the **Stick-It** API. It preserves the established endpoints,
PostgreSQL/PostGIS schema, password hashes, refresh tokens, and object-store key
layout. Existing Spring access tokens require refresh or login after cutover.

## Requirements

- **Go 1.25+** (required by transitive deps — Firebase Admin, `kin-openapi`)
- **PostgreSQL 14+ with PostGIS** (any version `postgis/postgis:17-master`
  supports). The database is migrated on startup by `golang-migrate` from the
  embedded SQL files in `internal/db/migrations/`.
- **RustFS** (or another S3-compatible store) is optional at startup. Image
  endpoints are unreachable if it is unconfigured.
- **Firebase service-account JSON** — optional; push notification sends become
  no-ops if not provided.
- **SMTP server** — optional; only needed for password recovery, account
  deletion, email confirmation, and admin bulk mail.

## Quick start (local)

```bash
# start a PostGIS DB
podman run -d --name mona-db -e POSTGRES_USER=mona -e POSTGRES_PASSWORD=mona \
    -e POSTGRES_DB=mona -p 5432:5432 docker.io/postgis/postgis:17-master

# configure + run
cd go-server
export DATABASE_URL="postgres://mona:mona@localhost:5432/mona?sslmode=disable"
export PORT=8080
go run ./cmd/server
```

Migrations run automatically at startup; the server begins accepting traffic
only after they succeed.

For a disposable PostGIS database, RustFS instance, and Go server with
reusable app scenarios, use the repository-level test stack and fixture guide:
[`../testdata/README.md`](../testdata/README.md).

For the agent-friendly full lifecycle, including native PostgreSQL/PostGIS and
foreground RustFS when Docker or Podman is unavailable, see
[`../docs/AGENT_LOCAL_STACK.md`](../docs/AGENT_LOCAL_STACK.md).

## Configuration (environment variables)

The server generates a fresh access JWT signing key on every process start.
Existing access tokens then fail verification; database-backed refresh tokens
remain valid and can issue a new access token. Run a single API process per
deployment when using this process-local key.
Administrator access comes from database admin membership. The old
`TOKEN_ADMIN_USERNAME` setting is unused and can be removed from existing env
files.

| Variable | Default | Notes |
|---|---|---|
| `PORT` | `8080` | HTTP listen port |
| `DATABASE_URL` | — | `postgres://user:pw@host:5432/db?sslmode=disable` |
| `TOKEN_ACCESS_EXPIRY` | `15m` | Go duration string |
| `TOKEN_REFRESH_EXPIRY` | `8760h` | Go duration string (1 year) |
| `APP_MAX_LOGIN_ATTEMPTS` | `10` | Failed-login lockout threshold |
| `WEB_HOST` | — | Public hostname; canonical domain for email links and the API root redirect |
| `PUBLIC_EMAIL_LOGIN` | `false` | Enables the v3 email-link and own-session revoke routes; restricted recovery completion remains unavailable |
| `EMAIL_LOGIN_TOKEN_TTL` | `15m` | Public email sign-in link lifetime as a Go duration string; maximum `24h` |
| `EMAIL_LOGIN_HMAC_KEY`, `EMAIL_LOGIN_HMAC_KEY_ID` | — | At least 32 bytes and stable ID for public request quotas; required when email login is enabled |
| `EMAIL_DELIVERY_KEY`, `EMAIL_DELIVERY_KEY_ID` | — | 32-byte AES key and stable ID for durable email payloads; required when email login is enabled |
| `EMAIL_LOGIN_CALLBACK_URL` | — | Flutter web callback URL such as `https://app.example/#/email-login/callback`; required when email login is enabled. The root Compose deployment derives it from `WEB_HOST`; standalone deployments must set it explicitly. |
| `WEB_ADMIN_API` | `true` | Enables the browser-admin session and migrated v2/v3 admin routes; `false` returns the unavailable response for the complete admin surface |
| `ADMIN_TOTP_ENCRYPTION_KEY`, `ADMIN_TOTP_ENCRYPTION_KEY_ID` | — / `admin-totp-v1` | Key material and key ID for encrypted admin TOTP enrollment secrets |
| `ADMIN_SESSION_HMAC_KEY`, `ADMIN_SESSION_HMAC_KEY_ID` | — / `admin-quota-v1` | Required key material and key ID for admin login-failure and report submission quotas |
| `ADMIN_BOOTSTRAP_USERNAME`, `ADMIN_BOOTSTRAP_PASSWORD`, `ADMIN_BOOTSTRAP_TOTP_SECRET` | — | Optional first-launch admin account. Set all three together; startup creates the account and MFA membership only if no admin has ever been enrolled |
| `TRUSTED_PROXY_CIDRS` | — | Proxies allowed to supply `X-Forwarded-For` or `X-Real-IP`; direct peers remain authoritative |
| `ADMIN_SESSION_IDLE_TTL` / `ADMIN_SESSION_ABSOLUTE_TTL` | `30m` / `8h` | Browser session idle and absolute expiry |
| `ADMIN_CHALLENGE_TTL` | `5m` | Password challenge lifetime |
| `ADMIN_PREAUTH_TTL` | `10m` | Pre-authentication browser envelope lifetime |
| `ADMIN_LOGIN_FAILURE_LIMIT` / `ADMIN_LOGIN_IP_LIMIT` / `ADMIN_LOGIN_GLOBAL_LIMIT` | `5` / `100` / `1000` | Shared account, IP, and global admin proof-failure quotas |
| `RUSTFS_ENDPOINT` | — | Internal S3 endpoint, e.g. `rustfs:9000` |
| `RUSTFS_EXTERNAL_ENDPOINT` | same as `RUSTFS_ENDPOINT` | Host rewritten into presigned URLs returned to clients |
| `RUSTFS_ACCESS_KEY`, `RUSTFS_SECRET_KEY` | — | credentials |
| `RUSTFS_BUCKET` | `monaserver` | bucket name |
| `RUSTFS_USE_SSL` | `false` | TLS for the internal S3 client |
| `RUSTFS_EXTERNAL_USE_SSL` | same as `RUSTFS_USE_SSL` | TLS scheme for externally returned presigned URLs, e.g. when Traefik terminates HTTPS |
| `RUSTFS_URL_EXPIRY` | `60m` | presigned URL TTL |
| `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM` | — | STARTTLS on port 587, SSL on 465, plain otherwise |
| `FIREBASE_CONFIG_PATH` | — | Path to service-account JSON; if missing, FCM sends are no-ops |

### One-time Spring/Flyway database handoff

The application runs every pending embedded migration before listening for
requests. A fresh database needs no manual setup. For an existing Spring
database, stop application writes and make and verify an off-host PostgreSQL
backup before starting the Go container.

Confirm that Flyway versions `1.0.0` through `1.0.21` all succeeded, that no
failed Flyway migration exists, that there are no other Flyway versions, and
that `schema_migrations` does not already exist:

```sql
SELECT installed_rank, version, description, success
FROM flyway_schema_history
ORDER BY installed_rank;

SELECT version, description
FROM flyway_schema_history
WHERE NOT success;

WITH expected(version) AS (
    SELECT '1.0.' || generate_series(0, 21)
)
SELECT expected.version AS missing_successful_version
FROM expected
LEFT JOIN flyway_schema_history AS history
    ON history.version = expected.version AND history.success
WHERE history.version IS NULL;

WITH expected(version) AS (
    SELECT '1.0.' || generate_series(0, 21)
)
SELECT history.version AS unexpected_version, history.description, history.success
FROM flyway_schema_history AS history
LEFT JOIN expected USING (version)
WHERE expected.version IS NULL
ORDER BY history.installed_rank;

SELECT version, description
FROM flyway_schema_history
WHERE success
ORDER BY installed_rank DESC
LIMIT 1;

SELECT to_regclass(current_schema() || '.schema_migrations');
```

The missing-version and unexpected-version queries must both return no rows,
the failed-migration query above must return no rows, and the newest-successful
query must return version `1.0.21` (the member primary-key migration). Only
then, hand ownership to `golang-migrate` in one transaction:

```sql
BEGIN;
CREATE TABLE schema_migrations (
    version bigint NOT NULL PRIMARY KEY,
    dirty boolean NOT NULL
);
INSERT INTO schema_migrations (version, dirty) VALUES (22, false);
COMMIT;
TABLE schema_migrations;
```

The result must contain exactly `(22, false)`. The Go server then applies
migration 23 and later migrations normally. If `schema_migrations` already
exists or the Flyway history is incomplete or dirty, stop and investigate
rather than inserting or changing a version row. Never seed version 22 on a
fresh database.

For Compose deployment, see [`../docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md).
The root `.env` supplies runtime settings to the app container. Set the admin
keys there and keep them stable. Set all three `ADMIN_BOOTSTRAP_*` values
together for first enrollment, then remove them after the admin account is
created.

### Admin permissions and superadmins

The `superadmin` permission grants every current and future admin capability.
New environment-bootstrapped admins receive this permission. On an existing
deployment, use the bundled `admin-auth` operator command once to promote an
already enrolled account; rerunning `enroll` for an active account updates its
permissions, revokes its admin sessions, and keeps its current MFA secret. The
command uses `DATABASE_URL` when set, or builds the standard Compose connection
from `POSTGRES_USER` and `POSTGRES_PASSWORD`:

```bash
docker compose exec app /app/admin-auth enroll --username admin-web --permissions superadmin
```

After that account signs in again, it can open Users, select an existing admin
account, and edit its permissions in the user editor (one permission per line).
Adding `superadmin` grants all permissions; replacing it with specific entries
removes wildcard access. Permission edits revoke the target's current admin
sessions. To enroll a regular account as an admin, use `admin-auth enroll` so
the account can set up MFA before it receives browser-admin access.

Admin permissions already use a flexible database array, so this change does
not need a database migration.

## API

The source of truth is the OpenAPI spec at `../api/openapi.yaml`. Regenerate the
Go API types and the runtime controller/model package with:

```bash
mise exec -- make gen-api
OPENAPI_GENERATOR_JAR=/path/to/openapi-generator-cli-7.19.0.jar make gen-server
```

The second command also requires Java. Normal build, test, and run workflows
need only the Go tools pinned in the repository `mise.toml`.

The running server exposes the bundled specification at these paths:

| Path | Content |
|---|---|
| `GET /public/api-docs` | OpenAPI 3.0.3 JSON (embedded into the binary) |
| `GET /swagger-ui`      | Swagger UI HTML page pointing at the spec above |

Endpoint authentication and role requirements are:

| Path prefix | Auth |
|---|---|
| `/api/v2/public/*` | none (signup, login, refresh) |
| `/api/v2/*` | JWT + `USER` role |
| `/api/v2/admin/*` | Browser-admin session cookie + CSRF, capability, and MFA at login; unavailable when `WEB_ADMIN_API=false` |
| `/api/v3/admin/*` | Browser-admin session cookie + CSRF, capability, and MFA at login; unavailable when `WEB_ADMIN_API=false` |
| `/api/v3/sync` | JWT + `USER` role |

Admin endpoints reflect any request origin and allow credentialed CORS. Their
Secure session cookie uses `SameSite=None` so browsers send it cross-site. Keep
the admin listener restricted to a trusted network or private ingress.

Fine-grained guards cover group administrators, group members, and pin creators.

## Build

```bash
make build                      # local binary -> bin/server
docker build -t stick-it-go .   # multi-stage -> distroless static image
```

The container image is ~15 MB (distroless/static), runs as `nonroot`, and
listens on `:8080`. All HTML templates, SQL migrations, and pin template PNGs
are embedded into the binary via `//go:embed`, so no extra volumes are needed.

## Testing

```bash
go test ./...                                   # unit tests
TEST_DATABASE_URL="postgres://..." go test ./... # + integration (migrations + auth flow)
```

The integration test spins up the full migration chain against a real PostGIS
database and exercises signup/login/refresh end-to-end.

## Layout

```
go-server/
├── cmd/server/              entrypoint, router, middleware wiring
├── internal/
│   ├── apperrors/           sentinel errors + WriteError helper
│   ├── config/              Viper env-var loader
│   ├── db/                  pgxpool + embedded migrations + queries
│   ├── gen/api/             oapi-codegen output (types + ServerInterface)
│   ├── handler/             HTTP handlers
│   ├── image/               pin compositing + resize (embedded PNG templates)
│   ├── middleware/          JWT, role, guards, RequireAny
│   ├── password/            bcrypt
│   ├── scheduler/           cron (weekly notification, daily season tick)
│   ├── service/             auth, guard, object, email, notification, …
│   └── token/               HS256 JWT helpers
└── Dockerfile               multi-stage, distroless runtime
```

## Faster local builds

Keep the local database/object store running and use `mise run run` from the
repository root with the runtime environment above. This runs Go directly and
reuses its module and compiler caches. Use `mise run build` when a binary is
needed; avoid clearing Go caches between edits.

Container builds cache module downloads in a layer and compiled packages in a
BuildKit cache mount. CI restores/exports that mount separately from the image
layers and cross-compiles Linux amd64/arm64 on the native builder. See
[`../docs/BUILD_SPEED.md`](../docs/BUILD_SPEED.md).
