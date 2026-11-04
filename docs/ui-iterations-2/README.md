# UI iterations 11–20

Ten additional concepts were implemented in the running Flutter Web debug app, captured after hot reload/restart, and independently reviewed by ten fresh GPT-6.1-sol agents. Six are retained and four are reverted after the user requested reverting rounds 17 and 19. The professional icon cleanup is a prerequisite, not an extra iteration.

The newly added Settings emoji, Rankings trophy, and rail sparkle were replaced with standard Material icons/plain branding. The earlier screenshot archive remains historical evidence. Warm accents, Signika typography, and content imagery remain part of the design.

Open [the screenshot gallery](index.html). Rounds 17 and 19 were later reverted at user request. Their screenshots retain the rejected candidates. Each screenshot records the app at that experiment's capture time; later decisions can supersede visible earlier candidates. The final source includes only retained changes.

| Round | Concept | Decision | Review rationale | Screenshot |
| --- | --- | --- | --- | --- |
| 11 | Factual group-count badge | Kept | Reviewer found the count compact, aligned and informative without competing with actions. | [View](11-group-count.png) |
| 12 | Explained group action cards | Kept | Reviewer found both paths clearer and the additional mobile space justified. | [View](12-action-cards.png) |
| 13 | Compact dock with selected label only | Reverted | Saving 8 pixels did not justify removing destination labels and reducing discoverability. | [View](13-compact-dock.png) |
| 14 | Default Material scope segments | Reverted | Reviewer found the default selected fill less obvious than the existing strong selected pill. | [View](14-material-segments.png) |
| 15 | Labeled keyboard-accessible group filter | Kept | Reviewer found the label discoverable, professional and comfortably fitted in the header. | [View](15-labeled-filter.png) |
| 16 | Outlined feed-item surface | Kept | Reviewer found the subtle outline grouped photo and metadata without distracting from content. | [View](16-outlined-feed.png) |
| 17 | Compact Map/Photo toggle | Reverted | Reverted at user request: restore the feed Map/Photo thumbnail selector. | [View](17-compact-map-button.png) |
| 18 | Flat settings sections | Kept | Reviewer found stronger scanning hierarchy and less visual weight while preserving grouped rows. | [View](18-flat-settings.png) |
| 19 | Labeled current-location action | Reverted | Reverted at user request: restore the icon-only current-location action. | [View](19-location-label.png) |
| 20 | Collapsible desktop navigation rail | Kept | Reviewer found reclaimed width useful while labels remained clear. Toggle already includes explicit Collapse/Expand tooltips. | [View](20-collapsible-rail.png) |

Round 20 also includes the [collapsed rail after interaction](20-rail-collapsed.png). Professional baselines: [Map](baseline-map.png), [Settings](baseline-settings.png). Final retained-state checks: [320 px Groups](final-groups-narrow.png), [dark Settings](final-settings-dark.png).

## Verification

Latest follow-up after reverting rounds 17 and 19: **8 feed/detail visual tests passed**, **1 Playwright touch-navigation flow passed** (including login and switching the restored Map/Photo thumbnail both ways), and focused analysis of the two affected Dart files found **no issues**. Fresh captures: [restored feed selector](current-preview/feed.png), [icon-only location action](current-preview/map.png). The live debug app was hot reloaded on port 4173. T3 shared-browser preview was unavailable because Chrome could not start its sandbox as root; Playwright captures provide the rendered evidence.

Earlier full iteration verification, before those user-requested reversions:

- Playwright: **2 passed** against the hot-reload debug server on port 4173. Checks cover real local login, Find/Create group routes, all five destinations, Map/Photo switching, dark Settings, rotation with retained form/draft state, browser back, camera capture, and a successful pin upload to the local API. The uploaded test pin is deleted afterward.
- Final full Flutter suite: **573 passed, 2 skipped**, including the four additional Rankings and search-disposal regressions.
- Rankings regression: reproduced the fixed-height overflow at 200% text, then **4 tests passed** after measuring header height and updating map offsets/sheet extent. Covers 320 × 150 and 320 × 700.
- Group-search lifecycle: **2 tests passed** for successful/failed responses arriving after the route is disposed. The initial browser trace identified the missing disposal guard; the fixed browser rerun passed without uncaught errors.
- Focused static analysis of all 13 changed Dart source/test files: **no issues found**. Repository-wide analysis reports **91 pre-existing diagnostics** (2 warnings outside these iteration files and 89 informational items).
- Light/dark feed/details goldens updated and inspected; narrow/wide feed metadata at 200% text passed. Rail collapse/expand preserves the current draft; short-window and status-bar padding tests passed.
- Local services used: Flutter Chrome debug, Go API on 8081, native PostgreSQL/PostGIS on 5432, RustFS on 9100. One earlier upload run hit API 500 while RustFS was unavailable; storage was restarted and the clean retry passed. The earlier navigation run exposed the group-search disposal error now covered by regression tests.
- This is debug/browser validation, not a release/offline build or Android device run. Screenshots establish the captured visual states; browser checks do not establish native TalkBack, Android system bars, predictive back, or device lifecycle behavior.

All review agents inspected rendered screenshots. A separate read-only review checked retained source changes for functional and accessibility issues. Its large-text Rankings finding was reproduced and fixed; a fresh focused review found no remaining material issue in that fix or the group-search lifecycle guard. Fixture photos and avatars can appear black; this is test content and does not establish real-media quality.

