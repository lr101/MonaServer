.PHONY: gen gen-api gen-db gen-server build run tidy

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
