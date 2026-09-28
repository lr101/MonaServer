.PHONY: gen gen-api gen-db gen-server verify-openapi-generator build run tidy test test-integration

OPENAPI_GENERATOR_JAR ?= $(HOME)/openapi-generator-cli.jar
OPENAPI_GENERATOR_VERSION ?= 7.19.0
OPENAPI_GENERATOR_SHA256 ?= 3d8140c691410e0004b1bb9b1e431c1293734830f30d6d5922f8e5dbf2e42e19

gen: gen-api gen-db gen-server

gen-api:
	oapi-codegen --config=internal/gen/api/oapi-codegen.yaml ../api/openapi.yaml

gen-db:
	cd internal/db && sqlc generate

verify-openapi-generator:
	test -f "$(OPENAPI_GENERATOR_JAR)"
	test "$$(sha256sum "$(OPENAPI_GENERATOR_JAR)" | cut -d' ' -f1)" = "$(OPENAPI_GENERATOR_SHA256)"
	test "$$(java -jar "$(OPENAPI_GENERATOR_JAR)" version)" = "$(OPENAPI_GENERATOR_VERSION)"

gen-server: verify-openapi-generator
	java -jar "$(OPENAPI_GENERATOR_JAR)" generate \
		-i ../api/openapi.yaml \
		-g go-server \
		-t generator-templates \
		--additional-properties router=chi,packageName=genserver,outputAsLibrary=true,onlyInterfaces=true,hideGenerationTimestamp=true,sourceFolder=. \
		-o internal/gen/server
	gofmt -w internal/gen/server/

build:
	go build -o bin/server ./cmd/server

run:
	go run ./cmd/server

tidy:
	go mod tidy

# Unit tests only (integration tests skip without TEST_DATABASE_URL).
test:
	go test ./...

# Integration tests against a real Postgres. Override TEST_DATABASE_URL as needed.
# Runs with -p 1 because the DB-backed packages TRUNCATE a shared database.
TEST_DATABASE_URL ?= postgres://monaserver:monaserver@localhost:5433/monaserver_test?sslmode=disable
test-integration:
	TEST_DATABASE_URL="$(TEST_DATABASE_URL)" go test -p 1 ./...
