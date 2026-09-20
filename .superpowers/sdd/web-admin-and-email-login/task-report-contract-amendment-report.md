# Report submission contract amendment

## Commits

- Source implementation: `2ad1358c380b7174a23a675ea95a8a60d8d5e7d3`
- Generated-output reproducibility follow-up: `b177ba465a8e625e74256291d3c7602f67c036ce`
- Round 1 review fix: `35ea7b874d10bb4eb1a95a018cf03490aa5a66ea`

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
- `go-server/cmd/server/server_test.go`

## Interface decision

`reportDto` keeps `userId`, `report`, and `message` required. It adds nullable
`targetId` as a UUID string and nullable `targetKind` as a string with a
32-byte handler limit. A target ID without a kind retains the existing user
target default; a kind without an ID is rejected with HTTP 400.

The handler rejects malformed, empty, overlong, all-Unicode-control-character,
invalid UTF-8, and nil UUID target values before persistence. The target-kind
boundary check uses `unicode.IsControl`, including tab and other C0/C1 control
runes. It maps only target ID and kind into `service.ReportSubmission`. Target
name and deleted state remain owned by the report service. Reporter identity
continues to come from the authenticated context; a forged body `userId`
remains forbidden.

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
generator artifact, the exact comparison exited `0`. The round 1 review reran
the same pinned generation and normalization comparison and it remained clean.

## Checks and results

- TDD red check: `mise exec -- go test ./internal/handler -run '^(TestReportTargetFromDTO|TestCreateReportRejectsInvalidTargetBeforePersistence)$'` first failed to compile because the generated DTO fields and parser did not exist.
- Round 1 TDD red check: `mise exec -- go test ./internal/handler -run '^TestCreateReportRejectsInvalidTargetBeforePersistence$'` — exit `1` before the handler fix; the new tab and unit-separator cases returned `503`, demonstrating the old NUL/CR/LF-only boundary was insufficient.
- Round 1 focused handler check: `mise exec -- go test ./internal/handler -run '^(TestReportTargetFromDTO|TestCreateReportRejectsInvalidTargetBeforePersistence)$'` — exit `0` after the `unicode.IsControl` boundary fix.
- Round 1 focused handler/reporter check: `mise exec -- go test ./internal/handler -run '^(TestReportTargetFromDTO|TestCreateReportRejectsInvalidTargetBeforePersistence|TestCreateReportPersistsWithoutSMTPAndRejectsForgedReporter)$' -count=1` — exit `0`; the database-backed test was skipped because `TEST_DATABASE_URL` was unset.
- Route-level coverage check: `mise exec -- go test ./cmd/server -run '^TestEndpointReport(TargetFieldsRoute)?$' -count=1 -v` — exit `0`; `TestEndpointReportTargetFieldsRoute` was skipped because `TEST_DATABASE_URL` was unset. The test covers generated-controller decoding for omitted, explicit-null, defaulted target ID, explicit target kind, malformed target fields, control-character target kind, and forged body reporter cases.
- A root-directory invocation, `mise exec -- go test ./cmd/server -run '^TestEndpointReportTargetFieldsRoute$' -count=1`, failed with `go.mod file not found`; rerunning the same package check from `go-server/` produced the skip/pass result above.
- Focused Go packages: `mise exec -- go test ./internal/handler ./cmd/server -count=1` — exit `0`.
- Focused Go vet: `mise exec -- go vet ./internal/handler ./cmd/server` — exit `0`.
- Focused Go handler check: `mise exec -- go test ./internal/handler` — exit `0`.
- Focused report behavior check: `mise exec -- go test -v ./internal/handler -run '^TestCreateReport'` — exit `0`; malformed-target cases passed, compatibility/mail-only cases passed, and database-backed persistence/forged-reporter cases were skipped because `TEST_DATABASE_URL` was unset.
- Go vet: `mise exec -- go vet ./...` — exit `0`.
- Go suite: `mise run test` — exit `0`; all listed Go packages passed.
- Go build: `mise run build` — exit `0`.
- Dart API suite: `mise run flutter-api-test` — exit `0`; `205` tests passed, including nullable target serialization/deserialization and legacy payload tests.
- Dart formatting: `mise exec -- dart format flutter/api/test/report_dto_contract_test.dart` — exit `0`, `0` files changed.
- Pinned Go generation: `mise exec -- make gen-api` and `OPENAPI_GENERATOR_JAR=/root/.cache/openapi-generator/openapi-generator-cli-7.19.0.jar mise exec -- make gen-server` — both exit `0`; generator logs contained only the repository's existing OpenAPI warnings.
- Final clean Go comparison: `git diff --exit-code -- go-server/internal/gen/api/api.gen.go` — exit `0`; `git diff --exit-code -- go-server/internal/gen/server` — exit `0`. The review fix changed no generated output.
- Exact CI Dart generation/normalization comparison: `generated_api=$(mktemp -d /tmp/mona-report-dart-gen-round1.XXXXXX); java -jar /root/.cache/openapi-generator/openapi-generator-cli-7.9.0.jar generate -i ../api/openapi.yaml -g dart -o "$generated_api" -t generator-templates --global-property modelTests=false,apiTests=false --skip-validate-spec; bash ../.github/scripts/normalize-openapi-generated.sh "$generated_api" api; diff -ru --exclude pubspec.yaml --exclude pubspec.lock --exclude .dart_tool --exclude build --exclude test api "$generated_api"` — exit `0` (`exact_ci_dart_diff=0`).
- Final staged/diff hygiene: `git diff --check` — exit `0` before both task commits.

## Availability and limitations

`TEST_DATABASE_URL` was unavailable. The local PostgreSQL readiness probe was
responding, but no disposable test database DSN was configured, so the
PostGIS-backed persistence and forged-reporter integration cases, including the
new route-level HTTP cases, were not run. No production services, SMTP, object
storage, sends, deployment, push, or PR operations were used.

No unresolved source-contract or handler issue remains in this bounded slice;
the coordinator should rerun the skipped database and route cases against a
disposable PostGIS database during integration review. Final source-fix commit:
`35ea7b874d10bb4eb1a95a018cf03490aa5a66ea`.
