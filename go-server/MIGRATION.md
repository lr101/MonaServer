# Migrating a Spring deployment to Go

This guide covers an existing Docker Compose deployment with PostgreSQL/PostGIS
and RustFS already in production. Keep the PostgreSQL data volume, RustFS
service, RustFS data volumes, bucket, and objects in place. Only the application
container changes.

The current Go migration chain contains the same 22 SQL migrations as the
Spring deployment. Spring records them as Flyway versions `1.0.0` through
`1.0.21`. Go records the equivalent files as versions `1` through `22` with
`golang-migrate`.

This procedure assumes that the Go image ends at
`000022_fix_member_primary_key.up.sql`. Check the migration directory for the
release you will deploy. If it contains a later version, review that migration
and its rollback impact before the cutover.

## What changes

- The Spring application container is replaced by the Go application container.
- `DATABASE_URL` replaces the separate JDBC URL and database credentials used
  by Spring.
- `golang-migrate` takes ownership of future database migrations.
- The Go server needs a stable `JWT_SECRET`.
- Application-facing object-store variables use the `RUSTFS_*` names.

PostgreSQL data and RustFS objects do not move. The Go server uses the existing
bucket and the same object keys:

```text
pins/{id}.png
groups/{id}/group_pin.png
groups/{id}/group_profile.png
groups/{id}/group_profile_small.png
users/{id}/profile.png
users/{id}/profile_small.png
```

## Before the maintenance window

Use a versioned Go image tag or digest that you have tested. Do not make the
first production cutover with `latest`.

Prepare the Go environment values before stopping Spring. The important
mappings are:

| Spring environment | Go environment | Conversion |
|---|---|---|
| `DB_URL`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | `DATABASE_URL` | Build one PostgreSQL URL. URL-encode reserved characters in the username and password. |
| none | `JWT_SECRET` | Generate a new, strong secret and keep it stable across restarts. |
| `PORT` | `HOST_PORT` | Preserve the old published port under a separate Compose variable. Set the Go container's `PORT` to `8080`. |
| `ACCESS_TOKEN_EXPIRATION` | `TOKEN_ACCESS_EXPIRY` | Add a Go duration unit. For example, `900` becomes `900s` or `15m`. |
| `REFRESH_TOKEN_EXPIRATION` | `TOKEN_REFRESH_EXPIRY` | Add a Go duration unit. For example, `31556952` becomes `31556952s`. |
| `ADMIN_ACCOUNT_NAME` | `TOKEN_ADMIN_USERNAME` | Copy the existing admin username. |
| `MAX_LOGIN_ATTEMPTS` | `APP_MAX_LOGIN_ATTEMPTS` | Copy the existing integer. |
| `APP_URL` | `APP_URL` | Keep the public application URL. |
| `REDIRECT_URL` | `APP_REDIRECT_URL` | Copy the existing value. Spring defaulted it to `https://app.lr-projects.de` when it was unset. |
| `MINIO_ENDPOINT` | `RUSTFS_ENDPOINT`, `RUSTFS_EXTERNAL_ENDPOINT` | Remove `http://` or `https://` and set `RUSTFS_USE_SSL` explicitly. |
| `MINIO_ACCESS_KEY` | `RUSTFS_ACCESS_KEY` | Reuse the application credential for the existing RustFS bucket. |
| `MINIO_SECRET_KEY` | `RUSTFS_SECRET_KEY` | Reuse the matching secret. |
| `MINIO_BUCKET` | `RUSTFS_BUCKET` | Copy the exact existing bucket name. Do not rely on the default. |
| `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM` | same names | Copy values that are in use. |
| `FIREBASE_CONFIG_PATH` | same name | Preserve the service-account file mount and its container path. |
| `ACHIEVEMENT_MONA_GROUP_ID`, `ACHIEVEMENT_CREATED_BEFORE` | same names | Copy them. If they were absent, use the former Spring defaults shown below. |

The Go server accepts the old `MINIO_*` names as compatibility aliases, but the
canonical `RUSTFS_*` names make the deployed configuration unambiguous.

An application environment for RustFS on the Compose network can look like
this:

