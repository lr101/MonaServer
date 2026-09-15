# T01 fix-round-1 contract report

Status: READY_FOR_SCOPED_REVIEW (contract commit complete; runtime integration is recorded below)

Base: `868a38b` (`feat: freeze web admin and email auth contracts`)
Contract implementation commit: `dd8cb3d` (`fix: align generated T01 contracts with wire invariants`)

## Contract and generator corrections

- The audience contract is a strict `adminAudience` union of `selected`, `filter`, and `all`. `selected` requires non-empty `ids`; `filter` requires `filter`; `all` rejects `ids` and `filter`. Every branch requires `kind` and `resource`.
- `adminAction` has all eight action branches. Email requires `body` and `subject`; push requires `body` and `title`; security actions require `reason`; the remaining branches retain their action discriminator. Generated server decoding and the Dart model template enforce these branch invariants.
- Filters are resource-tagged. Account audiences use `adminUserFilterDto` with `resource: accounts`; report audiences use `adminReportFilterDto` with `resource: reports`, supporting `statuses`, `types`, `createdAfter`, `createdBefore`, and `assigneeUserId`. The nested filter resource must match the outer audience resource, and cross-resource criteria are rejected. The existing `ListAdminReports` method signature remains compatible with its adapter while snapshots carry the complete report criteria.
- `200` and `202` preview responses now share `adminAudiencePreviewResponseDto`, requiring `snapshotId` and `status`. Pending responses carry `jobId`; ready responses carry the typed preview fields. Dart exposes `AdminAudiencesApi.previewAdminAudience` returning `AdminAudiencePreviewResponseDto?`, so both statuses use one typed result shape.
- Handwritten generator sources are in `go-server/generator-templates/` and `flutter/generator-templates/`, outside generated `go-server/internal/gen/`. Go generation verifies OpenAPI Generator `7.19.0` version and SHA-256 `3d8140c691410e0004b1bb9b1e431c1293734830f30d6d5922f8e5dbf2e42e19`. Dart generation uses the pinned `7.9.0` jar.
- Flutter model/API tests are disabled by source-controlled generator properties (`modelTests=false,apiTests=false`). The generated v3 TODO/no-op fixtures introduced by the T01 implementation were removed; retained v2 fixtures remain, and focused contract coverage is in `flutter/test/web_admin_contract_test.dart`.
- `.github/scripts/normalize-openapi-generated.sh` uses the checked-in `flutter/api` tree as a byte-identical reference for unchanged artifacts, and normalizes only changed/new generated artifacts. This makes generator whitespace deterministic without rewriting unrelated generated files.
- The OpenAPI contract declares `503` unavailable responses on every gated v3 operation. A route scan found 26 `/api/v3` operations and all 26 declare the shared response.

## Frozen type and method catalog

- Go generated server models: `genserver.AdminAudience`, `genserver.AdminAudienceFilter`, `genserver.AdminAction`, `genserver.AdminAudiencePreviewResponseDto`, `genserver.AdminReportFilterDto`; their generated `Assert*Required`/`Assert*Constraints` and canonical `UnmarshalJSON` methods are the transport validation boundary.
- Go embedded API models retain oapi-codegen union accessors (`AsSelectedAudience`, `AsFilterAudience`, `AsAllAudience`, `AsAdminUserFilterDto`, and `AsAdminReportFilterDto`) for the public spec package.
- Dart generated models: `AdminAudience`, `AdminAudienceFilter`, `AdminAction`, `AdminAudiencePreviewResponseDto`, and `AdminReportFilterDto`.
- Dart generated client method: `AdminAudiencesApi.previewAdminAudience`, with the raw `previewAdminAudienceWithHttpInfo` method retained for callers that need HTTP metadata.

## Verification

All commands ran from the stated worktree unless noted.

- `mise exec -- flutter test --no-pub test/web_admin_contract_test.dart` from `flutter`: PASS, 11 tests. Covers positive and negative selected/filter/all branches, account/report resource-safe filters, all eight action branches, constructor serialization, v2 login 200/401 compatibility, and preview 202/200 decoding.
- `mise exec -- flutter test --no-pub` from `flutter/api`: PASS, 203 tests.
- `mise exec -- flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings` from `flutter/api`: PASS with two existing generated `unawaited_return_in_try_block` warnings in `lib/api_client.dart:77` and `:87`.
- `java -jar /root/openapi-generator-cli.jar validate -i api/openapi.yaml`: PASS with six existing unused-model recommendations (`email`, `veryLongStringNullable`, `image`, `adminAudiencePreviewDto`, `adminAudiencePreviewAcceptedDto`, `visibility`).
- `OPENAPI_GENERATOR_JAR=/root/openapi-generator-cli.jar mise exec -- make verify-openapi-generator` from `go-server`: PASS. Verified version `7.19.0` and the SHA above.
- `OPENAPI_GENERATOR_JAR=/root/openapi-generator-cli.jar mise exec -- make gen-api` and `... make gen-server` from `go-server`: PASS.
- `mise exec -- go test ./internal/gen/server ./internal/gen/api` from `go-server`: PASS (packages have no test files; compile succeeded).
- Pinned Dart regeneration into a temporary directory with the custom templates, `modelTests=false,apiTests=false`, reference-aware normalizer, and `diff -ru` against `flutter/api`: PASS (`deterministic-dart-generation`).
- `git diff --check`: PASS before the contract commit.

## Scope and prior-report corrections

No Go runtime handler/service/main files, database migrations, recovery port, security/storage enum, or field contract changed in this slice. The prior report's nullable/optional union behavior is superseded by the strict branch schema and generated validators above. Its separate ready/accepted preview decoding is superseded by the common response and typed convenience method. Generated v3 TODO tests are no longer generated, and the missing v2 compatibility and resource-safe report-filter fixtures are now covered. Generator reproducibility now includes the verified Go jar digest and deterministic whitespace normalization.

## Runtime integration

The two authorized runtime commits were not yet applied when this report was first written. Their SHAs and the combined scoped test/vet results are appended in the final update below.

## Final runtime integration update

The contract commit was followed by the two authorized runtime cherry-picks, both cleanly:

- `ac8a327` from `00bc9ff0fd62b6c198a18a5255b16b75a6142919` (`fix: safely gate v3 runtime routes`)
- `7d8f309` from `413aa44f1bf80ced5280a871f7d8583faf307b3a` (`fix: normalize v3 controller errors`)

Scoped combined checks after those cherry-picks:

- `mise exec -- go vet ./cmd/server ./internal/handler`: PASS.
- `mise exec -- go test ./cmd/server ./internal/handler`: FAIL only in `cmd/server` test `TestV3EnabledAdminMutationCannotReturnPlaceholderSuccess`; it received HTTP 400 `invalid_request` instead of the test's expected HTTP 503 `feature_unavailable`. `./internal/handler` passed. The runtime fixture sends `{"action":{"action":"email"},"payloadHash":"payload-hash","snapshotId":"snapshot-id"}`, which is rejected by the contract validator before the gated placeholder service is reached because email now requires `body` and `subject`. No runtime file was changed in this slice; root/runtime ownership should update that fixture or gate ordering while preserving the strict contract validation.

Final branch tip before this report update: `7d8f309`. The report-only commit containing this final integration evidence follows.
