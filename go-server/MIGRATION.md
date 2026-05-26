# Migrating from Kotlin/Spring Boot to Go

The Go server is wire-compatible with the Kotlin deployment. Both can point at
the same PostgreSQL+PostGIS database and the same MinIO (or RustFS) bucket.

## API compatibility

All Kotlin API paths are supported. The Go server introduces cleaned-up canonical
paths **and** registers every old Kotlin path as an alias, so existing mobile
clients work without any changes.

### Path aliases (Kotlin → Go canonical)

| Old Kotlin path | Go canonical path |
|---|---|
| `POST /api/v2/public/signup` | `POST /api/v2/auth/signup` |
| `POST /api/v2/public/login` | `POST /api/v2/auth/login` |
| `POST /api/v2/public/refresh` | `POST /api/v2/auth/refresh` |
| `POST /api/v2/public/delete-code/{username}` | `POST /api/v2/auth/delete-code/{username}` |
| `GET /api/v2/public/recover?email=` | `GET /api/v2/auth/recover/{username}` |
| `GET /api/v2/public/infos` | `GET /api/v2/public/info` |
| `GET /api/v2/users/{userId}/profile_picture` | `GET /api/v2/users/{userId}/image` |
| `GET /api/v2/users/{userId}/profile_picture_small` | `GET /api/v2/users/{userId}/image/small` |
| `GET /api/v2/groups/{groupId}/profile_image` | `GET /api/v2/groups/{groupId}/image` |
| `GET /api/v2/groups/{groupId}/profile_image_small` | `GET /api/v2/groups/{groupId}/image/small` |
| `GET /api/v2/groups/{groupId}/pin_image` | `GET /api/v2/groups/{groupId}/pin-image` |
| `GET /api/v2/groups/{groupId}/invite_url` | `GET /api/v2/groups/{groupId}/invite-url` |
| `GET /api/v2/groups/{groupId}/members` | `GET /api/v2/members/groups/{groupId}` |
| `POST /api/v2/groups/{groupId}/members/{userId}` | `POST /api/v2/members/groups/{groupId}/users/{userId}` |
| `DELETE /api/v2/groups/{groupId}/members/{userId}` | `DELETE /api/v2/members/groups/{groupId}/users/{userId}` |
| `GET /api/v2/pins/{pinId}/likes` | `GET /api/v2/likes/pins/{pinId}` |
| `POST /api/v2/pins/{pinId}/likes` | `POST /api/v2/likes/pins/{pinId}` |
| `GET /api/v2/users/{userId}/likes` | `GET /api/v2/likes/users/{userId}` |
| `GET /api/v2/ranking/group` | `GET /api/v2/ranking/groups` |
| `GET /api/v2/ranking/user` | `GET /api/v2/ranking/users` |
| `GET /api/v2/map` | `GET /api/v2/ranking/map-info` |
| `GET /api/v2/map/geojson` | `GET /api/v2/ranking/geojson` |
| `POST /api/v2/admin/notification` | `POST /api/v2/admin/notifications` |
| `POST /api/v2/report` | `POST /api/v2/reports` |
| `POST /api/v2/users/{userId}/achievements/{achievementId}` | `POST /api/v2/users/{userId}/achievements/{achievementId}/claim` |
| `GET /api/v2/pins` (GET with query params) | `POST /api/v2/pins/sync` (JSON body) |
| `GET /api/v3/sync?since=` | `GET /api/v2/pins/sync/lastSeen?lastSeen=` |

Query parameter aliases:
- `GET /api/v2/pins/sync/lastSeen` accepts both `?lastSeen=` and `?since=`.

### Identical paths (no change required)

`GET/PUT/DELETE /api/v2/groups/{groupId}`, `POST /api/v2/groups`,
`GET /api/v2/groups`, `GET /api/v2/groups/{groupId}/admin`,
`GET /api/v2/groups/{groupId}/description`, `GET /api/v2/groups/{groupId}/link`,
`GET/DELETE /api/v2/pins/{pinId}`, `POST /api/v2/pins`,
`GET /api/v2/pins/{pinId}/image`, `GET /api/v2/status`,
`GET/PUT/DELETE /api/v2/users/{userId}`, `GET /api/v2/users/{userId}/xp`,
`GET /api/v2/users/{userId}/achievements`, `GET /api/v2/ranking/search`,
`POST /api/v2/admin/mail`, `GET /api/v2/public/info`.

### Other compatibility guarantees

