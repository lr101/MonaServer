# Agent local stack

This is the canonical runbook for starting Stick-It locally for an agent. It
covers the Go API, PostGIS, RustFS, the Flutter web build, the Playwright
browser, and the reusable fixture data.

Use the disposable Compose profile when Docker or Podman is available. The
current agent environment has native PostgreSQL/PostGIS but no container
runtime, so the native profile below is the path to use there. Both profiles
use loopback-only listeners and the same API and fixture commands.

| Service | Compose profile | Native profile |
|---|---|---|
| Go API | `http://127.0.0.1:8081` | `http://127.0.0.1:8081` |
| PostGIS | `127.0.0.1:5434` | `127.0.0.1:5432` |
| RustFS S3 API | `http://127.0.0.1:9100` | `http://127.0.0.1:9100` |
| RustFS console | `http://127.0.0.1:9101` | `http://127.0.0.1:9101` |
| Flutter web | `http://127.0.0.1:4173` | `http://127.0.0.1:4173` |

The database and RustFS are test dependencies, not mise tools. Firebase,
SMTP, and other production integrations are optional; leave them unset unless
the change specifically needs one of them.

## Prepare the toolchain

Run this from the repository root. Do not install Go, Flutter, or Node with
apt; their versions are pinned in `mise.toml`.

```bash
mise install
mise exec -- go version
mise exec -- flutter --version
mise exec -- node --version
mise run flutter-setup
mise run flutter-playwright-setup
```

The native profile additionally needs `curl`, `openssl`, `psql`, and Python's
standard-library HTTP server. On a Debian-based agent container, install only
the missing OS packages:

```bash
apt-get update
apt-get install -y curl openssl postgresql postgresql-contrib postgis postgresql-15-postgis-3 unzip
```

If the PostgreSQL cluster is not version 15, replace
`postgresql-15-postgis-3` and the `pg_ctlcluster` version below with the
installed cluster version.

## Create local credentials

The Compose and native profiles both read the ignored root `.env.test` file.
Create it once and replace every placeholder with a local-only value. Keep the
database password URL-safe because it is embedded in `DATABASE_URL`.

```bash
test -f .env.test || cp .env.test.example .env.test
chmod 600 .env.test
${EDITOR:-vi} .env.test

set -a
source .env.test
set +a
```

Do not use `set -x` while these variables are loaded. `TESTDATA_PASSWORD` is
separate from the service credentials and should only exist in the shell that
runs the fixture seeder. It must be 2–29 characters and use characters accepted
by Flutter's login validator; `openssl rand -hex 12` produces a valid
24-character value.

## Profile A: disposable Compose stack

Choose this profile when `docker compose version` or an equivalent Podman
Compose command works:

```bash
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

`--wait` waits for the PostGIS, RustFS, and Go health checks. The final loop
also proves that the API is reachable from the host, which is the address the
Flutter web app and Playwright use. Substitute `podman compose` for
`docker compose` when Podman is the available runtime.

For fast Go iteration while keeping only the database and object store in
containers:

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

Run the Go process in a persistent terminal. It applies migrations and creates
the configured RustFS bucket before serving requests.

## Profile B: native services without Docker

This is the profile for the current agent container. Keep PostgreSQL running,
start RustFS in a second persistent terminal, and run the Go API in a third.

### Start disposable PostGIS

The commands below create the role and database only when they do not already
exist. Use a dedicated test role and database in `.env.test`; never point the
integration suite at a development or shared database.

```bash
if ! pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
  pg_ctlcluster 15 main start
fi
pg_isready -h 127.0.0.1 -p 5432

runuser -u postgres -- psql -v ON_ERROR_STOP=1 \
  -v test_db_user="$TEST_DB_USER" \
  -v test_db_password="$TEST_DB_PASSWORD" \
  -v test_db_name="$TEST_DB_NAME" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'test_db_user', :'test_db_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'test_db_user') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'test_db_name', :'test_db_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'test_db_name') \gexec
