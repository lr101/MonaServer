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
cd flutter
flutter pub get
```

3) Generate code (Freezed, Json Serializable, Riverpod)
```
# Generates all code
dart run build_runner build
```

4) Run the app
```
# Android
flutter run -d android

# iOS (requires macOS)
flutter run -d ios
```

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

### Analytics configuration

PostHog is initialized at build time from `POSTHOG_API_KEY` and the optional
`POSTHOG_HOST` setting. Keep the API key out of the repository: provide it as
an environment variable in Codemagic, or as the `POSTHOG_API_KEY` GitHub
Actions secret. The checked-in `.config` files intentionally omit it. Builds
without the key run with analytics disabled.

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
