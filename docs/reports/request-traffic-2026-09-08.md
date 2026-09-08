# Client–server request investigation

Date: 2026-09-08. Baseline: `origin/develop` at `e03c64f`.
Branch: `investigate/request-traffic-report`.

## Findings

The main measured cost is **first-time per-pin request fan-out**, amplified by
browser CORS preflights. The existing image cache works for short return visits:
scrolling back and revisiting the feed generated **zero additional API or object
requests** in both runs. This is not evidence of a general request loop on scroll.

The highest-value change is to use image URLs that sync already returns. The
client currently drops these URLs, then requests them individually when displaying
pins. Batch or embed the visible pins' likes next. Also remove redundant group
refreshes and cache-bypassing group image prefetches.

No application behavior was changed during this investigation.

## Live setup and measurement

Started a development stack from the new worktree using the repository's
[native stack guide](../AGENT_LOCAL_STACK.md):

- Native PostgreSQL/PostGIS, separate disposable database `traffic_report`.
- Foreground RustFS, S3 `127.0.0.1:9200`, console `127.0.0.1:9201`, separate
  `/tmp/traffic-report-objects` data directory.
- Go API from this checkout at `127.0.0.1:8181`, with JSON request logging.
- Release Flutter Web Wasm build with JavaScript fallback, compiled with
  `API_HOST=http://127.0.0.1:8181`, served at `127.0.0.1:4273`.
- Playwright Chromium, fresh browser context, 450×900 viewport, accessibility
  enabled. Navigated the real UI; API calls were not mocked.

Seeded the existing three-user/four-group fixture through the API, then created
28 more pins in the joined public group: 30 joined-group pins, two public unjoined
pins, one private pin. Tiny fixture PNGs exercise image requests but do **not**
represent production image sizes. Firebase and SMTP were not configured; location
permission was not granted, so regional ranking and location-driven map activity
were not measured. Browser app assets and external map requests are excluded from
the table. This is a request-count investigation, not a production latency or
bandwidth benchmark.

Captured browser `Network.requestWillBeSent` events using Chromium's DevTools
protocol, which includes `OPTIONS` preflights, and compared them with Go logs.
Raw traces stayed local and were not committed; the
[sanitized endpoint counts](request-traffic-2026-09-08.csv) contain no credentials,
object signatures, resource IDs, or request bodies.

Procedure: fresh login → Feed → 20 downward wheel movements of 800 pixels with
450 ms pauses → 20 upward movements with 200 ms pauses → Groups → Feed → reload
in the same context → Groups/menu/search → enter `Stick-It Fixture` → open
`Public Unjoined Pins` → select its gallery. Each phase ends with a 3.5-second
settling interval. Fast scrolling can skip mounting some cards: 30 images but only
25 unique pin-like reads were observed. Phase totals reflect this exact sequence,
including prefetch, rather than a fixed cost per rendered screen.

| UI phase | API GET/POST | API OPTIONS | Object GET | Total |
|---|---:|---:|---:|---:|
| Fresh login and home | 7 | 7 | 4 | 18 |
| Open Feed | 14 | 13 | 9 | 36 |
| Scroll down | 46 | 46 | 21 | 113 |
| Scroll back | 0 | 0 | 0 | 0 |
| Groups → Feed revisit | 0 | 0 | 0 | 0 |
| Reload with persisted browser storage | 4 | 3 | 3 | 10 |
| Open search and enter fixture name | 5 | 5 | 3 | 13 |
| Open public unjoined group | 5 | 4 | 1 | 10 |
| Select unjoined group's gallery | 2 | 2 | 2 | 6 |
| **Total** | **83** | **80** | **43** | **206** |

The login/feed/scroll/revisit phases were run twice and produced the same counts.
Reload/search/gallery were measured in the extended second run. Its time window
contains 164 Go request log entries, all HTTP 200: 163 browser API/preflight
requests plus one separate diagnostic `OPTIONS /api/v3/sync` probe. Thus the
measured request burst is not a retry storm caused by API failures. Object GET
counts are browser-issued requests, not a claim about transfer bytes or cache hits.

