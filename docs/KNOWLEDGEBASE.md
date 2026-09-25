# Engineering knowledgebase

This page collects implementation facts that cross repository boundaries and
are easy to miss. Keep current behavior here; use the linked source files for
wire contracts, runtime configuration, and detailed procedures.

## Start with the authoritative guide

| Topic | Current reference |
| --- | --- |
| Project overview and common commands | [Repository README](../README.md) |
| OpenAPI contract and generated API workflow | [`api/openapi.yaml`](../api/openapi.yaml), [`api/AGENTS.md`](../api/AGENTS.md) |
| Go configuration and API runtime | [`go-server/README.md`](../go-server/README.md) |
| Flutter structure and lifecycle | [`flutter/ARCHITECTURE.md`](../flutter/ARCHITECTURE.md) |
| Admin web scope and first-admin setup | [`admin-web/README.md`](../admin-web/README.md) |
| Local API, database, object-store, and browser stack | [`AGENT_LOCAL_STACK.md`](AGENT_LOCAL_STACK.md) |
| Compose deployment and upgrades | [`DEPLOYMENT.md`](DEPLOYMENT.md) |
| Build and CI cache behavior | [`BUILD_SPEED.md`](BUILD_SPEED.md) |

`api/openapi.yaml` is the bundled API contract. Keep its authoring fragments in
`api/methods/`, `api/parameters/`, and `api/schemas/` synchronized when they
exist. OpenAPI security declarations describe the contract; Go route grouping
in `go-server/cmd/server/main.go` installs the runtime authorization middleware.
Generated clients and controllers must be regenerated from their sources.

## Cross-component behavior

### Batch reads and image loading

`POST /api/v3/batch` accepts 1–100 authenticated read requests and returns one
result per item in request order. It supports pin, user, and group image URLs,
user summaries, and pin likes. Each item retains the authorization and
visibility behavior of its ordinary read handler. See the [contract](../api/methods/batchRead.yaml),
[Go implementation](../go-server/internal/handler/batch_servicer.go), and
[Flutter coalescer](../flutter/lib/data/service/batch_read_coalescer.dart).

Flutter combines concurrent cache misses in a session-scoped coalescer; the
coalescer does not replace repository cache policies. Image URLs supplied by
sync or list responses live in a bounded in-memory registry separate from image
bytes. Visible images still download lazily. A supplied URL that has expired or
cannot be fetched falls back to the normal URL lookup path. Treat these URLs as
session data: do not persist, log, or carry them across account changes. Use
cache-aware image fetches for ordinary refreshes; force replacement only when
an upload or image version change requires new bytes.

Group and user pin services traverse server pages of 20 items using creation
date and ID tie-breaks. Feed paging works over the local pin set. Keep the two
concerns separate: local scrolling must not be treated as proof that a remote
group or user pin list was completely fetched.

### Flutter session and DTO handling

The API client owns an in-memory access token and serializes refresh attempts.
A refresh rejection expires the captured session; transient refresh failures
leave it active. Account-scoped database facades and session guards prevent
late asynchronous work from an old account from updating the current session.
Sync starts from the app lifecycle coordinator, not from provider construction
or rebuilds. See [Flutter architecture](../flutter/ARCHITECTURE.md) for the
session, cache, and sync rules.

JSON number fields can arrive as either integers or decimals. In handwritten
mapping, normalize through `num` (for example, with `toDouble()`) instead of
casting an integer directly to `double`; pin coordinates use this conversion in
[`PinEntity.fromDto`](../flutter/lib/data/entity/pin_entity.dart).

### Browser origins and CORS

Flutter Web validates its configured API origin before startup. `API_HOST`
selects the backend for standalone builds; the combined deployment can use the
page origin. The Compose web listener routes consumer API and signed object
requests through the public origin. Standalone cross-origin deployments still
need working CORS on both the API and object store. Batching reduces API call
count, but cross-origin requests can still require browser preflights.

### Admin boundary

`admin-web/` is a static sibling app with its own admin session. It uses the
opaque admin cookie and in-memory CSRF value; it does not use consumer JWTs.
Authorization is enforced by the Go server, so UI capability checks are only
for presentation. Email and Push campaign records save content; the Login
action sends one-time login links. General campaign delivery and the admin bulk
job worker are not part of the current admin-web scope. See the
[admin guide](../admin-web/README.md) and [server configuration](../go-server/README.md).
