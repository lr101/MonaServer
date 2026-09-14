# Repository guide

## Working scope

The maintained server lives in `go-server/`. Use `go-server/README.md` for its runtime configuration.

The main repository areas are:

- `go-server/`: Go module, server source, tests, generators, and container image.
- `api/`: API contract. `api/openapi.yaml` is the bundled specification consumed by the Go generators.
- `docker-compose.dev.yml`: local Go server, PostGIS, and RustFS stack.
- `mise.toml`: pinned local Go version and common build tasks.

Nested guides are conditional references: consult `api/AGENTS.md` when a
change touches the OpenAPI contract, `go-server/AGENTS.md` for substantive
Go-server changes, and `go-server/internal/db/AGENTS.md` for SQL or migration
changes. Skip nested guides for unrelated or trivial edits.

## Safe local checks

Local formatting, vetting, tests, and builds are safe to run without asking when they are relevant to the change. Use the narrowest applicable check; do not publish, deploy, or access non-local services unless the task explicitly includes it.

The repository provides these repeatable checks from the repository root:

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

PostgreSQL and PostGIS are OS-level test dependencies, not mise tools. For the
complete agent-friendly service lifecycle, including the Dockerless native path
used by this environment, read [`docs/AGENT_LOCAL_STACK.md`](docs/AGENT_LOCAL_STACK.md).
If only database setup is needed, also follow `go-server/internal/db/AGENTS.md`.
Do not stop at the plain test suite when database behavior changed.

## Agent-local service stack

When a change needs API, database, object storage, or Flutter Web validation,
follow [`docs/AGENT_LOCAL_STACK.md`](docs/AGENT_LOCAL_STACK.md) before starting
services. Choose its Compose profile only when Docker or Podman is actually
available; otherwise use its native PostgreSQL/PostGIS and foreground RustFS
profile. Report which services were running and which capabilities were not
available in the verification summary.

## Change rules

- Keep API behavior, `api/openapi.yaml`, generated API code, handlers, and route authorization in sync.
- Do not edit files below `go-server/internal/gen/` by hand except the explicitly preserved compatibility adapters listed in `go-server/internal/gen/server/.openapi-generator-ignore`. Change generator sources whenever they can represent the required behavior.
- Add database changes as new migrations. Do not rewrite a migration that may have run in another environment.
- Keep credentials out of commits and command output. `.env`, `.env.dev`, and `.env.test` are ignored for this reason.
- Do not mix dependency upgrades or generated-file churn into an unrelated change.
- Preserve wire compatibility unless the task explicitly changes the API contract. Clients depend on field names, status codes, JWT claims, and object keys.

## Pull request workflow

- Create a pull request only when the user or an explicit workflow requests one; target `develop` by default.

## Checks before handoff

Report verification evidence for the checks required by the change. API and database changes also require their generated files and the conditional checks named in their nested guides.