## Prioritized improvements

### 1. Preserve and reuse supplied pin image URLs — high priority

**Measured:** opening and scrolling the feed fetched 30 individual
`GET /api/v2/pins/{id}/image` URLs, 30 matching preflights, and 30 object images.
Yet [server sync](../../go-server/internal/handler/pins_servicer.go) already puts
an image URL in every returned changed pin. The client's
[`PinEntity.fromDto`](../../flutter/lib/data/entity/pin_entity.dart) drops `image`;
[`CustomFeed`](../../flutter/lib/widgets/custom_feed/presentation/custom_feed.dart)
and the image provider later call `fetchImage(id)`.

Retain URL plus expiry/version metadata independently of cached bytes and use
[`fetchImageFromUrl`](../../flutter/lib/data/repository/image_repository.dart)
when a visible or prefetched pin has a fresh supplied URL. That repository method
already checks cached bytes, deduplicates active requests, and falls back to the
URL endpoint if the supplied URL fails. Keep this fallback for expired signatures.
Do not download every synced image eagerly.

For unjoined group pages, request URLs for a bounded page using the existing
`GET /api/v2/pins?...&withImage=true` contract, or use its `ids` parameter for a
bounded batch of missing URLs. Persist the returned URLs instead of discarding
them. Sync-covered joined pins need no extra batch.

**Potential saving in this fixture:** eliminate 30 URL requests and their 30
preflights, **60 of the 149 feed-open/down-scroll requests (~40%)**, provided the
sync URLs are still valid. The 30 object downloads remain useful. This is an
estimate from the observed request breakdown; no optimized implementation was run.

### 2. Fetch likes and creator summaries in batches — high priority

**Measured:** the same feed sequence made 25 `GET /pins/{id}/likes` requests and
25 preflights. It also fetched one creator's `/users/{id}` twice on opening Feed.
[`LikeService`](../../flutter/lib/widgets/custom_feed/data/like_service.dart)
loads likes separately on a cache miss. The local feed page size is three;
[`UserService`](../../flutter/lib/data/service/user_service.dart) has a cache-miss
read but no repository-wide active-request map. Prefetch and mounted consumers
can overlap. The duplicate user request is observed; the exact provider lifecycle
that caused it still needs a focused regression test.

Add an authenticated, bounded batch read for visible pin-like summaries, or an
optional feed projection containing likes and distinct creator summaries. Keep
viewer-specific `likedByUser` fields scoped to the authenticated account, retain
visibility checks for each pin, and preserve optimistic updates and reconciliation.
A page of 20 pins could replace up to 20 like calls with one batch call. This
requires coordinated API source/generation/server/client work. Do not mix it with
an unrelated API redesign.

Add shared in-flight deduplication for user metadata; seed the user repository
from any expanded response. The like cache is nominally 50 items/one hour, but
its generic eviction includes an age gate, so it is not a strict 50-item limit.
Test long sessions and cache eviction separately; the 30-pin run does not establish
behavior after prolonged browsing. Do not increase TTL indiscriminately: likes
can change while the user browses.

### 3. Give group refreshes explicit freshness and deduplication — high priority

**Measured:** home fetched `/api/v3/sync` and then `/api/v2/pins` for the already
synced group. Warm reload fetched sync plus two group pin-list requests. Opening
the unjoined group also produced two pin-list requests.

[`PinGroupServiceUnfiltered`](../../flutter/lib/data/service/pin_service.dart)
watches the entire user-group stream and always schedules a remote refresh when
built. There is no shared group refresh future or recently-refreshed check.
Membership emissions can rebuild it; sync and group-screen consumers can overlap.

