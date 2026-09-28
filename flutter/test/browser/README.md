# Local browser image regression test

This test uses the real Dart API client, `ImageRepository`, browser Drift database,
and Flutter image decoder. Two temporary HTTP servers on `127.0.0.1` provide image
URL responses and a cross-origin PNG download. It does not need a user account,
PostGIS, RustFS, or production configuration.

The runner tests all six image types in both Wasm and JavaScript builds:

- Empty browser cache, then a reload that must reuse persisted bytes.
- A version 1 image table containing cached PNGs, upgraded by the real migration.
- Expired, retained empty entries that must recover when downloads succeed.

The final case reproduces a defect introduced in the image-cache rewrite (#454):
`fetchImage(id, false)` downloaded bytes for an existing `keepAlive=true` entry,
but the write guard discarded them. The returned future contained the new bytes
while database watchers continued displaying an empty or stale image. Refreshes
now preserve the retention setting when replacing the cached bytes they originally
read. If another retained write changes the bytes or expiry during the download,
the older response is discarded.
This demonstrates a cache failure mechanism; it does not establish the state of
any deployed browser cache.

## Run

From `flutter/`, with the repository's pinned Flutter SDK and Node 20+ available:

```bash
mise exec -- flutter pub get
npm ci --prefix test/browser
# Install the browser if no suitable Chromium is already available.
npm exec --prefix test/browser -- playwright-core install chromium
mise exec -- flutter build web --wasm --release --no-pub \
  --no-web-resources-cdn --target test/browser/image_probe.dart \
  --output build/image-probe
node test/browser/image_probe.mjs
```

For an existing browser, skip its installation and set `CHROME_EXECUTABLE` to
its executable path when running the Node script. The runner accepts an optional
first argument for an alternative compiled test directory.

Dependency and browser installation may download packages. The **test run** only
allows the two temporary local origins, aborts all other page requests, disables
service workers and proxies, and disables external hostname resolution in
Chromium. Any unexpected external page request makes the test fail. It serves a
minimal local HTML page, avoiding the app page's third-party scripts, and does
not load `config` or `config.dev`. It uses a fresh browser context per case and
closes both servers afterward.

The normal Flutter test suite also covers retained empty/stale refreshes in
`test/image_repository_test.dart`, including publication through image watchers
and preservation of the existing protection against late public responses.

## Camera preview regression

The camera test uses the real camera_web plugin, browser video and image capture,
with local provider overrides (no API, database or object storage). Run it in
Chromium with a simulated camera:

```bash
# Use an executable wrapper as CHROME_EXECUTABLE:
# exec /path/to/chrome --no-sandbox --use-fake-device-for-media-stream \
#   --use-fake-ui-for-media-stream "$@"
CHROME_EXECUTABLE=/path/to/chrome-wrapper mise exec -- flutter test --no-pub \
  --platform chrome test/browser/camera_preview_test.dart \
  test/camera_permissions_test.dart test/camera_values_test.dart \
  test/map_camera_lifecycle_test.dart
```

The permission tests inject denied/pending discovery results; the simulated
camera test checks actual preview initialization, exactly two media requests (permission and selected camera), and nonempty captured bytes. The Playwright camera tests also cover the group shutter, approval screen, return to preview and denial/retry.
These checks do not establish physical lens selection or Safari/Firefox mobile
behavior. Web and native previews use a centered 3:4 frame with a cover crop,
matching the normalized image sent for review. The group carousel is width
bounded so group choices and its centered shutter stay close together on
tablets and wide browser windows. Camera selection is shared; flash is disabled
on web.


The web discovery adapter is isolated in
`lib/features/camera/platform/camera_access_web.dart`. It bridges camera_web's
test-visible metadata map because the plugin currently opens every lens during
enumeration. The exact existing camera_web version is pinned; recheck this
bridge and browser regressions when upgrading it. Lens labels for devices other
than the initially opened camera are best-effort; video orientation/mirroring
remains the browser plugin's responsibility.

Relevant upstream reports:
- [Firefox Android camera startup](https://github.com/flutter/flutter/issues/115892)
  and the [upstream constraints fix](https://chromium.googlesource.com/external/github.com/flutter/packages/+/refs/tags/camera_web-v0.3.5%2B2).
- [WebKit preview crop/zoom after rotation](https://bugs.webkit.org/show_bug.cgi?id=220326).
