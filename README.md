# Stick-It monorepo

Stick-It is a Flutter app backed by MonaServer, the Go API for [Stick-It Map](https://stick-it-map.lr-projects.de). The app lets users record stickers and street art, share them with groups, and explore them on a map. The server provides the API for authentication, images, groups, rankings, achievements, account workflows, and notifications.

The service uses PostgreSQL with PostGIS and an optional S3-compatible object store, SMTP server, and Firebase Cloud Messaging configuration.

## Development

Install the pinned Go tools and run the server checks from the repository root:

```bash
mise install
mise run test
mise run build
```

The Go module and its detailed setup instructions are in [`go-server/`](go-server/README.md). The OpenAPI contract is in [`api/openapi.yaml`](api/openapi.yaml).

For a production cutover from the Spring deployment, follow the
[`go-server/MIGRATION.md`](go-server/MIGRATION.md) guide. It covers the one-time
Flyway handoff and keeps the existing PostgreSQL and RustFS data in place.

For a complete local stack, create an ignored `.env.dev` as described in the Go server guide, then run:

```bash
docker compose -f docker-compose.dev.yml up --build
```

The API listens on `http://localhost:8080`. Its bundled OpenAPI document is available at `/public/api-docs`, with Swagger UI at `/swagger-ui`.

To work on the Flutter app, install Flutter, then run these commands from the repository root:

```bash
cd flutter
flutter pub get
dart run build_runner build
flutter analyze --no-fatal-infos --no-fatal-warnings
```

The repository pins Go 1.27.0, Flutter 3.47.1, and the API tooling in
[`mise.toml`](mise.toml). The same checks are available from the repository
root as `mise run flutter-analyze`, `mise run flutter-test`, and
`mise run flutter-api-test`; use `mise run flutter-build-web` for a release web
build.

The app uses the generated Dart client in `flutter/api/`. Regenerate it from the shared contract with:

```bash
cd flutter
openapi-generator generate -i ../api/openapi.yaml -g dart -o ./api
```

The Codemagic iOS workflow writes the app's `.config`, prepares signing, builds
an IPA, and uploads it to App Store Connect. Configure the iOS signing
identities and the `APP_STORE_CONNECT_PRIVATE_KEY`,
`APP_STORE_CONNECT_KEY_IDENTIFIER`, and `APP_STORE_CONNECT_ISSUER_ID` secrets
in Codemagic before enabling that workflow.

PostHog is configured at build time with the `POSTHOG_API_KEY` environment
variable and optional `POSTHOG_HOST`; configure the key in Codemagic and GitHub
Actions rather than committing it to either checked-in Flutter config file.

## Repository layout

- `flutter/`: Flutter app, platform projects, assets, and generated Dart API client
- `go-server/`: server module, database migrations, tests, and container image
- `api/`: OpenAPI sources and bundled contract
- `docker-compose.dev.yml`: local PostGIS, object storage, and server stack
- `docker-compose.yml`: deployment stack
- `codemagic.yaml`: mobile release workflow
- `mise.toml`: pinned development tools and tasks

## License

See [LICENSE](LICENSE).
