---
name: flutter-web-verification
description: Verify MonaServer Flutter Web changes using a connected hot-reload debug session, local login, Playwright, and screenshots. Use for rendered UI or browser-flow validation; it does not replace release or Android device checks.
---

# Flutter Web verification

Read `flutter/AGENTS.md` and `docs/AGENT_LOCAL_STACK.md`. For visual judgments also use the Flutter visual-review guidance and `flutter/DESIGN_LANGUAGE.md`. Follow the user's requested routes and states; a screenshot is evidence for its captured state, not proof of interaction, contrast, or Android system behavior.

## Local services and debug session

Use a disposable local API/database/storage stack as described in the runbook. Check PostgreSQL, `http://127.0.0.1:8081/public/api-docs`, and, for images, `http://127.0.0.1:9100/health` before each run. Identify an existing listener before starting one; never start a second RustFS on the same port. Foreground processes can terminate between turns: recheck health and restart your own services as needed. If storage is unavailable, report image checks as unverified. The RustFS CORS origin must match the browser URL and port.

Install the pinned dependencies with `mise run flutter-setup` and `mise run flutter-playwright-setup` when missing. In a persistent interactive terminal at `flutter/`, start:

```bash
E2E_API_URL=http://127.0.0.1:8081 ./e2e/debug_web.sh
```

The script starts a Flutter Chrome **debug** device on loopback port 4173 using pinned Playwright Chromium. It prints a private debug-session state directory and requires the terminal to stay open. After a separate Playwright browser run, reconnect Flutter’s own tab with `mise exec -- node debug_reconnect.mjs <state-directory>` from `flutter/e2e`; wait for startup to settle, then use `r` in the Flutter terminal and verify `Reloaded application`. Use `R` for initialization changes. A `No client connected` message is not proof of hot reload; reconnect and retry. Playwright captures use a separate browser, so open a fresh page after changes. For a different `FLUTTER_DEBUG_PORT`, add its exact loopback origin to RustFS CORS **before** starting storage. Never kill a listener owned by another session.

## Login and screenshots

From `flutter/e2e`, use a fresh private directory for each run. Use a previously provisioned disposable, activated test account. Source `testdata/.env.test` if available, or copy the existing ignored `flutter/e2e/.auth/test-data.json` into the private run directory as shown. The global setup refuses remote API seeding by default. First-time signup requires configured email delivery and account activation; the no-email local API cannot create the fallback fixture. For a single post-login capture:

```bash
umask 077
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/monaserver-web-check.XXXXXXXX")"
# Omit this copy only when a provisioned fixture is sourced as environment.
cp .auth/test-data.json "$run_dir/test-data.json"
PLAYWRIGHT_BASE_URL=http://127.0.0.1:4173 \
E2E_API_URL=http://127.0.0.1:8081 \
E2E_DATA_PATH="$run_dir/test-data.json" \
PLAYWRIGHT_OUTPUT_DIR="$run_dir/artifacts" \
PLAYWRIGHT_REPORT_DIR="$run_dir/report" \
E2E_SCREENSHOT_DIR="$run_dir/screenshots" \
E2E_VISUAL_CAPTURE=1 E2E_VISUAL_DESTINATION=Map \
mise exec -- npx playwright test tests/debug-visual.spec.ts
```

Destinations: `Groups`, `Camera`, `Map`, `Feed`, `Profile`. Set `E2E_VIEWPORT_WIDTH`, `E2E_VIEWPORT_HEIGHT`, and `E2E_COLOR_SCHEME=light|dark` for relevant states. The test enables Flutter semantics, signs in through the actual form, checks browser errors, and prints the screenshot path. Inspect the image; extend or write a focused Playwright test for a specific flow or transient state rather than inferring behavior from the screenshot. Run tests serially against shared fixtures, and use separate private data and artifact directories for separate invocations; simultaneous runs can conflict over both fixture state and output files. Screenshots, traces, and videos may contain personal data or signed URLs; do not print secrets or publish artifacts without authorization.

For Android-facing browser verification, use the same private data/artifact
environment with `E2E_ANDROID_WEB=1` and run `tests/android-web.spec.ts` instead.
This uses a Pixel browser profile, touch input, synthetic camera and browser
geolocation. It tests navigation, rotation, theme/back behavior, draft retention,
and a real API upload, deleting the temporary pin afterward. Mobile Flutter
semantics must be enabled by tapping the placeholder; desktop Enter-key
activation does not work under this mobile profile. These tests verify shared
Web behavior and do not establish native Android or TalkBack operation.

For the usual release/offline check run `E2E_API_URL=http://127.0.0.1:8081 mise run flutter-verify-web` separately. Debug web does not test offline caching. Chromium is not Android: do not mark TalkBack, system insets, real camera, predictive back, or Android lifecycle checks as passed from Web evidence. Report the services used, actual commands/results, screenshots and any skipped or failing checks. Keep the user's requested live session open when useful; otherwise stop only processes you started.
