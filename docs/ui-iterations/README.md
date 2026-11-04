# Ten UI experiments

Each candidate was implemented in the running Flutter Web app, captured, and reviewed by a screenshot-only review agent. Kept experiments accumulate; rejected changes were restored from file snapshots without disturbing earlier work. Screenshots contain local fixture data and a synthetic camera preview.

| Iteration | Concept | Decision | Reason |
| --- | --- | --- | --- |
| 1 | [Inset floating navigation](01-floating-nav.png) | Reverted | Exposed black footer and competing rounded surfaces disrupted the map and rankings composition. |
| 2 | [Floating dock on a themed backdrop](02-anchored-dock.png) | Kept | Dock is clean and labels remain visible. Reviewer liked the dock but alleged header clipping; direct inspection did not reproduce that claim. |
| 3 | [Icon-and-label map scopes](03-scope-icons.png) | Kept | Reviewer found the group/person glyphs clearer without crowding the labels. |
| 4 | [Rankings title and region hierarchy](04-ranking-hierarchy.png) | Kept | Reviewer found the title/status separation easier to scan, with the trophy retained. |
| 5 | [Visible group-discovery shortcuts](05-group-shortcuts.png) | Kept | Reviewer found the primary Find groups and secondary Create group actions clear and discoverable. |
| 6 | [Clearer tappable group rows](06-group-affordance.png) | Kept | Reviewer preferred stronger titles, upright secondary text and a directional chevron. |
| 7 | [Playful settings landmarks](07-settings-personality.png) | Kept | Reviewer found compact section emojis improved scanning and matched the requested personality. |
| 8 | [Labeled map/photo inset toggle](08-labeled-map-preview.png) | Kept | Reviewer found the compact label clarified the toggle without materially covering content. |
| 9 | [Grouped camera-control tray](09-camera-tray.png) | Reverted | Reviewer found the extra tray competed with the shutter and bottom navigation without making the small actions clearer. |
| 10 | [Expanded wide-window navigation rail](10-expanded-rail.png) | Kept | Reviewer found inline labels and the Stick-It sparkle landmark made wide-screen wayfinding immediately scannable. |

The review for iteration 2 liked the dock but alleged header clipping. Direct inspection of the original screenshot did not reproduce that claim; the themed dock was retained on that basis. The missing-photo/black avatar fixture imagery is not evidence of a production loading defect.

Browser screenshots establish visible composition for these captured states. They do not establish native Android system behavior.

## Verification

- Full Flutter suite: 569 passed, 2 skipped.
- Focused navigation, scope, rankings, camera, feed/details, group-row and Settings checks: passed.
- Touch-browser navigation and new group shortcuts, plus camera/save journey: both passed after restoring the stopped local object store.
- Analysis of the retained UI files and whitespace checks: passed.
- A large-text overflow in the new inset label was caught and corrected with flexible text.

The local web app, API, PostgreSQL and RustFS were used for the browser verification. Camera imagery is synthetic; no native Android claim is implied.
