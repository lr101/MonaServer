# Android UI modernization checklist

This checklist tracks work against [Android design guidance](https://developer.android.com/design/ui/mobile). Unchecked items need implementation or device verification; they are not claims of defects.

Requested verification scope: use the Web browser, including an Android mobile
profile with touch input, for Android-facing shared behavior. Browser back,
viewport/rotation changes, accessibility-tree inspection and browser theme or
offline changes are proxies for the corresponding native behavior. They do
not establish TalkBack operation, Android system-bar rendering, predictive-back
animation or native process lifecycle behavior; those native claims remain
outside this requested verification method.

### Android-facing browser checks

`E2E_ANDROID_WEB=1` runs `flutter/e2e/tests/android-web.spec.ts` with a Pixel 7
browser profile, touch input, synthetic camera and browser geolocation. The
latest complete run passed both journeys:

- [x] Sign in through the form and touch all five destinations; verify selected state.
- [x] Change appearance, open Edit profile, rotate the viewport and retain form contents.
- [x] Return through Settings with browser back, preserving the Profile destination.
- [x] Rotate to a short, wide viewport and keep the rail destination reachable.
- [x] Capture a synthetic photo, preserve its draft title through rotation and approve it.
- [x] Verify the upload reaches the local API with the expected title and appears in the feed.
- [x] Delete the disposable uploaded pin after verification.

Screenshots cover the landscape form, landscape rail, approval draft and saved
feed/XP feedback. These passing browser checks complement the broader coverage
items below; they do not certify native Android behavior.
The landscape form capture exposed a clipped profile-photo edit badge; removing
its outward offset restored the full badge. A fresh touch-navigation run and
landscape screenshot verified that correction, and the 48 dp target test passed.

## Contrast and components
- [x] Give shared enabled text fields a visible outline in both themes.
- [ ] Check text (4.5:1) and non-text controls (3:1) against their actual backgrounds in both themes, including disabled and error states.
- [ ] Check settings, form buttons, labels, focus and validation states for consistent theme roles.
- [ ] Verify touch targets are at least 48 dp and text remains usable at large font scales.

## Navigation and adaptive layouts
- [ ] Verify all five destinations, selection, state preservation and Android back behavior.
- [x] Use a navigation rail at suitable wider window sizes; retain the bottom bar for compact windows. The 600 logical-pixel breakpoint, resize state preservation, short windows and status-bar padding have widget coverage; phone and wide Web layouts have rendered evidence. Android behavior is tracked separately below.
- [ ] Design and test map/detail and feed layouts on tablets, foldables and resized windows.

## Edge-to-edge
- [ ] Test Android 15+ with gesture and three-button navigation; check system bar contrast and insets.
- [ ] Check map controls, attribution, camera controls, sheets, keyboard and notices for overlap with system bars and gestures.

## Map and photo accessibility
- [x] Label the group and personal map scope controls; test switching and narrow, large-text layout.
- [ ] Audit TalkBack labels, reading order and decorative images on the map, feed, pin details and camera.
- [ ] Provide accessible alternatives for gesture-only actions and distinguish present/gone without color alone.
- [ ] Exercise capture, selection and save with TalkBack and large text.

## Actions and feedback
- [ ] Establish a clear primary action on forms and capture; distinguish secondary and destructive actions.
- [ ] Check loading, empty, offline, error and success states and ensure recovery actions remain visible.
- [ ] Check sheet sizing and overlays in both themes and at narrow widths.

## Android system behavior
- [ ] Test predictive back, keyboard navigation and focus, system theme changes and lifecycle resume.
- [ ] Test rotation, resizing and folding without losing user input or task state.
- [ ] Run the map → artwork → camera → save journey, a form and Settings on Android in both themes.

## Current verification limits

The latest [professional UI iteration review](ui-iterations-2/README.md) replaces
new decorative emoji with standard Material icons and records rounds 11–20.
The final browser rerun passed both touch/navigation and capture/upload flows.
A large-text Rankings header overflow and a late group-search response after
disposal were reproduced and fixed. The remaining native Android checkboxes
retain their original scope; browser results do not close those device checks.

Earlier verification history follows:

Latest continuation: a red/green regression test confirmed and fixed the
image-edit target from 44 to 48 dp. Focused tests pass for large-text settings
actions, ranking tap/keyboard interaction, adaptive navigation, and additional
surface/container/error contrast pairs in both themes. The rankings header
now uses a standard Material leaderboard icon with decorative semantics excluded. Feed photo
navigation now has labeled 48 dp previous/next buttons as well as swiping;
widget interaction and light/dark rendered goldens pass. The filter glyph is
larger, and location metadata uses upright 14-pixel text after screenshot
review feedback. Fresh Web captures passed and the 6.1-sol recheck found no
definite visible defect in those two changes while confirming that the app's
playful identity remains intact. The full Flutter suite passed 569 tests with
2 skipped after updating the old expectation that photo-navigation buttons
were absent.

The latest Web checks passed login/capture, auth target sizes, capture/approval
and return, and camera-denial recovery. Password keyboard navigation and
Settings/hidden-user empty state passed separately after timing out during a
resource-contended run. These are sampled states, not a complete audit of every
screen. The requested screenshot reviewer confirmed the map's visible controls
do not overlap in the captured state and that the playful identity is retained.

Android tooling (`adb` and the emulator) is not installed in this environment.
The user explicitly requested browser verification for Android-facing features;
native-tool availability is therefore not a blocker for that scoped work. Unresolved group
editing and restored-session browser failures below remain open; they are not
waived by passing widget or screenshot checks.

The shared input outline and adaptive navigation have focused widget coverage,
including resize state preservation, short windows and status-bar padding. A
phone-sized Flutter Web screenshot was reviewed, but the Android device checks
above remain open. The 2026-11-02 local web E2E run failed in sign-in focus and
reported a null-check error during group editing. An isolated focus retry showed the input receives focus before the Flutter semantics node takes it; its results do not establish
that those failures were caused by these changes. On a subsequent local run,
the group-edit browser test reached its image refresh assertions but failed on
an inactive Flutter focus-scope assertion. Its cause remains under investigation.
On a fresh retry with the existing local RustFS instance, the image refresh
checks again completed but the same assertion failed the browser test. The
API, PostgreSQL, RustFS and web preview were running for that retry; the
assertion's cause has not been isolated.
No Android emulator or device was used, as requested.

On 2026-11-03, Playwright captured debug-web login and all five primary
destinations at 450 × 900. A 6.1-sol screenshot review identified a hard-to-read
feed location and an ambiguous camera shutter; subsequent screenshots showed
the larger location and centered camera icon, and the reviewer found both
legible at that size. Screenshots do not establish touch, screen-reader, or
Android system behavior. A later screenshot review confirmed that outlined
avatar boundaries are visible over dark media. A dark backing and brighter
carousel dots were reviewed as visible on the captured photo, though their
small size and contrast across other imagery remain open.

The debug-web test run encountered the same group-edit focus-scope assertion.
Its stack goes through Flutter's route semantics and focus traversal; the
application-level trigger remains unproven. The run also suffered a RustFS
outage and concurrent Playwright runs sharing their artifact directory, so
later failures from that run cannot be treated as conclusive. A local no-op
offline worker was used for debug-server tests because the actual offline worker
is generated only for the release build; this does not test offline behavior.
A clean login/navigation rerun passed 10 tests, failed 3 and skipped 1. One
camera test had stale expectations for the current 3:4 crop; after updating
them and allowing the location screen's duplicated Back accessible name, the
camera capture and return journey passed. The reopened-tab debug startup and
session-sync failures need investigation. Flutter's Chrome-connected debug
session successfully performed hot reload on port 4174.
The web frame now expands on wider windows, with a bounded feed card; a wide
profile test and screenshot review cover those sampled states. The wider
map/detail and feed task layouts remain open. The opt-in image stress suite
passed its first six checks in one run; URL-batch timing failed once and passed
on retry, the wide profile passed after adapting the rail locator, and the
101-photo swipe test failed to reach its expected photo. The final image-detail
return check passed separately.
