# MonaServer

Go backend for the **Stick-It** API. It preserves the established endpoints,
PostgreSQL/PostGIS schema, password hashes, refresh tokens, and object-store key
layout.

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
export JWT_SECRET="change-me"
export TOKEN_ADMIN_USERNAME="root"   # account whose username grants ADMIN role
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

| Variable | Default | Notes |
|---|---|---|
| `PORT` | `8080` | HTTP listen port |
| `DATABASE_URL` | — | `postgres://user:pw@host:5432/db?sslmode=disable` |
| `JWT_SECRET` | — | HS256 signing key |
| `TOKEN_ACCESS_EXPIRY` | `15m` | Go duration string |
| `TOKEN_REFRESH_EXPIRY` | `8760h` | Go duration string (1 year) |
| `TOKEN_ADMIN_USERNAME` | — | Username whose JWTs are granted the `ADMIN` role |
| `APP_MAX_LOGIN_ATTEMPTS` | `10` | Failed-login lockout threshold |
| `PUBLIC_EMAIL_LOGIN` | `false` | Enables the v3 email-link and own-session revoke routes; restricted recovery completion remains unavailable |
| `EMAIL_LOGIN_HMAC_KEY`, `EMAIL_LOGIN_HMAC_KEY_ID` | — | At least 32 bytes and stable ID for public request quotas; required when email login is enabled |
| `EMAIL_DELIVERY_KEY`, `EMAIL_DELIVERY_KEY_ID` | — | 32-byte AES key and stable ID for durable email payloads; required when email login is enabled |
| `EMAIL_LOGIN_CALLBACK_URL` | — | Flutter web callback URL such as `https://app.example/#/email-login/callback`; required when email login is enabled |
| `WEB_ADMIN_API` | `true` | Enables the browser-admin session and migrated v2/v3 admin routes; `false` returns the unavailable response for the complete admin surface |
| `ADMIN_TOTP_ENCRYPTION_KEY`, `ADMIN_TOTP_ENCRYPTION_KEY_ID` | — / `admin-totp-v1` | Key material and key ID for encrypted admin TOTP enrollment secrets |
| `ADMIN_SESSION_HMAC_KEY`, `ADMIN_SESSION_HMAC_KEY_ID` | — / `admin-quota-v1` | Required key material and key ID for admin login-failure and report submission quotas |
| `ADMIN_FIRST_RUN_TOKEN` | — | One-time deployment secret (at least 32 characters) for enrolling the first administrator from the admin web login page; remove after setup |
| `ADMIN_BOOTSTRAP_USERNAME`, `ADMIN_BOOTSTRAP_PASSWORD`, `ADMIN_BOOTSTRAP_TOTP_SECRET` | — | Optional first-launch admin account. Set all three together; startup creates the account and MFA membership only if no admin has ever been enrolled |
| `ADMIN_ORIGIN` | — | Exact browser origin allowed for admin CORS and state-changing requests |
| `TRUSTED_PROXY_CIDRS` | — | Proxies allowed to supply `X-Forwarded-For` or `X-Real-IP`; direct peers remain authoritative |
| `ADMIN_SESSION_IDLE_TTL` / `ADMIN_SESSION_ABSOLUTE_TTL` | `30m` / `8h` | Browser session idle and absolute expiry |
| `ADMIN_CHALLENGE_TTL` / `ADMIN_RECENT_MFA_TTL` | `5m` / `5m` | Password challenge and action-bound recent-MFA windows |
| `ADMIN_PREAUTH_TTL` | `10m` | Pre-authentication browser envelope lifetime |
| `ADMIN_LOGIN_FAILURE_LIMIT` / `ADMIN_LOGIN_IP_LIMIT` / `ADMIN_LOGIN_GLOBAL_LIMIT` | `5` / `100` / `1000` | Shared account, IP, and global admin proof-failure quotas |
| `APP_URL` / `APP_REDIRECT_URL` | — | Public URL; used in email links |
| `RUSTFS_ENDPOINT` | — | Internal S3 endpoint, e.g. `rustfs:9000` |
| `RUSTFS_EXTERNAL_ENDPOINT` | same as `RUSTFS_ENDPOINT` | Host rewritten into presigned URLs returned to clients |
| `RUSTFS_ACCESS_KEY`, `RUSTFS_SECRET_KEY` | — | credentials |
| `RUSTFS_BUCKET` | `monaserver` | bucket name |
| `RUSTFS_USE_SSL` | `false` | |
| `RUSTFS_URL_EXPIRY` | `60m` | presigned URL TTL |
| `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM` | — | STARTTLS on port 587, SSL on 465, plain otherwise |
| `FIREBASE_CONFIG_PATH` | — | Path to service-account JSON; if missing, FCM sends are no-ops |
| `ACHIEVEMENT_MONA_GROUP_ID` | — | Group used by the legacy Mona achievement |
| `ACHIEVEMENT_CREATED_BEFORE` | — | RFC3339 cutoff used by the legacy Mona achievement |

For Compose deployment, see [`../docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md).
The root `.env` supplies runtime settings to the app container. Set the admin
keys there and keep them stable. The `ADMIN_FIRST_RUN_TOKEN` or the three
`ADMIN_BOOTSTRAP_*` values may be set temporarily for first enrollment, then
removed after the admin account is created.

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
| `/api/v2/admin/*` | Browser-admin session cookie + same-site origin, CSRF, capability, and action-bound recent MFA; unavailable when `WEB_ADMIN_API=false` |
| `/api/v3/admin/*` | Browser-admin session cookie + same-site origin, CSRF, capability, and action-bound recent MFA; unavailable when `WEB_ADMIN_API=false` |
| `/api/v3/sync` | JWT + `USER` role |

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
