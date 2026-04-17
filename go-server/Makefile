.PHONY: gen gen-api gen-db build run tidy

gen: gen-api gen-db

gen-api:
	oapi-codegen --config=internal/gen/api/oapi-codegen.yaml ../api/openapi.yaml

gen-db:
	cd internal/db && sqlc generate

build:
	go build -o bin/server ./cmd/server

run:
	go run ./cmd/server

tidy:
	go mod tidy
