# Build speed and cache verification

## Local development

Use the pinned tools in `mise.toml`. For Go, start the database and object store
once using [AGENT_LOCAL_STACK.md](AGENT_LOCAL_STACK.md), then run `mise run run`
with the local runtime environment. `mise run build` reuses Go's compiler and
module caches. Do not routinely clear them.

For Flutter, use `mise run flutter-run -- -d chrome` or a connected device ID
and hot reload. The Flutter tasks depend on manifest-aware `flutter-setup`;
unchanged setup is skipped, and deleting either package config reruns setup.
After changing SDK installations outside mise, force setup with
`mise run --force flutter-setup`. Keep `.dart_tool`, `build`, Pub, and Gradle
caches. Release Wasm builds retain the JavaScript fallback for browser support.

## GitHub Actions

Flutter and Go validation run on relevant pull requests and manual dispatches.
Flutter publishing and Go publishing run on relevant pushes to `main` and
`develop`. Feature branches are validated through their PR, avoiding duplicate
push and PR jobs. Superseded PR validation is cancelled. Publishing and channel
promotion are not cancelled.

Flutter analysis/tests, Android, web, and iOS run independently. Web publishing
waits for its analysis/tests and container validation, independent of mobile builds. Flutter SDK
and Pub caches are enabled on every Flutter job; Android also uses setup-gradle
and Gradle's task-output cache. Codemagic restores Pub and Gradle caches too.
Caches reduce repeat downloads/compilation; they do not replace dependency
resolution or tests. Do not cache signing credentials or whole workspaces.

The web job builds Wasm and JavaScript once and uploads the output. The container
job packages it with `flutter/docker/Dockerfile.runtime` and smoke-tests Nginx,
assets, MIME types, and missing-file responses. On publishing branches it saves
that tested image as a short-lived artifact. Publishing loads and pushes that
same image, then the existing promotion job updates the channel tag. The
standalone `flutter/docker/Dockerfile` still builds from source locally.

The Dart regeneration check runs when API sources, the generated client, or its
workflow change (and on manual dispatch). It uses checksum-verified OpenAPI
Generator 7.9.0, matching `flutter/api/.openapi-generator/VERSION`.

Go host tests use setup-go's cache, keyed by dependencies and the validation
workflow so the old publish-only job's empty cache cannot remain an exact hit.
Docker has a separate compiled-package cache at `/root/.cache/go-build`; the composite cache action injects/extracts it because
BuildKit's `gha` layer exporter does not export cache mounts. Cache keys include
OS, architecture, build inputs, and commit, with restore prefixes for reuse
across edits. Exact cache hits skip extraction because Actions cache entries
are immutable. Module downloads remain in a cached Docker layer. Both Linux
architectures compile on the native build platform with CGO disabled.

Docker layer cache scopes are `go-server` and `flutter-web-runtime`. GitHub's
branch cache access rules still apply: PR caches are not automatically available
to publishing branches. Separate jobs may also incur artifact transfer and
cache restore time, so assess total runner minutes as well as feedback time.

## Measure changes

Record a first build, an unchanged repeat, and a small source-edit rebuild using
the same machine, toolchain, flags, and dependencies. A first build with existing
caches is not a cold build. Use an isolated cache directory if measuring a cold
Go build; avoid deleting the developer's normal cache.

For example, from the repository root in Bash:

```bash
time mise run build
time mise run build
time mise run flutter-build-web
time mise run flutter-build-web
```

In Actions, compare SDK setup, dependency installation, compiler, artifact
transfer, and cache save/restore durations. Run the PR workflow again to inspect
warm cache behavior. Buildx's summary reports layer cache reuse; its separate
compiler cache restore/export steps report whether the mount was restored.
Keep the integration test command `go test -p 1 ./...` with a disposable
`TEST_DATABASE_URL`: these tests truncate shared tables and must stay serial.
