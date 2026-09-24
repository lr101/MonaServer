# Local test data

This directory contains a disposable integration stack and a repeatable fixture
for testing the Flutter app against the Go API. The fixture is created through
the API, so group images, pin images, authentication, visibility, and RustFS
presigned URLs are exercised together.

For the complete native service setup, read
[`docs/AGENT_LOCAL_STACK.md`](../docs/AGENT_LOCAL_STACK.md). After the API
is running on `http://127.0.0.1:8081`, seed the fixture with:

```bash
export TESTDATA_PASSWORD="$(openssl rand -hex 12)"
TEST_API_URL=http://127.0.0.1:8081 mise run testdata-seed
set -a
source testdata/.env.test
set +a
```

The password is written only to the ignored `testdata/.env.test` file.

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
node static_server.mjs
```

Use the Playwright MCP server against `http://localhost:4173/` and log in as
`stickitviewer`. The scenario names above make it possible to inspect joined
content, public content from an unjoined group, private-group authorization,
and empty states. Add a focused Playwright regression test under
`flutter/e2e/tests/` when a UI bug should be checked repeatedly.

The test stack is disposable and uses local-only credentials. Never point the
seeder at production or a shared environment.
