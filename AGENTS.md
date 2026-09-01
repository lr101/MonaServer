# Repository guide

## Working scope

The maintained server lives in `go-server/`. Use `go-server/README.md` for its runtime configuration.

The main repository areas are:

- `go-server/`: Go module, server source, tests, generators, and container image.
- `api/`: API contract. `api/openapi.yaml` is the bundled specification consumed by the Go generators.
- `docker-compose.dev.yml`: local Go server, PostGIS, and RustFS stack.
- `docker-compose.yml`: deployment stack using the published Go image.
- `mise.toml`: pinned local Go version and common build tasks.

Read the nearest nested `AGENTS.md` before editing files below `go-server/`, `go-server/internal/db/`, or `api/`. Its rules add to this file.

## Toolchain and common commands

Run these commands from the repository root:

```bash
mise install
mise run test
mise run build
```

`mise run build` writes `go-server/bin/server`. Treat that binary as a local artifact and never commit it.

For a normal Go change, format the files you touched and run vet as well:

```bash
cd go-server
mise exec -- gofmt -w path/to/changed.go
mise exec -- go vet ./...
mise exec -- go test ./...
```

Tests that need PostGIS skip when `TEST_DATABASE_URL` is unset. A passing plain test run does not mean the database tests ran. Database tests truncate shared tables, so point them only at a disposable test database and run them serially.

PostgreSQL and PostGIS are OS-level test dependencies, not mise tools. If the container has no database or container runtime, follow the native Debian setup in `go-server/internal/db/AGENTS.md`. Do not stop at the plain test suite when database behavior changed.

## Change rules

- Keep API behavior, `api/openapi.yaml`, generated API code, handlers, and route authorization in sync.
- Do not edit files below `go-server/internal/gen/` by hand except the explicitly preserved compatibility adapters listed in `go-server/internal/gen/server/.openapi-generator-ignore`. Change generator sources whenever they can represent the required behavior.
- Add database changes as new migrations. Do not rewrite a migration that may have run in another environment.
- Keep credentials out of commits and command output. `.env` and `.env.dev` are ignored for this reason.
- Do not mix dependency upgrades or generated-file churn into an unrelated change.
- Preserve wire compatibility unless the task explicitly changes the API contract. Clients depend on field names, status codes, JWT claims, and object keys.

## Pull request workflow

- Always target `develop` as the base branch for pull requests. Use another base only when explicitly requested.
- After a coding run reaches a completed state, always create a pull request for its changes before handoff.

## Checks before handoff

At minimum, run the narrow test for the package you changed, then `mise exec -- go test ./...`. Run `mise exec -- go vet ./...` for code changes. API and database changes also require their generated files and the checks named in their nested guides.
