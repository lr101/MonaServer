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
server, creates or reuses a disposable API user and group, and verifies the
login/group flow with Playwright.

From the repository root, start the development API first. The default API
target is `http://127.0.0.1:8080`:

```bash
mise install
mise run flutter-setup
mise run flutter-playwright-setup
E2E_API_URL=http://127.0.0.1:8080 mise run flutter-verify-web
```

`flutter-verify-web` also installs the JavaScript dependencies and Chromium, so
the explicit setup task is useful for the first run or for an interactive MCP
session. The generated test credentials and group name are stored in the
ignored `flutter/e2e/.auth/test-data.json`; set `E2E_TEST_USERNAME`,
`E2E_TEST_PASSWORD`, `E2E_TEST_GROUP`, or `E2E_TEST_EMAIL` to use a known
disposable account. `E2E_DATA_PATH` may point inside `flutter/e2e/.auth/` or to
an external path that you protect yourself; repository paths outside the
ignored auth directory are rejected. For a remote API with SMTP enabled,
provide an accepted disposable
`E2E_TEST_EMAIL`; the default `.invalid` address is intended for local/CI APIs
without mail. The seed helper refuses non-loopback APIs unless
`E2E_ALLOW_REMOTE_API=1` is set deliberately.

The Playwright MCP server is declared in the repository root `.mcp.json`. Once
the project MCP configuration is loaded, build and serve the web app for an
interactive browser session:

```bash
E2E_API_URL=http://127.0.0.1:8080 mise run flutter-build-web
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
