# MonaServer — Go Port

Go rewrite of the Kotlin/Spring Boot **Stick-It** API. Wire-compatible: same
endpoints, same JWT, same PostgreSQL/PostGIS schema, same MinIO bucket layout,
so both servers can run against the same database and object store during
migration.

## Requirements

- **Go 1.25+** (required by transitive deps — Firebase Admin, `kin-openapi`)
- **PostgreSQL 14+ with PostGIS** (any version `postgis/postgis:17-master`
  supports). The database is migrated on startup by `golang-migrate` from the
  embedded SQL files in `internal/db/migrations/`.
- **MinIO** (or any S3-compatible store) — optional at startup; image endpoints
  are unreachable if unconfigured.
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
export PORT=8081
go run ./cmd/server
```

Migrations run automatically at startup; the server begins accepting traffic
only after they succeed.

## Configuration (environment variables)

| Variable | Default | Notes |
|---|---|---|
| `PORT` | `8081` | HTTP listen port |
| `DATABASE_URL` | — | `postgres://user:pw@host:5432/db?sslmode=disable` |
| `JWT_SECRET` | — | HS256 signing key, **must match** Kotlin deployment during migration |
| `TOKEN_ACCESS_EXPIRY` | `15m` | Go duration string |
| `TOKEN_REFRESH_EXPIRY` | `8760h` | Go duration string (1 year) |
| `TOKEN_ADMIN_USERNAME` | — | Username whose JWTs are granted the `ADMIN` role |
| `APP_MAX_LOGIN_ATTEMPTS` | `10` | Failed-login lockout threshold |
| `APP_URL` / `APP_REDIRECT_URL` | — | Public URL; used in email links |
| `MINIO_ENDPOINT` | — | e.g. `minio.example.com:9000` |
| `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY` | — | credentials |
| `MINIO_BUCKET` | `monaserver` | bucket name |
| `MINIO_USE_SSL` | `false` | |
| `MINIO_URL_EXPIRY` | `60m` | presigned URL TTL |
| `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM` | — | STARTTLS on port 587, SSL on 465, plain otherwise |
| `FIREBASE_CONFIG_PATH` | — | Path to service-account JSON; if missing, FCM sends are no-ops |

## API

The source of truth is the OpenAPI spec at `../api/openapi.yaml`. The Go server
types and `ServerInterface` are generated from it via `oapi-codegen`:

```bash
make gen-api    # regenerates internal/gen/api/api.gen.go
```

The running server exposes the bundled spec at the same path as SpringDoc does
in the Kotlin build:

| Path | Content |
|---|---|
| `GET /public/api-docs` | OpenAPI 3.0.3 JSON (embedded into the binary) |
| `GET /swagger-ui`      | Swagger UI HTML page pointing at the spec above |

Endpoints, auth, and RBAC are identical to the Kotlin deployment:

| Path prefix | Auth |
|---|---|
| `/api/v2/public/*` | none (signup, login, refresh) |
| `/api/v2/*` | JWT + `USER` role |
| `/api/v2/admin/*` | JWT + `ADMIN` role (username == `TOKEN_ADMIN_USERNAME`) |
| `/api/v3/sync` | JWT + `USER` role |

Fine-grained guards (group admin, group member, pin creator, etc.) are applied
as chi middleware per-route and execute the same SQL checks as the Kotlin
`Guard` component.

## Build

```bash
make build                      # local binary -> bin/server
docker build -t stick-it-go .   # multi-stage -> distroless static image
```

The container image is ~15 MB (distroless/static), runs as `nonroot`, and
listens on `:8081`. All HTML templates, SQL migrations, and pin template PNGs
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
