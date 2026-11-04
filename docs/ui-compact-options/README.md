# Small-screen layout comparison

The supplied phone screenshots showed that explanatory action cards and repeated labels crowded content. This comparison implements three real group-header layouts and three achievement layouts, captures each in the running authenticated Flutter Web app at **360 × 740**, and asks an independent subagent to select or reject them.

**Selected: Header B and Achievements A.** The four unused prototypes were removed from the implementation. Open [the six-option gallery](index.html).

| Option | Decision | Reviewer rationale | Evidence |
| --- | --- | --- | --- |
| Header A: consolidated menu | Rejected | The menu still consumes title width and makes Share a two-step action. | [Screen](header-a-menu.png) · [Actions or personal view](header-a-actions.png) |
| Header B: actions beside stats | Kept | Gives the title full width while Share remains immediate and other actions stay in a familiar menu. | [Screen](header-b-actions-row.png) · [Actions or personal view](header-b-actions.png) |
| Header C: avatar action sheet | Rejected | An avatar-attached button suggests an avatar action; the sheet adds a modal step. | [Screen](header-c-avatar-sheet.png) · [Actions or personal view](header-c-actions.png) |
| Achievements A: prioritized tracks | Kept | Shows the current goal in each category without a full catalog. Refined with an explicit All tiers entry. | [Screen](achievements-a-tracks.png) · [Actions or personal view](personal-a-tracks.png) |
| Achievements B: category picker | Rejected | Opening a category into every tier recreates a long, card-heavy catalog. | [Screen](achievements-b-categories.png) · [Actions or personal view](personal-b-categories.png) |
| Achievements C: status filters | Rejected | The icon-only statuses are less self-explanatory and separate goals from their category context. | [Screen](achievements-c-status.png) · [Actions or personal view](personal-c-status.png) |

## Retained refinements

- Find/Create are direct toolbar icons with tooltips; the large description cards are gone. The group filter and map scope also use compact icons with accessible names and selection state.
- Group titles get the full toolbar width and a measured height for up to three lines. Share and the original menu sit next to the stats. Membership/admin checks, native sharing/clipboard fallback, report, edit, and leave behavior are preserved. Leave confirmation now names its Cancel action.
- Group tabs use icons with full tooltips. The description is a two-line teaser with a 48-pixel information target; the information sheet retains the full description, external link, and best-season data.
- Personal/group achievements share a presentation-only track browser. Ready rewards lead, followed by closest goals, then collected tracks. Current-tier carousels keep the overview compact. **All tiers** exposes future and collected rewards; full requirements and collection remain available through milestone details.
- At large text sizes, current milestone cards use intrinsic height; the catalog remains accessible. Toolbar/profile height and stat columns respond to text scaling.
- The non-map dock floats over content and hides text. Tooltips and tab semantics remain. Camera now uses a standard camera icon. The map keeps its dock integrated with the rankings sheet. A regression check ensures the last list action can scroll clear of the floating dock.

Final rendered evidence: [320 px light group header](final-header-320.png), [refined dark achievements](final-achievements-360.png), [compact Groups with floating dock](compact-groups-floating-dock.png), [compact map controls](compact-map-controls.png), [personal achievements at 320 px](final-personal-320.png).

## Verification

- Final full Flutter run: **577 passed, 2 skipped**. Includes share/native/clipboard fallback, role-dependent group actions, large text at 320 px, reward details/collection, track ordering and complete catalog access, draft retention and scrolling clear of the floating dock.
- Focused analysis of **19 changed Dart files: no issues**; the final three refined layout files were also analyzed cleanly.
- Playwright: **all three journeys passed across focused runs**: login/touch navigation/rotation/theme/back; camera capture, draft rotation and real local API upload/delete; group Share/menu availability, canceling Leave, switching tabs, catalog browsing, milestone details and a 320 px resize.
- Browser verification caught the All tiers action merging into surrounding semantics; a separate button node fixed it and the complete group journey passed. Two stale selectors were adapted to the existing accessible menu-item and field/hint names.
- The first full run found a stale text-based Pins-tab finder; it now uses the icon tooltip, and the subsequent complete suite passed.
- Independent rendered review selected B/A; a separate read-only code review found no material regressions and independently passed the navigation/catalog tests.
- Services: connected Flutter Chrome debug on 4173, local Go API on 8081, native PostgreSQL/PostGIS on 5432 and RustFS on 9100. Phone-accessible preview handoff uses a fresh isolated database/API/storage/email-capture stack through the preview skill.
 Screenshots are live debug-Web captures with the same local fixture account and data. Black media areas are fixture content. No Android device or native screen-reader verification is inferred from browser evidence.

Phone-accessible preview: https://web-compact-ui-b5fae4a9.dev.dell.lr-projects.de/ (one-time admission link supplied separately; never stored here). Web/API HTTPS returned 200 and the public worker hash matches the current bundle. This preview uses a JavaScript CanvasKit build at optimization level 1 to fit the environment; it does not establish a WebAssembly release/offline check. The completed headless debug verification session was then stopped to free memory; public preview services remain running.
