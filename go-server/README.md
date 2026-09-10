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
| `APP_URL` / `APP_REDIRECT_URL` | — | Public URL; used in email links |
| `RUSTFS_ENDPOINT` | — | Internal S3 endpoint, e.g. `rustfs:9000` |
| `RUSTFS_EXTERNAL_ENDPOINT` | same as `RUSTFS_ENDPOINT` | Host rewritten into presigned URLs returned to clients |
| `RUSTFS_ACCESS_KEY`, `RUSTFS_SECRET_KEY` | — | credentials |
| `RUSTFS_BUCKET` | `monaserver` | bucket name |
| `RUSTFS_USE_SSL` | `false` | TLS scheme used by the internal S3 client |
| `RUSTFS_EXTERNAL_USE_SSL` | same as `RUSTFS_USE_SSL` | TLS scheme used for presigned URLs; useful when a proxy terminates public TLS |
| `RUSTFS_URL_EXPIRY` | `60m` | presigned URL TTL |
| `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM` | — | STARTTLS on port 587, SSL on 465, plain otherwise |
| `FIREBASE_CONFIG_PATH` | — | Path to service-account JSON; if missing, FCM sends are no-ops |
| `ACHIEVEMENT_MONA_GROUP_ID` | — | Group used by the legacy Mona achievement |
| `ACHIEVEMENT_CREATED_BEFORE` | — | RFC3339 cutoff used by the legacy Mona achievement |

### Docker Compose configuration

Create an ignored `.env` file for deployments (or `.env.dev` for
`docker-compose.dev.yml`). A current configuration looks like this:

```dotenv
HOST_PORT=8080
POSTGRES_USER=monaserver
POSTGRES_PASSWORD=<database-password>
POSTGRES_DB=monaserver
DATABASE_URL=postgres://monaserver:URL_ENCODED_PASSWORD@db:5432/monaserver?sslmode=disable

JWT_SECRET=<strong-random-secret>
TOKEN_ACCESS_EXPIRY=15m
TOKEN_REFRESH_EXPIRY=8760h
TOKEN_ADMIN_USERNAME=admin
APP_MAX_LOGIN_ATTEMPTS=10

APP_URL=https://api.example.com
APP_REDIRECT_URL=https://example.com

RUSTFS_ENDPOINT=minio:9000
RUSTFS_EXTERNAL_ENDPOINT=storage.example.com:9000
RUSTFS_ACCESS_KEY=<application-access-key>
RUSTFS_SECRET_KEY=<application-secret-key>
RUSTFS_BUCKET=<bucket-name>
RUSTFS_USE_SSL=false
RUSTFS_EXTERNAL_USE_SSL=false
RUSTFS_URL_EXPIRY=60m

MAIL_HOST=
MAIL_PORT=587
MAIL_USERNAME=
MAIL_PASSWORD=
MAIL_FROM=
FIREBASE_CONFIG_PATH=

ACHIEVEMENT_MONA_GROUP_ID=d9631336-5c32-4f64-83a7-7a4fcdae4dd6
ACHIEVEMENT_CREATED_BEFORE=2023-12-10T02:43:44.402768+00:00
```

`RUSTFS_ENDPOINT` is the address used by the server. The external endpoint is
written into presigned URLs returned to clients. Both use `host:port` without
a URL scheme. The deployment Compose service is `minio`; use `rustfs:9000`
instead with `docker-compose.dev.yml`. `RUSTFS_USE_SSL` controls the internal
client, while `RUSTFS_EXTERNAL_USE_SSL` controls the scheme in presigned URLs.

`HOST_PORT` controls the published Compose port. The container always listens
on `8080`. Keep the achievement values above when replacing a Spring deployment
that relied on its built-in defaults.

### One-time Spring/Flyway database handoff

The application runs every pending embedded migration before listening for
requests. A fresh database needs no manual setup. For an existing Spring
database, stop application writes and make and verify an off-host PostgreSQL
backup before starting the Go container.

Confirm that Flyway versions `1.0.0` through `1.0.21` all succeeded, that no
failed Flyway migration exists, and that `schema_migrations` does not already
exist:

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

SELECT to_regclass(current_schema() || '.schema_migrations');
```

Only after verifying the complete Flyway history, hand ownership to
`golang-migrate` in one transaction:

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
| `/api/v2/admin/*` | JWT + `ADMIN` role (username == `TOKEN_ADMIN_USERNAME`) |
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
