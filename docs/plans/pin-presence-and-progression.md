# Pin presence, photo history, and progression

## Product decisions

- The core loop is finding an existing pin, contributing a newer photo, and
  confirming whether the work is still there. These are actions on the same pin,
  not ways to create duplicates.
- A gone pin stays in the database, retains its photos, and stays on the map as
  a grey marker with a `Gone` label. Deletion remains a separate creator/admin
  moderation operation and removes it from normal results.
- User XP and achievements appear on the profile and in the compact map status
  bar. Achievements have their own profile tab; a successful claim triggers the
  celebration. XP gains and level ups get subtle feedback.
- Groups earn XP and achievements. Their rewards unlock cosmetic choices for
  group markers, group profile presentation, and map display. Public/private
  access remains a normal setting, never an unlock.
- Existing achievement claims are re-evaluated against new rules. Previously
  awarded XP remains. A revoked claim cannot stay selected as a profile badge,
  and reclaiming the same milestone cannot pay its XP twice.

## 1. Nearby pin experience

### User flow

1. In a foreground map/camera session with location permission, show a small
   `Pin nearby` cue when an accessible pin is within 75 m and the location
   estimate is accurate enough to make that cue credible (proposed: reported
   accuracy <= 50 m). Show the nearest pin's group marker, distance, and photo
   thumbnail. Never block the map or camera. Tapping opens its detail sheet.
2. The detail sheet has `Find it`, `Add photo`, and `Check status` actions.
   `Find it` centers the map on the pin, shows the original and latest photo,
   updates distance as the user moves, and offers an external directions action.
   A gone pin is explicitly described as a historical find.
3. Keep the cue in the app foreground. Deduplicate it by pin and session, hide it
   while a sheet is open, and allow dismissing it for the day. Give no cue for
   pins the user cannot see. No background location or push notification is
   needed for this release.
4. Nearby discovery queries the server for a small geographic radius so public
   pins outside the locally selected groups can still be found. Limit results,
   apply existing group visibility rules, and index the geographic query.

The existing marker calculates a 50 m distance, but markers are created with
their animation off and the current location stream moves in 100 m steps.
Neither is suitable as the trigger for this cue. Use a single nearby controller
that consumes location updates and a bounded server response. Keep the normal
map stream and marker image providers stable so metadata updates do not reload
images or flicker markers.

### API and data

- Add `GET /api/v2/pins/nearby?lat=&lon=&radius=` with a bounded radius and
  result size. Return pin ID, group ID, coordinates, current presence state,
  latest thumbnail reference, and server-calculated distance. Enforce public
  group or membership visibility in SQL, as existing pin search does.
- Use PostGIS `ST_DWithin` on the pin point with a spatial index. Exclude hard
  deleted pins; include gone pins so they can be intentionally found again.
- Reject invalid coordinates and oversized radius. This endpoint is read-only
  and uses the existing authenticated user route group.

## 2. Photos and presence on an existing pin

### User flow

- A pin detail view becomes a timeline: original photo, later photos ordered by
  observation date, contributor names, and status events. `Add photo` uses the
  current camera/picker flow, previews the image, and attaches it to the same
  pin ID. The original photo remains available.
- `Still here` and `Gone` are separate actions under `Check status`. Show the
  current state and last confirmed date. A user can optionally attach a fresh
  photo to either check; an added photo also offers a `Still here` check.
- First conflicting report yields `Needs checking`, not an immediate flip.
  Proposed initial rule: two independent recent reports agree before changing
  the public state, while a group admin can resolve a conflict. A photo-backed
  `Still here` report can restore a gone pin after review under the same rule.
  Show who and when in the timeline so the decision can be understood.
- Show a gone pin's original/latest photos in full color in its detail view.
  Desaturate its map marker and map thumbnail, add a `Gone` label, and provide
  a map filter for `Here`, `Needs checking`, and `Gone`. Color is not the only
  status indicator. Keep gone pins out of the default active feed/ranking counts
  unless the user selects historical content.

### Storage and API

- Add a forward migration with `pin_photos` (ID, pin ID, contributor ID,
  observed/created timestamps, immutable object key, moderation state) and
  `pin_presence_reports` (ID, pin ID, reporter ID, `here|gone`, observed time,
  optional photo ID, accuracy, creation time, idempotency key). Add a materialized
  presence state and last-confirmed time to `pins`, or derive them with a
  transactionally maintained summary. Backfill each existing pin's image as its
  first photo without copying the object if its current key can be reused.
- Add `GET/POST /api/v2/pins/{id}/photos`, `GET/POST
  /api/v2/pins/{id}/presence`, and an admin/group-admin resolution operation.
  Extend pin read/sync DTOs with presence state, last confirmation, photo count,
  and latest photo reference. Preserve existing field names and old single-image
  endpoints for older clients.
- Mutations check authentication, group access, image limits, and location
  evidence on the server. Validate proximity using submitted coordinates and
  accuracy against the stored pin location; do not trust a client-provided
  `nearby` boolean. Allow an explicit admin moderation path without proximity.
  Use idempotency keys and one effective report per user per pin per review
  window. New photo objects use immutable keys; removal/moderation never
  overwrites the original.
