# API contract guide

## Source files

`openapi.yaml` is the bundled OpenAPI 3.0 contract consumed by both Go generators. The files under `methods/`, `parameters/`, and `schemas/` are the smaller authoring fragments kept alongside it. There is no checked-in bundling command that updates `openapi.yaml` from those fragments. When a matching fragment exists, keep it and the bundled contract synchronized in the same change.

Treat operation IDs, JSON property names, required fields, formats, response codes, and security declarations as compatibility-sensitive. The mobile clients and generated Go method signatures depend on them.

## Generation

Run generators from `go-server/`:

```bash
mise exec -- make gen-api
mise exec -- make gen-server
```

`make gen-api` updates `go-server/internal/gen/api/api.gen.go`. That package embeds the specification served at `/public/api-docs`. The command requires `oapi-codegen` on `PATH`; the checked-in file records v2.7.0.

`make gen-server` updates controllers, servicer interfaces, and models in `go-server/internal/gen/server/`. It expects a Java runtime, the OpenAPI Generator jar at `~/openapi-generator-cli.jar`, and `goimports` at `~/go/bin/goimports`. The checked-in output records OpenAPI Generator 7.19.0. The normal `mise.toml` installs only Go, so it does not provide the Java runtime or generator jar. `make gen` also runs sqlc, so do not use it for an API-only edit unless SQL generation is intended.

Do not edit either generated directory by hand. Commit the source and generated changes together.

## Server work required after contract changes

Generated code does not finish an endpoint change. Update the matching implementation in `go-server/internal/handler/` and check conversions in `internal/handler/convert.go`. If a new route is added, classify it in `go-server/cmd/server/main.go`; OpenAPI security metadata does not install runtime middleware.

Verify the result from `go-server/`:

```bash
mise exec -- gofmt -w internal/handler/*.go cmd/server/*.go
mise exec -- go vet ./...
mise exec -- go test ./...
```

Add or update route tests in `cmd/server/server_test.go` when paths, authentication, request bodies, response bodies, or status codes change.