SQL

runuser -u postgres -- psql -d "$TEST_DB_NAME" -v ON_ERROR_STOP=1 \
  -c 'CREATE EXTENSION IF NOT EXISTS postgis;'
PGPASSWORD="$TEST_DB_PASSWORD" psql -h 127.0.0.1 -p 5432 \
  -U "$TEST_DB_USER" -d "$TEST_DB_NAME" -Atc 'SELECT PostGIS_Version();'
```

If the role or database already exists, the password in `.env.test` must match
the existing local role. The extension is created as the PostgreSQL operating
system user because an ordinary test role may not be allowed to install
extensions.

### Start RustFS

RustFS is required for image uploads, presigned URLs, and the complete pin/group
flow. Keep the listener on loopback. The official Linux installer creates a
systemd service; this container has no systemd, so use the foreground binary
mode here.

If `rustfs` is already installed, open a second terminal and run:

```bash
mkdir -p /tmp/monaserver-rustfs-data
set -a
source .env.test
set +a
export RUSTFS_ACCESS_KEY="$TEST_RUSTFS_ACCESS_KEY"
export RUSTFS_SECRET_KEY="$TEST_RUSTFS_SECRET_KEY"
export RUSTFS_ADDRESS='127.0.0.1:9100'
export RUSTFS_CONSOLE_ADDRESS='127.0.0.1:9101'
export RUSTFS_CONSOLE_ENABLE='true'
rustfs server /tmp/monaserver-rustfs-data
```

Leave that terminal running. Press `Ctrl+C` when the test session is finished.

If the binary is not installed and systemd is available, use the [RustFS Linux
quick start](https://docs.rustfs.com/en/installation/linux/quick-start), then
set `RUSTFS_ACCESS_KEY`, `RUSTFS_SECRET_KEY`, `RUSTFS_ADDRESS`, and
`RUSTFS_CONSOLE_ADDRESS` in `/etc/default/rustfs` and restart the service.

For a container without systemd, download the current x86_64 Linux release
from the [official RustFS releases](https://github.com/rustfs/rustfs/releases),
verify its published checksum, unzip the `rustfs` binary, and use the same
foreground command above. The following pinned example was checked in the
current x86_64 agent environment; update the version, asset, and checksum
together when upgrading:

```bash
rustfs_download_dir="$(mktemp -d)"
rustfs_version='1.0.0-beta.12'
rustfs_asset="rustfs-linux-x86_64-musl-v${rustfs_version}.zip"
curl --fail --location \
  "https://github.com/rustfs/rustfs/releases/download/${rustfs_version}/${rustfs_asset}" \
  --output "${rustfs_download_dir}/${rustfs_asset}"
printf '%s  %s\n' \
  '683bef16247ab04bedb76d0444736f286d21943375d2d57d2ded9ec277498427' \
  "${rustfs_download_dir}/${rustfs_asset}" | sha256sum --check --status
unzip -q "${rustfs_download_dir}/${rustfs_asset}" -d "$rustfs_download_dir"
chmod 0755 "${rustfs_download_dir}/rustfs"
```

Use `"${rustfs_download_dir}/rustfs" server /tmp/monaserver-rustfs-data` in
the foreground command when the binary is not installed globally. The RustFS
[CLI reference](https://docs.rustfs.com/en/reference/cli) documents the
`server`, address, console, and volume options.

Verify the object store before starting the API:

```bash
curl --fail --silent http://127.0.0.1:9100/health >/dev/null
```

### Start the Go API

Open a third terminal from the repository root. The native database uses port
5432; RustFS uses the same host ports as the Compose fixture.

```bash
cd go-server
set -a
source ../.env.test
set +a
DATABASE_URL="postgres://${TEST_DB_USER}:${TEST_DB_PASSWORD}@127.0.0.1:5432/${TEST_DB_NAME}?sslmode=disable" \
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

Wait for the server to finish migrations, then verify it from another
terminal:

