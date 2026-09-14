# Flutter startup slice verification — 2026-09-11

Implemented the first composition-root increment: separate configuration,
bootstrap, platform initialization/provider wiring, and app rendering; validate
API origins before initialization; show a safe startup error; enforce initial
import boundaries. Shared session state, platform ports and application lifecycle
ownership remain next work in [the architecture plan](../../flutter/ARCHITECTURE.md).

## Checks

- Flutter 3.47.3 / Dart 3.13.3, from the pinned mise toolchain.
- Focused startup and architecture tests: 30 passed. Tests were observed failing
  before implementation, including the URL and import-guard review fixes.
- `mise run flutter-test`: 186 passed.
- `mise run flutter-analyze`: completed with 41 existing informational findings;
  none in the new app modules, entry point or new tests. No dependency versions
  changed; the existing analyzer package became a direct development dependency.
- Release web compilation: passed with `API_HOST=http://127.0.0.1:8081`.
- `mise exec -- bash flutter/docker/test_web_build.sh flutter/build/web`: passed;
  both Wasm/SkWasm and JavaScript/CanvasKit artifacts are present.
- Independent code review: both findings fixed and rechecked.
- `git diff --check`: passed.

## Browser and services

Used the existing native PostgreSQL/PostGIS, Go API on port 8081 and RustFS on
port 9100. Created a fresh disposable copy of the reusable fixture with unique
names: three users, four groups, five pins and two likes. Credentials and fixture
files remain ignored.

The default port 4173 server belonged to another worktree, so its initial smoke
results were discarded. This checkout was served separately on IPv6 loopback
port 4173. A local Playwright configuration pinned `localhost` to `::1`; a browser
probe confirmed that address and matched the served Wasm bytes to this build.
Chromium 153.0.8010.12 selected the Wasm/SkWasm build.

The isolated run passed login/logout (including reload after logout), joined
groups and web camera access. Public-group search loaded all pin images but
failed the console-error check on two missing fixture profile pictures. After
adding profile pictures to the disposable users, that scenario passed on its
focused rerun. All four browser scenarios therefore passed across these runs.

JavaScript fallback was checked as a build artifact, not exercised in a browser.
The logout/reload flow verifies session cleanup; durable offline uploads and
long-term storage persistence were not tested. No Android device, native camera,
Firebase initialization or iOS verification was performed. The owned test web
server was stopped after verification; pre-existing backend services were left
running.
