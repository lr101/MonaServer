.PHONY: gen gen-api gen-db gen-server build run tidy test test-integration

gen: gen-api gen-db gen-server

gen-api:
	oapi-codegen --config=internal/gen/api/oapi-codegen.yaml ../api/openapi.yaml

gen-db:
	cd internal/db && sqlc generate

gen-server:
	java -jar ~/openapi-generator-cli.jar generate \
		-i ../api/openapi.yaml \
		-g go-server \
		--additional-properties router=chi,packageName=genserver,outputAsLibrary=true,onlyInterfaces=true,hideGenerationTimestamp=true,sourceFolder=. \
		-o internal/gen/server
	~/go/bin/goimports -w internal/gen/server/

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
