# Local test data

This directory contains a disposable integration stack and a repeatable fixture
for testing the Flutter app against the Go API. The fixture is created through
the API, so group images, pin images, authentication, visibility, and RustFS
presigned URLs are exercised together.

## Start the test stack

From the repository root, start the isolated PostGIS database, RustFS object
store, and Go server:

```bash
test -f .env.test || cp .env.test.example .env.test
# Replace the placeholder values in .env.test with local-only values.
docker compose --env-file .env.test -f docker-compose.test.yml up --build -d --wait
for attempt in $(seq 1 60); do
  if curl --fail --silent http://127.0.0.1:8081/public/api-docs >/dev/null; then
    break
  fi
  if [ "$attempt" -eq 60 ]; then
    docker compose --env-file .env.test -f docker-compose.test.yml logs go-server
    exit 1
  fi
  sleep 1
done
```

The `--wait` flag waits for the PostGIS, RustFS, and Go API health checks. The
short loop also confirms that the API is reachable from the host before the
fixture seeder runs.

The services use these host ports:

| Service | Address |
|---|---|
| Go API | `http://127.0.0.1:8081` |
| PostGIS | `127.0.0.1:5434` |
| RustFS S3 API | `http://127.0.0.1:9100` |
| RustFS console | `http://127.0.0.1:9101` |

The Go server runs database migrations on startup and creates the `monaserver`
bucket in RustFS. Seed the fixture with a local-only password; it is written
only to the ignored `testdata/.env.test` file and is never printed:

```bash
TESTDATA_PASSWORD='replace-with-a-local-only-password' mise run testdata-seed
set -a
source testdata/.env.test
set +a
```

The seed command is idempotent when the same password is reused. To start from
an empty database and object store, remove the disposable volumes explicitly:

```bash
docker compose --env-file .env.test -f docker-compose.test.yml down -v
```

The API can also be run from the host for faster Go iteration while retaining
the containerized database and RustFS:

```bash
docker compose --env-file .env.test -f docker-compose.test.yml up -d --wait db rustfs
cd go-server
set -a
source ../.env.test
set +a
DATABASE_URL="postgres://${TEST_DB_USER}:${TEST_DB_PASSWORD}@127.0.0.1:5434/${TEST_DB_NAME}?sslmode=disable" \
JWT_SECRET="$TEST_JWT_SECRET" \
TOKEN_ADMIN_USERNAME='__test_admin_disabled__' \
RUSTFS_ENDPOINT='127.0.0.1:9100' \
RUSTFS_EXTERNAL_ENDPOINT='127.0.0.1:9100' \
RUSTFS_ACCESS_KEY="$TEST_RUSTFS_ACCESS_KEY" \
RUSTFS_SECRET_KEY="$TEST_RUSTFS_SECRET_KEY" \
RUSTFS_BUCKET='monaserver' \
PORT=8081 \
mise exec -- go run ./cmd/server
```

In that mode, run the seeder with `TEST_API_URL=http://127.0.0.1:8081`.

## Fixture scenarios

All three accounts use the password supplied as `TESTDATA_PASSWORD`:

| Account | Purpose |
|---|---|
| `stickitviewer` | Default app login; member of the public member group, but not of the unjoined groups |
| `stickitowner` | Owns every fixture group and creates the fixture pins |
| `stickitmember` | Member of the public member group and both the public and private unjoined groups |

The stable group names and scenarios are:

| Group | Visibility | Viewer membership | Data |
|---|---:|---:|---|
| `Stick-It Fixture - Public Member Group` | public | yes | Two pins, created by the viewer and another member |
| `Stick-It Fixture - Public Unjoined Pins` | public | no | Two pins visible to the viewer despite no membership; one has a viewer like |
| `Stick-It Fixture - Private Unjoined Group` | private | no | One pin that must not be visible to the viewer |
| `Stick-It Fixture - Empty Public Group` | public | no | No pins, for empty-state and join-flow checks |

The full declarative fixture is in [`scenarios.json`](scenarios.json). The
generated `testdata/.seed-state.json` maps scenario keys to database IDs for
API-level checks. Run `mise run testdata-test` to validate the fixture
references before seeding it.

## Use the fixture with Flutter Web

After sourcing `testdata/.env.test`, run the existing local browser smoke test:

```bash
mise run flutter-verify-web
```

For interactive inspection through Playwright MCP, build and serve the web app:

```bash
mise run flutter-build-web
cd flutter/e2e
npm ci
npm run install:browsers
python3 -m http.server 4173 --bind 127.0.0.1 --directory ../build/web
```

Use the Playwright MCP server against `http://localhost:4173/` and log in as
`stickitviewer`. The scenario names above make it possible to inspect joined
content, public content from an unjoined group, private-group authorization,
and empty states. Add a focused Playwright regression test under
`flutter/e2e/tests/` when a UI bug should be checked repeatedly.

The test stack is disposable and uses local-only credentials. Never point the
seeder at production or a shared environment.
