# Go server guide

## Build and test

This directory is the Go module. The required version is declared in `go.mod` and pinned in the repository `mise.toml`.

From the repository root:

```bash
mise install
mise run build
mise run test
```

From this directory, the equivalent commands are:

```bash
mise exec -- go build -o bin/server ./cmd/server
mise exec -- go test ./...
```

Useful narrower checks are:

```bash
mise exec -- go test ./internal/service
mise exec -- go test ./internal/service -run '^TestGroup'
mise exec -- go test ./cmd/server -run '^TestEndpoint'
mise exec -- go vet ./...
```

Run `mise exec -- gofmt` on every changed Go file. Use `mise exec -- go mod tidy` only when imports or dependencies changed, and review both `go.mod` and `go.sum` afterward.

## Run locally

The process needs a reachable PostGIS database. It applies embedded migrations before opening the HTTP listener and exits if the database connection or migration fails. RustFS, Firebase, and SMTP are optional. Their dependent features remain unavailable when they are not configured.

For the complete service setup, including the Dockerless native PostgreSQL and
foreground RustFS path used by agents, follow
[`../docs/AGENT_LOCAL_STACK.md`](../docs/AGENT_LOCAL_STACK.md). It also
documents the Flutter Web and Playwright verification flow and the boundary
between a database/API check and a full-stack check.

For the full development stack, create an ignored `.env.dev` in the repository root. This is the minimum useful starting point:

```dotenv
POSTGRES_USER=monaserver
POSTGRES_PASSWORD=monaserver
DATABASE_URL=postgres://monaserver:monaserver@db:5432/monaserver?sslmode=disable
JWT_SECRET=local-only-secret
TOKEN_ADMIN_USERNAME=admin
RUSTFS_ACCESS_KEY=localadmin
RUSTFS_SECRET_KEY=local-secret-change-me
RUSTFS_ENDPOINT=rustfs:9000
RUSTFS_EXTERNAL_ENDPOINT=localhost:9000
RUSTFS_USE_SSL=false
```

Then run this from the repository root:

```bash
docker compose -f docker-compose.dev.yml up --build
```

The API listens on `http://localhost:8080`, Postgres is published on port `5433`, and the RustFS console is published on port `9001`.

To run the Go process directly while using only the Compose database:

```bash
docker compose -f docker-compose.dev.yml up -d db
cd go-server
DATABASE_URL='postgres://monaserver:monaserver@localhost:5433/monaserver?sslmode=disable' \
JWT_SECRET='local-only-secret' \
TOKEN_ADMIN_USERNAME='admin' \
mise exec -- go run ./cmd/server
```

The config loader reads process environment variables. It does not load `.env` files itself. Compose loads `.env.dev` through `env_file`.

Runtime defaults and all supported variables live in `internal/config/config.go`. `DATABASE_URL`, `JWT_SECRET`, and `TOKEN_ADMIN_USERNAME` are required for a useful server. Set `RUSTFS_ENDPOINT` as `host:port`, without an `http://` or `https://` prefix. Use `RUSTFS_EXTERNAL_ENDPOINT` when presigned URLs need a host that differs from the server's internal endpoint.

## Database-backed tests

`mise run test` runs tests that do not need external services and skips integration tests when `TEST_DATABASE_URL` is empty.

The integration suite runs migrations and truncates application tables between tests. Never point it at a development, staging, or production database. Tests share the same database, so keep `-p 1`:

```bash
TEST_DATABASE_URL='postgres://monaserver:monaserver@localhost:5433/monaserver_test?sslmode=disable' \
mise exec -- go test -p 1 ./...
```

`mise exec -- make test-integration` uses that DSN by default. Create the `monaserver_test` database first. The PostGIS extension and migration chain must be available there.

## Request flow and package map

Requests follow this path:

```text
api/openapi.yaml
  -> internal/gen/server controllers and models
  -> internal/handler HTTP adapters
  -> internal/service business rules
  -> internal/db facade
  -> internal/gen/db sqlc queries
  -> PostgreSQL/PostGIS
```

- `cmd/server/main.go` loads config, migrates the database, constructs services, partitions generated routes by authorization, starts scheduled jobs, and owns HTTP middleware.
- `internal/handler/` implements generated servicer interfaces. Keep request parsing, response conversion, and HTTP status mapping here.
- `internal/service/` owns business rules and cross-resource operations. Return typed application errors from `internal/apperrors/` when a handler must map an error to an HTTP response.
- `internal/db/` wraps pgx and sqlc types with application types. Read its nested guide before changing SQL or migrations.
- `internal/middleware/` handles JWT identity, roles, and resource guards. Authentication alone is not enough for group and pin operations; preserve the matching guard checks.
- `internal/image/`, `internal/handler/templates/`, and `internal/handler/static/` contain assets embedded into the binary with `go:embed`.
- `internal/scheduler/` registers the weekly notification and monthly season jobs.
- `internal/token/` and `internal/password/` isolate JWT and bcrypt details.

## API and routing changes

`api/openapi.yaml` is the contract. Generated controllers parse parameters, but `cmd/server/main.go` decides which middleware protects each route. When adding or moving an endpoint:

1. Update the API sources under `../api/`.
2. Regenerate both API outputs described in `../api/AGENTS.md`.
3. Implement or update the matching servicer in `internal/handler/`.
4. Put the generated route in the correct public, user, or admin group in `cmd/server/main.go`.
5. Add a server test that proves the unauthenticated and authorized behavior.

Do not assume an OpenAPI `security` entry configures chi middleware. The route grouping in `main.go` is authoritative at runtime.

## Generated code and embedded files

Never hand-edit `internal/gen/api/` or `internal/gen/db/`. Most of `internal/gen/server/` is generated too. The files listed in `internal/gen/server/.openapi-generator-ignore` are narrow compatibility adapters for behavior the generator cannot express; change them only with a focused wire-level regression test. Running `make gen-server` preserves those adapters and regenerates everything else from the API contract. It requires Java and an OpenAPI Generator CLI jar; set `OPENAPI_GENERATOR_JAR` when the jar is not at `$HOME/openapi-generator-cli.jar`.

The Docker image is a static, nonroot distroless image. Migrations, HTML templates, the favicon, and pin images are embedded at compile time. Code must not rely on the repository working directory or runtime copies of those files.

## Coding and test conventions

- Pass request contexts through handlers, services, and database calls. Do not replace them with `context.Background()` inside normal request work.
- Parse and validate external string IDs at the handler boundary. Use `uuid.UUID` inside services and database code.
- Keep HTTP-specific types out of services when a small service input or result type will do.
- Preserve soft-delete filters and visibility checks when adding queries.
- Add package-level tests beside the code. End-to-end route behavior belongs in `cmd/server/server_test.go`.
- Prefer existing test helpers in `internal/service/testsetup_test.go`. They assume serial use of one disposable database.
- Object storage, mail, and notification clients may be absent in local tests. Keep nil-safe behavior where the existing constructors allow it.
