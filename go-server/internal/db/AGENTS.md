# Database guide

## Sources and generated output

The schema source is `migrations/*.up.sql`. The application embeds these files and runs them at startup with `golang-migrate`.

SQL used by sqlc lives in `queries/*.sql`. `sqlc.yaml` writes generated pgx code to `../gen/db/`. Do not edit `internal/gen/db/` by hand.

`queries.go` is the hand-written facade over sqlc. It converts pgx values to the types used by services. `achievements.go` and a few compatibility helpers contain deliberate raw SQL. For normal CRUD work, add a named sqlc query and expose it through the facade instead of adding another SQL string to a service.

## Migrations

- Add the next zero-padded migration number. The current sequence ends at `000022`.
- Add a new migration for every deployed schema change. Never change an existing migration to repair a later state.
- Keep migrations safe for startup. The HTTP server does not listen until every pending migration succeeds.
- This repository currently stores forward migrations only. Do not invent a down migration unless the project adopts that policy.
- Keep PostGIS behavior in mind. Integration tests and production use PostgreSQL with the PostGIS extension, not plain PostgreSQL.

## Query changes

Use sqlc annotations such as `:one`, `:many`, and `:exec` according to the result shape. Follow the existing nullable `pgtype` conversion helpers in `queries.go`. Preserve `is_deleted = FALSE` filters where callers expect active records only.

After changing `queries/*.sql`, `sqlc.yaml`, or a query-visible schema:

```bash
cd go-server
mise exec -- make gen-db
mise exec -- gofmt -w internal/db/*.go
mise exec -- go test ./internal/db ./internal/service
```

The generation command requires `sqlc` on `PATH`. The checked-in output records sqlc v1.31.1. Match that version to avoid unrelated generated diffs. Review the result because a query rename can affect the facade and several services even when generation succeeds.

## Database tests

Integration helpers run the complete migration chain and issue `TRUNCATE ... CASCADE`. Use a disposable database and serialize packages:

```bash
cd go-server
TEST_DATABASE_URL='postgres://monaserver:monaserver@localhost:5433/monaserver_test?sslmode=disable' \
mise exec -- go test -p 1 ./...
```

Do not add `t.Parallel()` to tests that share this database. Test both the SQL behavior and the service behavior when a schema or query change affects business rules.
