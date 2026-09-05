# Stick-It: Map & Stickers

[![Codemagic build status](https://api.codemagic.io/apps/63413ae4c15332316120753f/63413ae4c15332316120753e/status_badge.svg)](https://codemagic.io/app/63413ae4c15332316120753f/63413ae4c15332316120753e/latest_build)
[![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/lr101/stick-it/issues)
[![Discord](https://img.shields.io/badge/Discord-%235865F2.svg?style=for-the-badge&logo=discord&logoColor=white&style=flat)](https://discord.gg/ReMZ8j6S8X)
[![Play Store](https://img.shields.io/badge/Google_Play-414141?style=for-the-badge&logo=google-play&logoColor=white&style=flat)](https://play.google.com/store/apps/details?id=com.TheGermanApps.buff_lisa)
[![App Store](https://img.shields.io/badge/App_Store-0D96F6?style=for-the-badge&logo=app-store&logoColor=white&style=flat)](https://apps.apple.com/de/app/stick-it-geomap/id6446781455)

## Description

Stick-It lets you capture where stickers and street art are found, and explore posts from others on an interactive map.

Key features:
- Groups and community: Share posts with groups and discover new content from friends and others.
- Interactive map: View stickers and groups on the map and explore local rankings.
- Fast posting: Take a photo, tag it to a location, and share in seconds.
- Overview feed: Quickly enable/disable groups to curate your feed.

## How does it work?

The Stick-It app is built using the **Flutter** framework, which allows for cross-platform development on Android, iOS, and web platforms. Here's a high-level overview of how the app works:

### Project structure

The app is structured as follows:
 - **data**: contains data models, repositories, and services. Repositories handles and provides database operations. Services provide business logic for the app, including holding global state values and making api calls.
 - **features**: contains the app's features (mostly widgets where a route leads to), such as the main screen, group screen, and profile screen. Each directory is split into representation (UI) and data (screen specific logic and states).
 - **util**: contains utility classes, such as the app's theme, routing, and error handling.
 - **widgets**: contains reusable widgets that are used across the app. Each directory is split into representation (UI) and data (screen specific logic and states).

## Quick start (development)

1) Prerequisites
- Install `mise`, then run `mise install` from the monorepo root to install the pinned Flutter 3.47.2 SDK and build tools.
- Ensure a working Android/iOS development environment (Android Studio / Xcode on macOS for iOS).

2) Install dependencies
Run these commands from the monorepo root:
```
mise run flutter-setup
```

3) Generate code (Freezed, Json Serializable, Riverpod)
```
# Generates all code
cd flutter
dart run build_runner build
```

4) Run the app
```
# Android
mise run flutter-run -- -d android

# iOS (requires macOS)
mise run flutter-run -- -d ios
```

Build from the monorepo root with `mise run flutter-build-web` or
`mise run flutter-build-apk`. The Android task requires the Android SDK; iOS
requires macOS and Xcode.

### Browser verification and Playwright MCP

For changes that affect the web UI or startup path, first start the disposable
PostGIS, RustFS, and Go API stack and seed its reusable scenarios from the
repository root:

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
E2E_API_URL=http://127.0.0.1:8081 mise run flutter-verify-web
```

The check builds `flutter/build/web`, starts a static server on port 4173,
and verifies login and the Groups screen. The reusable accounts, groups, pins,
likes, and scenario IDs are documented in [`../testdata/README.md`](../testdata/README.md)
and generated under ignored `testdata/` files. The default test API is
loopback-only; set `TESTDATA_ALLOW_REMOTE_API=1` only when intentionally using
a disposable remote test API. The Playwright fallback setup has its separate
`E2E_ALLOW_REMOTE_API=1` opt-in.

The root `.mcp.json` registers Playwright MCP. For an interactive agent
session, build and serve the app, then navigate the MCP browser to
`http://localhost:4173/`:

```bash
E2E_API_URL=http://127.0.0.1:8081 mise run flutter-build-web
cd flutter/e2e && npm ci && npm run install:browsers
python3 -m http.server 4173 --bind 127.0.0.1 --directory ../build/web
```

Enable Flutter web accessibility by activating the `Enable accessibility`
control before using DOM locators. Log in as `stickitviewer` and use the
scenario groups from `testdata/scenarios.json` to inspect joined, public
unjoined, private, and empty states. GitHub Actions performs the build and
artifact checks but does not run this browser E2E suite; agents run it locally
when UI behavior needs verification. See `flutter/AGENTS.md` for the
agent-specific workflow.

### Optional: API generator setup
The shared OpenAPI contract lives at `../api/openapi.yaml` when these commands run from `flutter/`.
```
# Install the OpenAPI generator
pip install openapi-generator-cli

# Generate OpenAPI client
flutter pub global activate openapi_generator_cli
export PATH="$PATH":"$HOME/.pub-cache/bin"
openapi-generator generate -i ../api/openapi.yaml -g dart -o ./api
```

## Developer references

### Set new icon
1. change asset path in pubspec.yaml
2. run: ```flutter packages pub run flutter_launcher_icons:main```

### Build Android APK
1. run: ```flutter build apk```

### Release app

The Android release to Google Play is managed by the root `codemagic.yaml`
workflow. A Codemagic push webhook starts `flutter-android` for updates merged
into `main`. Configure the Android keystore, Firebase, Google Play, and app
configuration variables before enabling the webhook.

### Generate API (summary)
1. Activate openapi-generator: `flutter pub global activate openapi_generator_cli`
2. Run from `flutter/`: `openapi-generator generate -i ../api/openapi.yaml -g dart -o ./api`

## Troubleshooting

- iOS minimum version error (Firebase):
  - Error: The plugin "firebase_core" requires iOS 15.0+.
  - Fix: In `ios/Podfile`, set `platform :ios, '15.0'` and ensure the `post_install` hook sets `IPHONEOS_DEPLOYMENT_TARGET` to `15.0` for all pods. Then run on macOS: `flutter clean && flutter pub get && cd ios && pod repo update && pod install`.

- Code generation errors (Freezed/Riverpod):
  - Run: `dart run build_runner build`.
  - Ensure your files contain the correct `part 'file.freezed.dart';` and `part 'file.g.dart';` statements when required.

- Android build issues:
  - Run: `flutter clean && flutter pub get`.
  - Check your Java SDK and Android SDK versions in Android Studio.

## Contributing

Contributions are welcome. Please open an issue for bugs or feature requests, or submit a pull request. For larger changes, open an issue first to discuss the approach.

## License

This project is licensed under the terms of the LICENSE file included in the repository.