Keep a per-group active refresh and successful server cursor/freshness timestamp.
After a successful joined-group sync, reuse that coverage for immediate screen
opens. Watch only relevant membership state and keep cache-policy updates separate
from remote fetches. Refresh explicitly on pull-to-refresh, expiry, reconnect,
mutation, or visibility/membership changes. A boolean “already fetched” is
insufficient, especially for public unjoined groups and empty groups.

Currently `updatedAfter` comes from the oldest cached pin's client-side
`lastSynced`. An unchanged response does not advance that cursor, and a local
clock is not an authoritative server checkpoint. Introduce a server-issued
watermark with a documented tie-breaking policy so repeated empty refreshes do
not keep scanning the same interval or miss concurrent changes.

### 4. Make group media prefetch respect the existing cache — high priority

**Measured:** warm reload issued three object GETs for the joined group's profile,
small profile, and map marker. Cold home requested the small profile object twice.
[`prefetchGroupMedia`](../../flutter/lib/data/service/group_service.dart) calls
`overrideUrl` for all three images after sync. Unlike `fetchImageFromUrl`,
[`overrideUrl`](../../flutter/lib/data/repository/image_repository.dart) always
performs HTTP and bypasses the shared fetch deduplication path.

Use cache-aware URL fetching for ordinary sync hydration, with image versions to
invalidate changed bytes. Reserve forced replacement for a confirmed upload or
version change. A renewed presigned URL alone does not imply changed pixels.
Prioritize the displayed small avatar/marker; load the large group profile on
its detail screen. Preserve existing stale bytes and stable byte identity.

**Potential saving:** three object requests per unchanged joined group per reload
in this fixture, plus avoiding the observed duplicate small-avatar download.
Scaling to many groups is a source-based expectation, not measured here.

### 5. Remove thumbnail URL fan-out from group search — medium priority

**Measured:** search made two list requests (initial empty search and the entered
term), followed by three thumbnail-URL requests, three preflights, and three
object GETs. The search is already debounced by one second; it does not send a
request on every keystroke in this sequence.

[`GroupSearch`](../../flutter/lib/features/group_search/presentation/group_search.dart)
requests `withImages:false`, converts results to entities, and does not pass a
supplied URL to [`GroupTile`](../../flutter/lib/widgets/tiles/presentation/group_tile.dart).
The tile already supports `imageUrl` and a cache-aware URL provider.
Request image URLs with the result page and pass only the thumbnail URL to visible
rows. Existing `withImages:true` includes several URLs but does not require
fetching their bytes. A future thumbnail-only projection could trim the JSON.

Use a search generation token/cancellation to prevent an older in-flight query
from appending stale results after the debounce refresh. Cache recent query/page
results briefly. Retain the initial discovery list if it is intentional UX;
removing it changes behavior and is not a necessary first optimization.

### 6. Reduce web preflight overhead — medium priority

**Measured:** 80 of 206 requests were API `OPTIONS`. The
[CORS middleware](../../go-server/cmd/server/main.go) has no `MaxAge`, and the live
probe returned no `Access-Control-Max-Age` header.

Serving Flutter and `/api` behind the same origin would remove cross-origin API
preflights. If separate origins are required, configure an appropriate preflight
cache lifetime and test allowed methods/headers/origins. Max-age helps repeated
requests to the same URL; it does **not** eliminate first preflights for distinct
pin paths. It therefore cannot by itself solve per-pin fan-out. Keep API
preflights, useful API calls, and object requests separate in dashboards.

### 7. Reduce over-prefetch and queueing after removing redundant work — medium priority

**Measured:** opening Feed fetched nine images although only two like-bearing
cards mounted during that phase. [`CustomFeed`](../../flutter/lib/widgets/custom_feed/presentation/custom_feed.dart)
paginates the already-loaded local list in chunks of three; the
[active feed](../../flutter/lib/features/feed/presentation/active_group_feed.dart)
uses an invisible-item threshold of five. Both parent and child also refresh the
paging controller on pin-provider emissions.

