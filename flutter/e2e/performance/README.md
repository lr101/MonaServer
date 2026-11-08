# Reproducing UI stutter

This opt-in Chromium test exercises the real release Flutter app, API, Drift
cache, map, feed images and navigation retention. It repeatedly visits Groups →
Map → Profile → Feed and scrolls down/up on the feed. Ten measured cycles after
one warm-up cycle force page eviction/recreation, the area changed in #686.
Setup signs in, activates all joined groups, reloads once to warm the persisted
cache, and requires a real feed card before timing. This deliberately measures
warm navigation; first-login loading is a separate check.
It does not mock the app or change production code.

## Run

1. Start the disposable PostGIS, RustFS and Go API and seed the standard fixture
   following [the local stack guide](../../../docs/AGENT_LOCAL_STACK.md).
2. From the repository root:

   ```bash
   set -a
   source testdata/.env.test
   set +a
   E2E_API_URL=http://127.0.0.1:8081 mise run flutter-build-web
   cd flutter/e2e
   npm ci
   npm run install:browsers
   E2E_API_URL=http://127.0.0.1:8081 npm run test:performance
   ```

The existing global setup reads the fixture environment and writes the ignored
auth file. Do not point this at production. The runner serves `flutter/build/web`
locally using the existing static server; use the release build above, not a
hot-reload/debug build. The default viewport is 450×900, animations enabled,
Chromium headless, CPU throttled 4×. No retries, video or tracing are enabled,
to avoid hiding intermittent failures or distorting timings. Keep the browser
foreground if using `--headed`, and keep other host workloads quiet.

The test requires a nonempty feed before recording. It uses the seeded data
unchanged; keep that dataset, viewport, machine and Chromium version identical
when comparing commits. The small standard fixture is a baseline, not a
large-gallery stress dataset. For larger datasets, use a disposable local
account and preserve that dataset for both runs.

## Failure and evidence

Every measured phase must have more than ten samples and **zero frame gaps
above 100 ms**. The budget targets obvious pauses; it does not assert perfect
60 Hz rendering. A single isolated stall fails even if p95 looks healthy.

Each test output directory contains `ui-frame-gaps.json` (also attached to the
Playwright report as `frame-report.json`): raw intervals, sample
counts, duration, p95, maximum, intervals above 34 ms, and stalls above 100 ms,
labelled by cycle and destination. Workload version 2 uses fixed 1000 ms
recording windows for navigation and 2000 ms for Feed, starting before the tab
selection; scrolling starts no earlier than 500 ms. Windows outside ±100 ms
are rejected. A readiness-dependent end time would bias comparisons when a
candidate shows its destination sooner. View it with `npx playwright show-report`.
Compare the same workload on the parent and candidate commits; repeat whole
runs to investigate intermittent failures instead of enabling retries.

The measurements are browser `requestAnimationFrame` gaps, not Flutter
build/raster durations or proof that every canvas frame changed. GPU-only
stalls may escape detection. The test covers warm repeated navigation and
scrolling, not cold startup, forced incremental sync, camera capture or native
Android/iOS rendering. Network/map tile latency and host load can affect results;
use the per-phase artifact to locate a failing flow before profiling it.

## Check the detector without services or a Flutter build

```bash
cd flutter/e2e
npm ci
# If Chromium is not already installed:
npm run install:browsers
npm run test:performance-monitor
npm run test:performance-isolation
```

This checks summary boundaries, rejection of empty recordings and detection of
a deliberate 180 ms main-thread block in a real Chromium page. It validates the
detector independently of whether the application currently stutters.
The isolation test additionally requires nginx and verifies real HTTP headers
and browser worker isolation for each web-serving configuration.

## Score a 20% improvement

Before changing production code, preserve its release web bundle and record five
whole baseline runs using `npm run test:performance -- --repeat-each=5`. Use
separate `PLAYWRIGHT_OUTPUT_DIR` and `PLAYWRIGHT_REPORT_DIR` for each arm. After
building the candidate with the same API URL, collect five candidate runs on the
same fixture and host. Do not run builds or other tests during timed recordings.
Use fresh browser contexts (the runner default) for each whole run.

```bash
node performance/score-runs.mjs /path/to/baseline /path/to/candidate
node --test performance/score-runs.test.mjs
```

The primary metric is the actual mean frame interval, averaged with equal
weight across the 40 phases, then the median of five whole runs. PASS requires
at least 20% reduction and no increase in median worst gap or median count of
gaps above 100 ms. Excess delay above 16.67 ms is reported separately as a
diagnostic; improving excess delay alone does not satisfy the 20% target. The scorer rejects incomplete
or incompatible recordings and preserves all run values in its JSON result.
Artifacts include host/browser/fixture fingerprints and release bundle hash.

The score does not certify capabilities: separately review the production diff
and run behavioral checks for affected navigation, drafts, scroll restoration,
media and sync paths. Removing a feature to improve timing is FAILURE regardless
of the numerical result.

Flutter's threaded Wasm renderer requires cross-origin isolation. The web
servers provide `Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: credentialless`; test integrations involving
cross-origin popups, embedded content, tiles and media when changing them.

## Profile a failing flow

For readable Dart function names, make a separate diagnostic release build with
`--no-minify-wasm --no-strip-wasm` in addition to the normal Flutter build flags,
then regenerate the offline manifest. Run one cycle with:

```bash
E2E_PERF_TRACE=1 npm run test:performance
```

The test writes a private `ui-trace.json` in its output directory for Chrome's
Performance panel. Profiling changes timings: this mode records only one cycle
and marks its build as `diagnostic`, so the scorer rejects it. Do not use these
timings for the 20% comparison. Timeline URLs can contain signed image URLs;
keep the trace private. Rebuild the normal minified release before scoring again.
