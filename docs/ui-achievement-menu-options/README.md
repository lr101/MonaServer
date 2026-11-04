# Five more achievement and group-menu options

Open [the screenshot gallery](index.html) to compare all five treatments in each family, including personal achievements and the relocated group-action panels. These are captures of the real Flutter debug app after local password sign-in.

> Follow-up: the user moved Group settings to the top-right toolbar and Share into the settings page. See [current profile alignment](../ui-profile-alignment/README.md). The comparison screenshots below are historical.

## Kept after this comparison

- **Achievements: option 2, compact goals.** Current milestones are grouped as Ready to collect, Next up and Collected. Each row identifies the category, exact count and reward. Tap a row for requirements and an explicit Collect reward action. The visible All tiers entry retains future and collected milestones; at large text it becomes a named icon button.
- **Groups: option 3, Group settings.** Share stays beside the stats. A fourth tab opens labeled admin Edit, Report and Leave rows. Admin management is separated from the membership/safety actions. Long names keep the full toolbar width. Existing invite permissions, native sharing/clipboard fallback, report/edit destinations and Leave confirmation/recovery remain.

See [research and sources](research.md), [independent reviews](review.md), and [option metadata](options.json). The rejected implementations and temporary selectors were removed; their screenshots remain for comparison.

| Option | Achievements | Group actions |
| --- | --- | --- |
| 1 | Badge collection | Direct icon strip |
| 2 | **Compact goals — kept** | Contextual information-sheet split |
| 3 | Expandable categories | **Dedicated Group settings tab — kept** |
| 4 | Focused next goal | Information hub |
| 5 | Tier ladder | Split action rows |

The visual review ranked achievements 2 > 3 > 4 > 1 > 5 and group actions 3 > 2 > 5 > 4 > 1. The retained designs were refined with category/count context, visible catalog discovery and explicit action semantics.

## Evidence

All comparison captures use 360×740 logical pixels and dark appearance. The same disposable activated account is used across variants. Achievement captures use the same joined group, with three ready rewards; group-menu captures use a separate owned group with a long name and description. Black avatars are existing fixture content. The owned group's image is an existing app asset.

- `achievements-1.png` through `achievements-5.png`: group achievement trials.
- `personal-1.png` through `personal-5.png`: personal achievement trials.
- `group-1.png` through `group-5.png`: group profile/action placements.
- `group-2-info.png`, `group-3-settings.png`, `group-4-info.png`: relocated actions.
- `final-achievements-360.png`: refined retained group achievements, dark.
- `final-personal-320.png`: refined retained personal achievements, light.
- `final-settings-800.png`: retained settings at a wider 800 px window, light.
- `final-settings-320.png`: refined retained admin settings and long name, light.

## Verification workflow

Local PostGIS/PostgreSQL, the Go test API on `127.0.0.1:8081`, RustFS on `127.0.0.1:9100`, and a connected Flutter Chrome debug device on `127.0.0.1:4173` were used. Flutter's own tab was captured over CDP; separate Playwright tests used a Pixel touch browser and actual form sign-in. Connected hot reload was confirmed after reconnecting, including a 763 ms reload.

The focused regressions cover admin/member/visitor action visibility, edit/report arguments, native Share and clipboard fallback, Leave root-route/prior-route/pending-route behavior through the new action row, membership removal while Settings is selected, catalog future/collected tiers and ordering, personal/group claims, and 320 px / 200% text layout. The report action now passes its group-specific issue type using the router payload expected by the report form, rather than opening the generic issue selector. Light-theme milestone accents use the on-surface orange role for legibility. Browser verification also identified and fixed an actionable semantic-role defect: milestone rows must expose a button, not inherit their progress indicator's role.

This UI-only preview uses the local hot-reload debug app. Browser evidence does not establish native Android TalkBack, predictive back, system bars, device lifecycle, or release/offline behavior. No Android device/emulator checks are claimed.

Final local checks: `flutter test --no-pub --concurrency=2` completed with **580 passed, 2 skipped**. Focused analysis of the affected source/test files reported **no issues**. `git diff --check` passed. The initial complete run found one stale personal-carousel expectation; it was updated to exercise explicit collection and the tier catalog, and the full suite was rerun cleanly.

Both relevant Playwright journeys passed against the final app: compact group actions/catalog/details/320 px resize (27.3 s) and admin Edit, group-specific Report, a real reward claim, visible collected state, and cleanup of the two temporary pins/group (see browser artifacts). No uncaught browser errors were reported. [Collected reward evidence](final-collected.png) shows the real post-claim catalog state.