Consolidate refresh ownership, preserve stable pin identity, and only reset when
the ordered pin list changes meaningfully. Tune lookahead by viewport and scroll
direction, cap concurrent media prefetch, and discard obsolete queued work when
leaving a screen. Keep enough lookahead to avoid placeholders; zero prefetch is
not the target.

The [HTTP client](../../flutter/lib/data/config/openapi_config.dart) defaults to
one concurrent authenticated send and a 50 ms delay before returning each
response. This adds a serialized delay floor of about three seconds across the
60 feed API calls measured here, apart from network/server time. A small bounded
concurrency increase may improve perceived loading after reducing request count;
it does not reduce count itself. Preserve token-refresh serialization and retry
safety. Image object GETs use a separate HTTP path, so they are not governed by
this API limiter.

The same client refreshes access tokens on demand after one minute, while the
[server default expiry](../../go-server/internal/config/config.go) is 15 minutes.
Initialize the API client with the login access token and refresh using its actual
expiry with a safety margin, keeping a single retry on authentication expiry.
Fresh login immediately followed by refresh was observed; prolonged token-refresh
frequency was not benchmarked. Do not assume deployments use the default expiry.

## Correctness and scope boundaries

- Client “pagination” in the feed is local. Group/user pin fetches omit page and
  size; the server's generated controller defaults size to 20. Joined-group sync
  supplied all 30 fixture pins, masking that boundary. An unjoined group with
  more than 20 pins needs explicit page traversal or a cursor. Measure a larger
  unjoined fixture before shipping pagination changes. Fewer requests caused by
  silently omitting content are not an improvement.
- Retain membership snapshots and deletion handling when changing sync. Separate
  map/offline metadata coverage from bounded feed media hydration.
- Existing image repositories already have active-request deduplication, negative
  caching, stale-byte fallback, stable-byte emission, and a persistent pin-image
  cache with an 800-item bound and 14-day TTL. Preserve these protections instead
  of introducing a parallel cache. Return-scroll success here does not prove
  behavior after expiry, logout, memory pressure, or eviction.
- Presigning is local HMAC work in the server's object service, not an extra
  storage round trip. Some group DTO construction does per-group member-count
  and best-season DB queries; batch those separately if profiling identifies
  server latency. Neither SQL count nor production latency was measured here.

## Suggested implementation order and acceptance checks

1. Reuse supplied pin URLs; cache-aware group media hydration; user metadata
   deduplication. Cover concurrent prefetch/widget consumers, expired URL fallback,
   metadata-only image updates, and account changes.
2. Deduplicate group refreshes with explicit freshness/cursors; wire search
   thumbnail URLs through. Test joined/unjoined/private/empty groups and more than
   one page of pins, including changes arriving during sync.
3. Batch likes/creator summaries, then tune preflight caching and prefetch/HTTP
   concurrency against a slower network and realistic photos.

Repeat the measured UI sequence with committed request-budget tests. Targets:
zero individual pin-image URL calls while supplied URLs remain valid; one shared
metadata read per missing creator; zero unchanged group-image downloads after
warm reload; no duplicate concurrent group refresh; zero additional requests on
immediate back-scroll within cache bounds. Batch likes should scale with pages,
not pins. Track transferred bytes, visible-image completion, cache hits, API
latency, and errors as well as request counts. Budgets must state fixture size,
cache state, viewport, elapsed time, and whether preflights are included.

Baseline verification: `mise run test` passed; the Flutter Web release Wasm build
passed; both real-browser traffic runs completed. Plain Go tests did not run
PostGIS integration tests (`TEST_DATABASE_URL` was unset). The live fixture did
exercise real migrations, authentication, groups, pin creation/reads, and RustFS.
No Go/API/database source was changed, so no generated files or DB test mutations
were needed for this report. The investigation API, RustFS, and static web server
were stopped afterward; the disposable fixture database and ignored local
credentials remain available for a follow-up run.
