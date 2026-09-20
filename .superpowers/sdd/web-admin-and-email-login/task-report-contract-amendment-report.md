# Report submission contract amendment

## Commits

- Source implementation: `2ad1358c380b7174a23a675ea95a8a60d8d5e7d3`
- Generated-output reproducibility follow-up: `b177ba465a8e625e74256291d3c7602f67c036ce`

## Changed files

- `api/schemas/reportDto.yaml`
- `api/openapi.yaml`
- `go-server/internal/gen/api/api.gen.go`
- `go-server/internal/gen/server/api/openapi.yaml`
- `go-server/internal/gen/server/model_report_dto.go`
- `flutter/api/lib/model/report_dto.dart`
- `flutter/api/doc/ReportDto.md`
- `flutter/api/test/report_dto_contract_test.dart`
- `go-server/internal/handler/report_servicer.go`
- `go-server/internal/handler/report_servicer_test.go`

## Interface decision

`reportDto` keeps `userId`, `report`, and `message` required. It adds nullable
`targetId` as a UUID string and nullable `targetKind` as a string with a
32-byte handler limit. A target ID without a kind retains the existing user
target default; a kind without an ID is rejected with HTTP 400.

The handler rejects malformed, empty, overlong, control-character, invalid
UTF-8, and nil UUID target values before persistence. It maps only target ID
and kind into `service.ReportSubmission`. Target name and deleted state remain
owned by the report service. Reporter identity continues to come from the
authenticated context; a forged body `userId` remains forbidden.

## Generator commands

Go generation, both from `go-server/`:

```text
mise exec -- make gen-api
OPENAPI_GENERATOR_JAR=/root/.cache/openapi-generator/openapi-generator-cli-7.19.0.jar mise exec -- make gen-server
```

The server generator verified the pinned OpenAPI Generator `7.19.0` JAR and
its repository SHA256 before generating.

The Dart generator used the pinned OpenAPI Generator `7.9.0` JAR:

```text
java -jar /root/.cache/openapi-generator/openapi-generator-cli-7.9.0.jar generate -i ../api/openapi.yaml -g dart -o "$generated_api" -t generator-templates --global-property modelTests=false,apiTests=false --skip-validate-spec
bash ../.github/scripts/normalize-openapi-generated.sh "$generated_api" api
```

The final check used the same excluded-file `diff -ru` comparison as
`.github/workflows/build-flutter.yml`. Before the follow-up commit it failed
only for `flutter/api/doc/ReportDto.md`; after promoting the normalized
generator artifact, the exact comparison exited `0`.

## Checks and results

- TDD red check: `mise exec -- go test ./internal/handler -run '^(TestReportTargetFromDTO|TestCreateReportRejectsInvalidTargetBeforePersistence)$'` first failed to compile because the generated DTO fields and parser did not exist.
- Focused Go handler check: `mise exec -- go test ./internal/handler` — exit `0`.
- Focused report behavior check: `mise exec -- go test -v ./internal/handler -run '^TestCreateReport'` — exit `0`; malformed-target cases passed, compatibility/mail-only cases passed, and database-backed persistence/forged-reporter cases were skipped because `TEST_DATABASE_URL` was unset.
- Go vet: `mise exec -- go vet ./...` — exit `0`.
- Go suite: `mise run test` — exit `0`; all listed Go packages passed.
- Go build: `mise run build` — exit `0`.
- Dart API suite: `mise run flutter-api-test` — exit `0`; `205` tests passed, including nullable target serialization/deserialization and legacy payload tests.
- Dart formatting: `mise exec -- dart format flutter/api/test/report_dto_contract_test.dart` — exit `0`, `0` files changed.
- Final exact Dart generation/normalization comparison — exit `0`.
- Final staged/diff hygiene: `git diff --check` — exit `0` before both task commits.

## Availability and limitations

`TEST_DATABASE_URL` was unavailable. The local PostgreSQL readiness probe was
responding, but no disposable test database DSN was configured, so the
PostGIS-backed persistence and forged-reporter integration cases were not run.
No production services, SMTP, object storage, sends, deployment, push, or PR
operations were used.

No unresolved source-contract or handler issue remains in this bounded slice;
the coordinator should rerun the skipped database cases against a disposable
PostGIS database during integration review.