| Surface | Behavior |
|---|---|
| JWT format | HS256, subject = user UUID — tokens issued by Kotlin validate in Go when `JWT_SECRET` matches |
| Role model | Admin granted by username match on `TOKEN_ADMIN_USERNAME` |
| Database schema | Unchanged — the 22 Flyway migrations are identical SQL |
| MinIO object keys | Identical (`pins/{id}.png`, `users/{id}/profile.png`, etc.) |

## Environment variable mapping

| Kotlin (`application.yml` / env) | Go env var |
|---|---|
| `DB_URL` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | `DATABASE_URL` (combined DSN) |
| `app.token.secret` | `JWT_SECRET` |
| `app.token.access-token-exploration` | `TOKEN_ACCESS_EXPIRY` (Go duration, e.g. `15m`) |
| `app.token.refresh-token-exploration` | `TOKEN_REFRESH_EXPIRY` |
| `app.token.admin-account-name` | `TOKEN_ADMIN_USERNAME` |
| `app.config.maxLoginAttempts` | `APP_MAX_LOGIN_ATTEMPTS` |
| `app.config.url` | `APP_URL` |
| `app.config.redirectUrl` | `APP_REDIRECT_URL` |
| `app.minio.endpoint` | `MINIO_ENDPOINT` (**without** `http://` prefix — Go SDK takes `host:port`) |
| `app.minio.accessKey` | `MINIO_ACCESS_KEY` |
| `app.minio.secretKey` | `MINIO_SECRET_KEY` |
| `app.minio.bucket` | `MINIO_BUCKET` |
| `app.minio.useSSL` | `MINIO_USE_SSL` |
| `spring.mail.host` | `MAIL_HOST` |
| `spring.mail.port` | `MAIL_PORT` |
| `spring.mail.username` | `MAIL_USERNAME` |
| `spring.mail.password` | `MAIL_PASSWORD` |
| `app.config.mail` | `MAIL_FROM` |
| `app.config.firebaseConfigPath` | `FIREBASE_CONFIG_PATH` |
| (new) achievement config | `ACHIEVEMENT_MONA_GROUP_ID`, `ACHIEVEMENT_CREATED_BEFORE` (RFC3339) |

> **MINIO_ENDPOINT format**: Kotlin accepted `http://host:port`; Go needs `host:port`.
> Strip the scheme: `MINIO_ENDPOINT=minio:9000` (not `http://minio:9000`).

## One-time Flyway → golang-migrate handoff

Flyway tracks applied migrations in `flyway_schema_history`.
`golang-migrate` uses `schema_migrations`. On a production database that already
has the 22 Kotlin migrations applied you **must** seed this table before starting
the Go server, otherwise it will try to re-run all 22 migrations and fail.

Run this SQL once against the production database:

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
    version bigint  NOT NULL PRIMARY KEY,
    dirty   boolean NOT NULL
);
INSERT INTO schema_migrations (version, dirty)
VALUES (22, false)
ON CONFLICT (version) DO NOTHING;
```

`22` is the current highest migration version (`000022_fix_member_primary_key.up.sql`).
After this insert the Go startup migration step is a no-op and will only pick up
new migration files you add going forward.

## Cutover procedure

1. **Back up** — `pg_dump` the production PostgreSQL database.
2. **Seed schema_migrations** — run the SQL above against the production DB.
3. **Build the Go image** — `docker build -t go-server:latest ./go-server`.
4. **Set environment variables** — map all Kotlin vars to Go vars (table above).
   Pay attention to `MINIO_ENDPOINT` format.
5. **Start Go server** alongside Kotlin (different port).
6. **Smoke test** — hit key endpoints on the Go server port:
   - `POST /api/v2/auth/login` (and old alias `POST /api/v2/public/login`)
   - `GET /api/v2/groups` (authenticated)
   - `POST /api/v2/pins/sync`
   - `GET /api/v2/pins/sync/lastSeen`
7. **Cut traffic** — update load balancer / docker-compose to route to the Go server.
8. **Decommission Kotlin** — retain the image for one sprint for rollback.

## Rollback

The Go server writes no data incompatible with Kotlin. To revert:

1. Point the load balancer back at the Kotlin container.
2. `schema_migrations` left behind is harmless — Flyway ignores it.

## Automated cutover script

See `scripts/migrate-to-go.sh` for a script that performs steps 2–7 automatically.
Run it with `--dry-run` first to preview all actions.
