# Flutter guidance

## Rebuild-sensitive providers

Providers that feed map markers, images, or other media need stable rebuild
behavior. An unintended provider rebuild can cause an expensive decode or make
the widget briefly show a placeholder. On map screens, that can look like a
marker flickering.

- Subscribe to the stable data stream before starting cache or network work.
  Do not make an async refresh the provider's stream initialization gate.
- Use `select` and stable provider parameters so unrelated state changes do not
  recreate media providers.
- If a database update changes only metadata, preserve the identity of cached
  image bytes. A new `Uint8List` with the same pixels is a new `ImageProvider`
  to Flutter, and an equal byte event should not reach dependent providers.
- Use `gaplessPlayback: true` when an image replacement must not blank the
  previous frame. This is a visual safeguard, not a substitute for preventing
  unnecessary rebuilds and decodes.
- Add a regression test when changing a provider that supplies media. Cover
  both the order of subscription and refresh, and the behavior of metadata-only
  updates.

## Web verification for agents

Use the Chromium check when a change affects Flutter startup, routing,
authentication, group screens, web-only behavior, or another UI path that is
not covered by widget tests. It builds the Wasm web app, starts a local static
server, and verifies the login/group flow with Playwright. GitHub Actions keeps
the web build and artifact checks lightweight; it does not start this test
stack or run the browser E2E suite.

### Start the disposable API stack

For functionality checks that need realistic server data, start the isolated
PostGIS, RustFS, and Go server stack from the repository root:

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
TESTDATA_PASSWORD='replace-with-a-local-only-password' mise run testdata-seed
set -a
source testdata/.env.test
set +a
```

This exposes the test API on `http://127.0.0.1:8081`, PostGIS on port `5434`,
and RustFS on ports `9100` (S3) and `9101` (console). The reusable scenarios
are documented in [`testdata/README.md`](../testdata/README.md) and declared
in [`testdata/scenarios.json`](../testdata/scenarios.json). They include a
joined public group, a public group whose pins are visible to a non-member, a
private group hidden from that user, and an empty group. The seeder writes
credentials and resolved IDs only to ignored files under `testdata/`.

If the Go server is being iterated on directly, start only `db` and `rustfs`
from `docker-compose.test.yml` and run `go run ./cmd/server` with the host
environment shown in the test-data guide.

From the repository root, run the browser check against the seeded test API at
`http://127.0.0.1:8081`:

```bash
mise install
mise run flutter-setup
mise run flutter-playwright-setup
E2E_API_URL=http://127.0.0.1:8081 mise run flutter-verify-web
```

`flutter-verify-web` also installs the JavaScript dependencies and Chromium, so
the explicit setup task is useful for the first run or for an interactive MCP
session. The smoke test reads the sourced fixture credentials. If no fixture is
sourced, its fallback setup can still create a disposable user and group; the
generated credentials are stored in the ignored
`flutter/e2e/.auth/test-data.json`. `E2E_DATA_PATH` may point inside
`flutter/e2e/.auth/` or to an external path that you protect yourself;
repository paths outside the ignored auth directory are rejected. The seed
helper refuses non-loopback APIs unless `TESTDATA_ALLOW_REMOTE_API=1` is set
deliberately. The Playwright fallback setup has its separate
`E2E_ALLOW_REMOTE_API=1` opt-in.

The Playwright MCP server is declared in the repository root `.mcp.json`. Once
the project MCP configuration is loaded, build and serve the web app for an
interactive browser session:

```bash
E2E_API_URL=http://127.0.0.1:8081 mise run flutter-build-web
cd flutter/e2e
npm ci
npm run install:browsers
python3 -m http.server 4173 --bind 127.0.0.1 --directory ../build/web
```

Then use the `playwright` MCP server at `http://localhost:4173/`. Flutter web
starts with its accessibility semantics disabled; press the `Enable
accessibility` control before inspecting or interacting with fields and
buttons. Run the one-shot verifier once beforehand if the test API user/group
does not exist yet. The MCP setup is for web validation and does not emulate an
Android device or camera.
