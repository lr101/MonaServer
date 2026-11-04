# Centered floating navigation

All five compact destinations share one 64 px capsule, centered with a 12 px
bottom gap and a maximum width of 360 px. The area outside the capsule remains
clear and passes pointer input to the page. There is no Scaffold footer.

The selected slot expands by up to 16 px, its icon grows from 24 to 28 px, and
the selection pill slides over 320 ms. Destination pages also slide. Reduced
motion selects immediately. Visited pages retain state, and camera activation
continues to follow the selected destination. The keyboard hides the dock.

Scrollable content extends behind the dock, with trailing clearance so the
last item can scroll above it. Map tiles remain full bleed; rankings, location,
and attribution sit above the dock. Wide layouts retain the navigation rail.
Icons have accessible destination names, selection semantics, tooltips, and
at least 48 px targets at supported narrow phone widths.

## Rendered evidence

- [Recorded transitions](floating-navigation.gif), trimmed from the actual
  mobile browser recording after sign-in.

- [Map, dark](map-dark.png) and [Groups, dark](groups-dark.png).
- [320 px light layout](groups-320-light.png).
- [Groups](floating-dock-groups.png), [Feed](floating-dock-feed.png),
  [Profile](floating-dock-profile.png), [Map](floating-dock-map.png), and
  [expanded rankings](floating-dock-rankings-expanded.png) from the mobile
  Playwright journey.

The source and rendered review accepted the shared capsule, motion, retained
state, touch targets, and map spacing. A later screenshot check corrected the
feed's clipped viewport: bottom clearance belongs to scroll content, rather
than a bottom SafeArea that leaves a blank strip above the dock.

## Verification

Local verification uses PostgreSQL/PostGIS, RustFS on loopback port 9100, the
Go API on 8081, and a connected Flutter Chrome debug session on 4173. Sign-in
uses the actual password form. Browser camera and geolocation are synthetic;
uploads reach the real disposable local API and are deleted afterward.

Navigation widget checks cover centering, transparent pointer pass-through,
48 px targets, selection movement and expansion, page movement, draft
retention, rapid selection, safe bottom insets, keyboard visibility, reduced
motion, and the final group row clearing the dock. Mobile browser checks cover
all destinations, consistent dock geometry, rotation, appearance, back,
photo capture/save, group actions/settings/achievements, and expanded rankings.

These checks establish shared Flutter Web behavior. They do not establish
TalkBack, predictive back, Android system bars, real camera behavior, or native
device lifecycle behavior.

Final results: `flutter test --no-pub` passed 596 tests, with two existing
skips. Focused analysis of navigation, map spacing, feed/list clearance,
achievement clearance, and navigation tests reported no issues. All five
`android-web.spec.ts` Playwright journeys passed together against the debug
server. A connected hot reload was also confirmed during implementation.
