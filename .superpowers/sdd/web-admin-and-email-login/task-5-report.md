# Task 5 report — campaign server CRUD

Implemented content-only administrative campaign CRUD:

- OpenAPI campaign list/detail/create/update/archive/delete contract and generated Go outputs.
- `campaigns` persistence migration, sqlc queries, facade, service, handler, and browser-admin route wiring.
- `campaigns.read` for reads and `campaigns.write` for mutations, with browser-session, CSRF, recent-MFA, and capability routing.
- Bounded fields, opaque cursor pagination, revision checks, draft-only deletion, and archival lifecycle.
- No audience expansion, providers, delivery, SMTP/FCM, jobs, retries, or workers.

Verification:

- Focused RED/GREEN tests covered missing campaign routes, service validation/lifecycle/pagination, database revision/draft-delete predicates, handler CSRF/capabilities, and middleware capability/MFA mapping.
- `mise exec -- go test ./...`, `mise exec -- go vet ./...`, and `mise exec -- go build -o bin/server ./cmd/server` passed.
- The focused database facade test passed against the task-scoped disposable PostGIS database.

Limitation:

- The full database-backed suite has a pre-existing failure in
  `TestRealAdminRouterUsesBrowserSessionBoundary`: committed users wiring returns
  `200`, while that test still expects the former `503` scaffold. The shared
  database also already recorded an out-of-tree migration version `32`, so this
  task uses migration `000033` and a separate task-scoped test database without
  modifying shared migration state.