- Keep `is_deleted` and deletion logs for actual deletion only. Gone-state
  changes update `pins.update_date` so sync clients receive the new state.
  Do not emit a deleted ID when a pin becomes gone.
- Add a Drift migration for pin presence fields and photo metadata caching.
  Update the pin repository, group sync, map markers, gallery, and detail page.
  Old clients still see the original image and pin; they simply lack the new
  status/timeline UI.

## 3. User levels and achievements

- Keep the previously agreed cumulative user level thresholds: 0, 25, 75,
  150, 275, 450, 700, 1,050, 1,550, 2,250, 3,250, 4,750, 7,000, 10,000,
  14,000 XP. Existing total XP is retained and displayed level is recalculated.
- Keep 5 XP for creating a pin and 10 XP for creating a group. Award 20, 50,
  or 100 XP for claimed easy, medium, or hard milestones. A plain repeated
  presence tap gives no XP; an accepted, independent photo update or useful
  presence verification can earn a bounded, once-per-window contribution reward.
  Put every award in a ledger with a unique event key to prevent retries and
  status flipping from farming XP.
- Add several milestones in sticks, places, groups, likes given, and likes
  received. Define `likes received` by joining likes to the creator's pins;
  retain `likes given` as its own track. Achievement definitions, thresholds,
  descriptions, and XP reward amounts come from the server. Version them so a
  rule change can re-evaluate claims without rewriting historical award events.
- Add a profile XP card and compact map level indicator. The profile's
  Achievements tab shows ready-to-claim, earned, and in-progress milestones
  with their requirements. Claim success triggers one short reveal; subsequent
  reads do not replay it. Respect reduced-motion settings.

## 4. Group levels, achievements, and cosmetic rewards

### Earning and milestones

- Group XP is a ledger of distinct accepted contributions, independent of
  user XP. Initial values to validate against seed data: 5 group XP per new
  pin, 3 per accepted photo update by another member, and 2 per independent
  accepted presence check no more than once per pin per 90 days. Award group
  achievement claims 20/50/100 group XP by difficulty. A hard deletion for
  abuse can reverse only its associated unearned ledger entries.
- Begin group level thresholds at twice the user ladder: 0, 50, 150, 300,
  550, 900, 1,400, 2,100, 3,100, 4,500, 6,500, 9,500, 14,000, 20,000,
  28,000 group XP. This gives a small group visible early progress while larger
  groups have long-term goals. Simulate against existing group distributions
  before release and adjust the table once before migration.
- Group achievement tracks: active pins (10/50/200), distinct pins with a
  later photo from another member (5/25/100), confirmed presence checks
  (10/50/200), and distinct mapped localities represented (3/10/25). Only
  eligible visible/accepted contributions count. Store definition versions and
  claim history; the group admin can claim a ready reward. Members see progress.

### Unlocks and UI

- Unlock a small catalog of cosmetics by level and achievement: marker frame,
  marker accent, group profile border, group banner accent, and a group badge
  shown on its map card/profile. Example pacing: level 2 unlocks an accent;
  level 4 a marker frame; level 7 a profile border; level 10 a banner accent.
  Individual achievements unlock themed variants. The current group pin image
  stays the center of the marker; cosmetics are rendered around it.
- Add `group_xp`, group achievement progress/claims, unlock entitlements, and
  selected cosmetics to server data. Return entitlements from an endpoint and
  validate every selection server-side. Only a group admin changes cosmetics;
  all members can view progress. Do not tie group public/private visibility,
  discoverability, image access, or membership permissions to a level.
- Extend the existing group overview with a level progress card and an
  Achievements tab. Add a `Customize appearance` action in group edit with
  previews, locked states that show how to earn them, and one-tap selection.
  Use existing surface colors, orange accent, rounded cards, and group imagery.
  Cosmetic assets should be code-native Flutter decoration/vector where possible,
  rather than a new image asset for every color/frame combination.

## Delivery order and acceptance checks

1. **Foundation:** contract and forward migrations; generated Go/Dart clients;
   photo, presence, reward ledger, and group entitlement queries. Prove older
   pin reads, access rules, and deletion behavior remain compatible.
2. **Nearby and pin history:** bounded geographic query; foreground cue; detail
   sheet, photo timeline, presence reports, conflict resolution; grey gone
   markers and filters. Verify distance/accuracy boundaries, private groups,
   stale/offline cache, duplicate submissions, and concurrent reports.
3. **User progression:** server-owned level/achievement definitions, historical
   XP reconciliation, profile/map displays, claim animation, and action refresh.
   Verify every XP award is idempotent and a revoked old claim never erases XP.
4. **Group progression and cosmetics:** group ledger, milestones, unlocks,
   server validation, group UI, and appearance previews. Verify unauthorized
   selection fails and public/private visibility is unaffected by rewards.
5. **Release checks:** run Go vet and tests with a disposable PostGIS database
   serially; regenerate API/sqlc/OpenAPI outputs; run Flutter analyze, widget
   tests, web build, and browser flow against the local stack. Exercise nearby
   discovery, here/gone transitions, grey markers, history, user/group XP,
   claims, reduced motion, and old-client response compatibility.

The first UI slice should be the pin detail/timeline and grey state. The
nearby cue then has a complete destination; progression follows real accepted
actions rather than being presented before those actions work.