```dotenv
HOST_PORT=8080
PORT=8080
DATABASE_URL=postgres://postgres:URL_ENCODED_PASSWORD@db:5432/sticker?sslmode=disable

JWT_SECRET=<strong-random-secret>
TOKEN_ACCESS_EXPIRY=15m
TOKEN_REFRESH_EXPIRY=31556952s
TOKEN_ADMIN_USERNAME=admin
APP_MAX_LOGIN_ATTEMPTS=10

APP_URL=https://api.example.com
APP_REDIRECT_URL=https://example.com

RUSTFS_ENDPOINT=rustfs:9000
RUSTFS_EXTERNAL_ENDPOINT=storage.example.com:9000
RUSTFS_ACCESS_KEY=<existing-application-access-key>
RUSTFS_SECRET_KEY=<existing-application-secret-key>
RUSTFS_BUCKET=<existing-bucket-name>
RUSTFS_USE_SSL=false
RUSTFS_URL_EXPIRY=60m

ACHIEVEMENT_MONA_GROUP_ID=d9631336-5c32-4f64-83a7-7a4fcdae4dd6
ACHIEVEMENT_CREATED_BEFORE=2023-12-10T02:43:44.402768+00:00
```

`RUSTFS_ENDPOINT` is the address used by the Go container. The external
endpoint is written into presigned URLs returned to clients. Both values use
`host:port` without a URL scheme.

The current client has one `RUSTFS_USE_SSL` setting for both endpoints. If
clients use an HTTPS endpoint, the Go container must also use a TLS-enabled
route. A common configuration is:

```dotenv
RUSTFS_ENDPOINT=storage.example.com:443
RUSTFS_EXTERNAL_ENDPOINT=storage.example.com:443
RUSTFS_USE_SSL=true
```

Keep the old public port in `HOST_PORT` and set the Go process's `PORT` to
`8080`. Using one variable for both values breaks deployments whose public port
is not 8080.

## Database handoff

The Go server runs its embedded migrations before it opens the HTTP listener.
Do not let it connect to the production database until the handoff below is
complete. Without the handoff, it starts at migration 1 and tries to recreate
the Spring schema.

The commands below use the repository service names `stick-it-server` and `db`.
Substitute the names from the deployed Compose file when they differ.

### 1. Drain traffic, stop writes, and back up PostgreSQL

Put the public route into maintenance mode or remove the application instance
from its reverse proxy or load balancer. Confirm that new requests cannot reach
Spring. Keep traffic drained until all smoke tests pass.

```bash
docker compose stop stick-it-server

(
  set -euo pipefail
  umask 077
  mkdir -p backup
  MIGRATION_BACKUP_PATH="backup/pre-go-cutover-$(date -u +%Y%m%dT%H%M%SZ).dump"
  test ! -e "$MIGRATION_BACKUP_PATH"
  docker compose exec -T db sh -c \
    'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
    > "$MIGRATION_BACKUP_PATH"
  docker compose exec -T db pg_restore --list \
    < "$MIGRATION_BACKUP_PATH" > /dev/null
  echo "Verified database backup: $MIGRATION_BACKUP_PATH"
)
```

Keep the Spring container stopped until the Go cutover or rollback. Do not stop
RustFS. Copy the verified backup to storage outside this Compose host before
continuing.

### 2. Verify the Flyway state

```bash
docker compose exec -T db sh -c \
  'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<'SQL'
SELECT installed_rank, version, description, success
FROM flyway_schema_history
ORDER BY installed_rank DESC
LIMIT 5;

WITH expected(version) AS (
    VALUES
        ('1.0.0'), ('1.0.1'), ('1.0.2'), ('1.0.3'), ('1.0.4'),
        ('1.0.5'), ('1.0.6'), ('1.0.7'), ('1.0.8'), ('1.0.9'),
        ('1.0.10'), ('1.0.11'), ('1.0.12'), ('1.0.13'), ('1.0.14'),
        ('1.0.15'), ('1.0.16'), ('1.0.17'), ('1.0.18'), ('1.0.19'),
        ('1.0.20'), ('1.0.21')
)
SELECT expected.version AS missing_successful_version
FROM expected
LEFT JOIN flyway_schema_history AS history
    ON history.version = expected.version
   AND history.success
WHERE history.version IS NULL
ORDER BY expected.version;

SELECT version, description
FROM flyway_schema_history
WHERE NOT success;

SELECT to_regclass(current_schema() || '.schema_migrations')
    AS go_migration_table;
SQL
```

Proceed only when all of these conditions hold:

- The newest successful Flyway migration is version `1.0.21` with description
  `fix member primary key`.
