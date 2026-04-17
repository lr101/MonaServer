# Migrating from Kotlin/Spring Boot to Go

The Go server is wire-compatible with the Kotlin deployment. Both can point at
the same PostgreSQL+PostGIS database and the same MinIO bucket, so the cut-over
can be staged or even rolled back.

## Compatibility guarantees

| Surface | Behavior |
|---|---|
| HTTP routes + verbs | identical (`api/openapi.yaml` is the shared source of truth) |
| Request/response JSON shapes | identical |
| JWT format | HS256, subject = user UUID string — tokens issued by Kotlin validate in Go and vice versa *as long as `JWT_SECRET` matches the Kotlin `app.token.secret`* |
| Role model | `ADMIN` still granted by username match against `TOKEN_ADMIN_USERNAME` (same env var semantics as Kotlin's `app.token.admin-account-name`) |
| Database schema | unchanged — the 22 Kotlin Flyway migrations are the same SQL, embedded in the Go binary |
| MinIO layout | identical object keys (`pins/{id}.png`, `groups/{id}/group_profile.png`, etc.) |
| Spring `delete_log` audit entries | preserved (handled inside the SQL migrations; Go writes through the same tables) |

## Pre-migration checklist

1. **Back up the database.** `pg_dump` against your prod PostgreSQL.
2. **Copy env vars to the new deployment**, mapping Kotlin keys to Go keys:

   | Kotlin (`application.yml` / env) | Go env var |
   |---|---|
   | `DB_URL` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | `DATABASE_URL` (combined) |
   | `app.token.secret` | `JWT_SECRET` |
   | `app.token.access-token-exploration` | `TOKEN_ACCESS_EXPIRY` (Go duration string, e.g. `15m`) |
   | `app.token.refresh-token-exploration` | `TOKEN_REFRESH_EXPIRY` |
   | `app.token.admin-account-name` | `TOKEN_ADMIN_USERNAME` |
   | `app.config.maxLoginAttempts` | `APP_MAX_LOGIN_ATTEMPTS` |
   | `app.config.url` | `APP_URL` |
   | `app.config.redirectUrl` | `APP_REDIRECT_URL` |
   | `app.minio.*` | `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `MINIO_BUCKET`, `MINIO_USE_SSL` |
   | `spring.mail.*` | `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM` |
   | `app.config.firebaseConfigPath` | `FIREBASE_CONFIG_PATH` |

3. **Do not run the Go migrator against the prod DB** until you've confirmed
   on a staging copy that it is a no-op. The renamed files
   (`000001_…up.sql`) contain the same SQL that Flyway already applied, but
   they use a different bookkeeping table (`schema_migrations` vs.
   `flyway_schema_history`). See the note below.

## One-time Flyway → golang-migrate handoff

Flyway tracks applied versions in `flyway_schema_history`. `golang-migrate`
tracks them in `schema_migrations`. Before starting the Go server the first
time, seed `schema_migrations` so migrations are marked as already-applied:

```sql
-- Run against prod DB before the first Go boot.
CREATE TABLE IF NOT EXISTS schema_migrations (
    version bigint  NOT NULL PRIMARY KEY,
    dirty   boolean NOT NULL
);
INSERT INTO schema_migrations (version, dirty) VALUES (22, false)
    ON CONFLICT (version) DO NOTHING;
```

`22` is the highest version currently shipped (file `000022_fix_member_primary_key.up.sql`).
After this, Go's startup migration step is a no-op and will pick up only new
migration files you add going forward.

If you prefer to run both in parallel during a gradual rollout, leave Flyway as
the authoritative migrator on the Kotlin side and keep the Go migration step
seeded to the current version — Go will stay idle while Kotlin keeps adding
versions, and you promote new SQL files to the Go tree (`internal/db/migrations/`)
only when ready to own migrations from Go.

## Suggested rollout

1. **Deploy Go in shadow mode.** Run it on an internal port pointed at the
   same DB + MinIO + Firebase. Issue a login, a group fetch, and a pin upload
   via both servers and diff the responses.
2. **Cut over a fraction of traffic** via your load balancer (e.g. 10% to the
   Go image tag). Watch `4xx/5xx` rates on both pools.
3. **Flip remaining traffic.** JWTs issued by Kotlin continue to validate
   against Go; users do not need to re-authenticate.
4. **Decommission the Kotlin deployment.** Retain its image tag for at least
   one release cycle in case of rollback.

## Rollback

The Go server does not write any data incompatible with Kotlin. If you need to
revert:

1. Point the load balancer back at the Kotlin image.
2. `schema_migrations` left behind by Go is harmless — Flyway ignores it.

## Outstanding work

Auth and the RBAC chain are fully implemented. Handler bodies for groups,
pins, users, members, likes, ranking, reports, admin, and the HTML views are
stubbed to `501 Not Implemented` — the chi middleware chain (JWT + role +
per-route guards) is already wired on each route, so implementation is a pure
service-layer task.

Track the stubs by grepping for `handler.NotImplemented` in
`cmd/server/main.go`.