```bash
for attempt in $(seq 1 60); do
  if curl --fail --silent http://127.0.0.1:8081/public/api-docs >/dev/null; then
    break
  fi
  if [ "$attempt" -eq 60 ]; then
    echo 'Go API did not become ready' >&2
    exit 1
  fi
  sleep 1
done
```

If RustFS cannot be installed, the Go server can be started with the RustFS
assignments omitted. Authentication, groups, and database-backed tests still
work, but image and presigned-URL behavior is not a full-stack result and must
be reported as unverified.

## Seed and use the reusable scenarios

Run the seeder once the API is ready. Keep the generated password in the
current shell if the fixture will be reseeded; the command never prints it and
writes only ignored files under `testdata/`.

```bash
export TESTDATA_PASSWORD="$(openssl rand -hex 12)"
TEST_API_URL='http://127.0.0.1:8081' mise run testdata-seed

set -a
source testdata/.env.test
set +a
```

The fixture contains a joined public group, public pins in a group the viewer
has not joined, a private group hidden from that viewer, and an empty public
group. Read [`testdata/README.md`](../testdata/README.md) and
[`testdata/scenarios.json`](../testdata/scenarios.json) before choosing a
scenario for a regression. `mise run testdata-test` validates the fixture
references without contacting the API.

To exercise the Go API without a browser, use the generated API documentation
for endpoint discovery and the seeded accounts described in the fixture guide.
Do not paste access or refresh tokens into logs. The seeder intentionally keeps
only user and resource IDs in `testdata/.seed-state.json`.

## Build and verify Flutter Web

The API URL is compiled into Flutter Web, so rebuild after changing
`E2E_API_URL`:

```bash
E2E_API_URL='http://127.0.0.1:8081' mise run flutter-verify-web
```

This builds the Wasm web app, starts a local static server when needed, and runs
the Playwright login/group smoke test against the seeded API. It is the normal
agent check for startup, routing, authentication, group visibility, and other
web UI changes.

For interactive inspection through the configured Playwright MCP server:

```bash
E2E_API_URL='http://127.0.0.1:8081' mise run flutter-build-web
python3 -m http.server 4173 --bind 127.0.0.1 --directory flutter/build/web
```

The repository `.mcp.json` starts Chromium with only `localhost` and loopback
hosts allowed. Use the `playwright` MCP server at `http://localhost:4173/`.
Enable Flutter's accessibility semantics in the page before looking for form
fields or buttons. This browser setup validates Flutter Web; it is not an
Android emulator.

## Go checks and full-stack boundaries

Run the plain suite for fast feedback:

```bash
mise run test
mise exec -- go vet ./...
```

For database-backed Go tests, stop the running API or use a separate disposable
database. The tests run migrations and truncate shared tables, so never run
them against the seeded database while the API is serving traffic:

```bash
cd go-server
TEST_DATABASE_URL="postgres://${TEST_DB_USER}:${TEST_DB_PASSWORD}@127.0.0.1:5432/${TEST_DB_NAME}?sslmode=disable" \
mise exec -- go test -count=1 -p 1 ./...
```

For a change that affects both the server and UI, the evidence should include
the relevant Go test or API smoke check plus `mise run flutter-verify-web`. A
green Flutter build alone does not prove database migrations, authorization,
object storage, or API behavior.

## Stop and reset

Stop foreground Go, RustFS, and static-server terminals with `Ctrl+C`. For the
Compose profile, remove only the named disposable volumes when a clean run is
needed:

```bash
docker compose --env-file .env.test -f docker-compose.test.yml down -v
```

For the native profile, stop the RustFS systemd service if that mode was used.
Only drop the exact disposable database named by `TEST_DB_NAME`, after
confirming it is not shared:

```bash
runuser -u postgres -- dropdb --if-exists "$TEST_DB_NAME"
```

The native RustFS data under `/tmp/monaserver-rustfs-data` is disposable. Do
not remove any other PostgreSQL database, RustFS data directory, or service.