- The missing-successful-version query returns no rows.
- The failed-migration query returns no rows.
- `go_migration_table` is null.

If `schema_migrations` already exists, inspect it:

```sql
TABLE schema_migrations;
```

Continue only if you understand which Go migration attempt created it. Do not
insert a second version row.

### 3. Seed the Go migration version

Run this once:

```bash
docker compose exec -T db sh -c \
  'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<'SQL'
BEGIN;

CREATE TABLE schema_migrations (
    version bigint NOT NULL PRIMARY KEY,
    dirty boolean NOT NULL
);

INSERT INTO schema_migrations (version, dirty)
VALUES (22, false);

COMMIT;
SQL
```

Verify the result:

```bash
docker compose exec db sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "TABLE schema_migrations;"'
```

The table must contain exactly one row with version `22` and `dirty` set to
`false`.

## RustFS checks

Do not create a new bucket and do not attach a new RustFS data volume. Configure
the Go server with the exact bucket and credentials used by Spring.

Before the cutover, verify that the application credential can inspect the
bucket and read a known object. It also needs permission to put and delete the
application's objects. The Go server checks whether the bucket exists during
startup. If that check fails, the server logs `rustfs ensure bucket` and starts
without object storage. Image operations then remain unavailable until the Go
container is restarted with working storage configuration.

The Go server creates the configured bucket when it is absent and the
credential permits bucket creation. That behavior is useful for development,
but it can hide a production typo by creating an empty bucket. Confirm the
bucket name and read an existing image after startup.

If RustFS is a Compose service, keep its existing service, volumes, image, and
health check. Update the application service's `depends_on` entry to the real
RustFS service name if needed. If RustFS runs outside this Compose project,
remove the stale object-store dependency instead. `depends_on` controls start
order unless it uses a health condition, so make sure RustFS is ready before
starting Go.

## Cut over the application

Change only the application image and environment. Preserve the database and
RustFS definitions from the deployed Compose file.

```yaml
services:
  stick-it-server:
    image: ghcr.io/lr101/stick-it-server-go:<tested-version>
    restart: unless-stopped
    ports:
      - "${HOST_PORT}:8080"
    env_file:
      - ./.env
    environment:
      PORT: "8080"
```

Pull and start only the application service:

```bash
docker compose pull stick-it-server
docker compose up -d --no-deps stick-it-server
docker compose logs --tail=200 stick-it-server
```

The service is now bound to the production host port, but the upstream route
must remain drained. The logs must contain `rustfs ready` for the expected
bucket and `server listening`. A migration error stops the process. An
object-store error does not, so check both messages.

## Smoke tests

Run these checks before reopening traffic:

1. `GET /api/v2/public/infos` returns `200`.
2. `POST /api/v2/public/login` works for an existing user.
3. An authenticated `GET /api/v2/groups` returns the user's groups.
4. An existing pin, group, or user image produces a usable presigned RustFS URL.
5. A test user can upload and retrieve a new image.
6. Password recovery and email confirmation work when mail is configured.
7. The status response reports the expected external object-store endpoint.

Run HTTP checks against the Compose host and `HOST_PORT` so they bypass the
drained public route. After every check passes, restore the reverse proxy or
load-balancer route and watch the application logs during the first live
requests.

Spring generated its JWT signing key when the process started. It did not read
a persistent signing secret from the deployment environment. Existing Spring
access tokens therefore do not validate in Go. Refresh tokens remain in
PostgreSQL and can be exchanged by compatible clients, but plan for users to log
in again if refresh fails. Keep the new Go `JWT_SECRET` stable after cutover.

## Rollback

If production traffic has already reopened, drain it again before rollback.

Before rolling back, inspect the Go migration version:

```bash
docker compose exec db sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "TABLE schema_migrations;"'
```

Rollback to Spring is schema-safe while the version is still `22`. If Go has
applied a later migration, review that SQL before starting Spring.

To roll back version 22:

1. Stop the Go application container.
2. Restore the previous Spring image and environment.
3. Start only the application service.
4. Leave `schema_migrations` in PostgreSQL. Flyway ignores it.
5. Expect clients to refresh or log in again because Spring creates a new JWT
   signing key when it starts.
6. Smoke-test Spring through the Compose host, then restore the public route.

RustFS needs no rollback action because the service, bucket, and key layout did
not change.
