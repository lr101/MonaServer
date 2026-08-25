# MonaServer

MonaServer is the Go backend for [Stick-It Map](https://stick-it-map.lr-projects.de). It provides the mobile API for geotagged image sharing in groups, JWT authentication, rankings, achievements, account workflows, and scheduled notifications.

The service uses PostgreSQL with PostGIS and an optional S3-compatible object store, SMTP server, and Firebase Cloud Messaging configuration.

## Development

Install the pinned tools and run the checks from the repository root:

```bash
mise install
mise run test
mise run build
```

The Go module and its detailed setup instructions are in [`go-server/`](go-server/README.md). The OpenAPI contract is in [`api/openapi.yaml`](api/openapi.yaml).

For a complete local stack, create an ignored `.env.dev` as described in the Go server guide, then run:

```bash
docker compose -f docker-compose.dev.yml up --build
```

The API listens on `http://localhost:8080`. Its bundled OpenAPI document is available at `/public/api-docs`, with Swagger UI at `/swagger-ui`.

## Repository layout

- `go-server/`: server module, database migrations, tests, and container image
- `api/`: OpenAPI sources and bundled contract
- `docker-compose.dev.yml`: local PostGIS, object storage, and server stack
- `docker-compose.yml`: deployment stack
- `mise.toml`: pinned Go and generator tools

## License

See [LICENSE](LICENSE).
