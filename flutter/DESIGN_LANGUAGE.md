# Stick-It Flutter design language

This is the working reference for Flutter UI changes and reviews. It describes
the visual system visible in the app on 27 September 2026 and separates stable
choices from inconsistencies that should not be copied. It is not a claim that
every existing screen conforms. Update this document when a product design
decision changes; the implemented values remain in the linked source files.

For rendered examples and known exceptions, see the [visual review](../docs/UI_VISUAL_REVIEW.md)
and [achievements and pin review](../docs/PROGRESSION_UX_REVIEW.md). Those reports
are observations and proposals, not a replacement for current source or a
blanket requirement to implement every suggestion.

## Character and hierarchy

Stick-It is a map and street-art app. Artworks, locations, and group identity
are the content; chrome should make them easy to recognize and act on. The
app's recognizable vocabulary is **warm orange, cool neutral surfaces, rounded
shapes, Signika text, and clear icon-plus-label navigation**. The usual screen
hierarchy is: location or artwork first, task action second, metadata and
progression third. The UI can be playful, but completion and presence states
must be understandable without interpreting decoration.

This is a description of the intended direction, not a mandate to put a map on
every screen. A form or settings screen should still feel like the same app.

Use the standard Material icon set for application chrome and section
landmarks. The user's latest direction replaces the decorative emoji introduced
during the first experiment series with a more professional treatment. Retain
the warm orange accents, Signika typography, content imagery and clear labels.
Historical experiment screenshots preserve earlier alternatives; they do not
override this newer iconography decision.

The first ten-experiment review in [UI iterations](../docs/ui-iterations/README.md)
retains an inset navigation dock on a themed backdrop, icon-plus-label map
scopes, a separate rankings title/status, direct group discovery/create
actions, clearer tappable group rows, Settings section landmarks,
labeled map/photo inset toggles, and an expanded rail from 900 logical pixels.
The former emoji landmarks have since been replaced by Material icons. The
black-backed dock and extra camera-control tray were rejected. Compact
navigation keeps all five labels; the rail stays compact below the expanded
breakpoint. Preserve these choices while checking large-text and short-window
behavior.

The second ten-round review in [UI iterations 11–20](../docs/ui-iterations-2/README.md)
keeps a factual group count, explained Find/Create action cards, a labeled
keyboard-accessible group filter, outlined Feed posts, flat Settings sections,
and a collapsible wide navigation rail. Rounds 17 and 19 were reverted at user
request: retain the feed Map/Photo thumbnail selector and icon-only location
action. The compact dock retains all five labels; the map scope
retains its stronger selected pill. Settings and Rankings use standard Material
icons, and the rail brand reads “Stick-It” without decorative emoji.

The small-screen comparison in [compact UI options](../docs/ui-compact-options/README.md)
supersedes the large Find/Create cards and persistent filter/scope captions.
Use toolbar Search/Create icons and icon-only map controls with tooltips and
accessible names. Group profile titles have the full toolbar width; Share and
the existing overflow live beside the profile stats below. Long names and
large text determine the title/header height. Group tabs use recognizable
icons; the description is a compact teaser with full information on demand.
Achievements show the current tier per category, prioritizing ready rewards,
then nearby goals, then collected tracks. The All tiers entry exposes future
and collected tiers; details retain full requirements and reward collection.
The non-map compact navigation dock floats over content with icons only,
while the map keeps its dock integrated with the sliding rankings panel.

The follow-up [five-option comparison](../docs/ui-achievement-menu-options/README.md)
replaces the achievement carousels with full-width current-goal rows, grouped
as Ready to collect, Next up, and Collected. Include the category and exact
count, with requirements/reward collection in a details sheet. The labeled
All tiers catalog retains future and collected milestones. At the user's
follow-up direction, group profiles now mirror the personal profile's top-row
Settings gear. Members have three content tabs; sharing and the full group
information live on the Group settings page alongside Edit, Report and Leave.
The member profile no longer repeats the description or Share below the stats.
For admins, Group settings shows the edit form directly (photo, name,
description, link, visibility and admin selection) with Save changes followed
by sharing and the other actions. A successful save stays on Settings.
Other members retain read-only group information. Long group titles reserve
room for the single gear and scale their toolbar
height. Settings remain member-only, including direct links; the public and
locked non-member overview behavior is preserved. See
[profile alignment](../docs/ui-profile-alignment/README.md). The earlier
fourth settings-tab comparison is historical. Floating icon-only navigation
outside Map remains in place in that historical comparison.

The floating navigation correction supersedes the split Map/non-map dock.
All five compact destinations use the same centered, icon-only capsule over
the page, with no painted footer or opaque surround. Only the capsule casts a
shadow. Its selected slot expands while the indicator slides and the icon
grows from 24 to 28 logical pixels. Page changes slide over 320 ms; reduced
motion selects immediately. Each target stays at least 48 logical pixels at
the supported narrow phone sizes. The dock avoids the system bottom inset and
hides for the keyboard. Visited page state is retained. Map tiles extend
behind the dock. The rankings tray shares the dock width and bottom edge,
expanding upward from behind it; ranking content stays above navigation.
Attribution and location controls follow the tray’s top edge while it moves.
Feed and group lists keep full-height viewports and put dock clearance at the
end of their scrollable content, so content can pass behind the capsule.
Wider layouts keep the existing adaptive navigation rail.

Photo approval uses a centered, floating Upload pill with a transparent
surround. The form scrolls behind it with measured trailing clearance. Keep
the action visible above the keyboard; show saving progress and persistent,
recoverable errors beside it. See [capture uploads](../docs/ui-capture-upload/README.md).

## Implemented foundations

| Element | Current source and visual role | Guidance for new work |
| --- | --- | --- |
| Theme | [`MaterialTheme`](lib/util/theme/data/material_theme.dart) uses Material 3 and light/dark `ColorScheme`s. Light surface is `#F4F6F8`; dark surface is `#121519`. | Use `Theme.of(context).colorScheme` and themed components before adding literal colors. Treat dark and light as first-class states. |
| Brand accent | `primary` is peach `#FFB77C` in both themes; `onPrimary` is dark brown `#4B2800`. The light theme also defines a stronger orange container `#E88F1D`. | Peach works as a filled action or selected background with dark foreground. Do not assume it is readable as small text or an icon on a light surface. Check the actual foreground/background pair. |
| Supporting colors | Slate blue-gray is `secondary`; teal is `tertiary`. On-surface and outline roles are neutral. | Use these semantic roles sparingly. A group pin's customizable palette is content identity, not a second app-wide accent system. |
| Type | [`pubspec.yaml`](pubspec.yaml) bundles variable **Signika**; the theme applies it to `TextTheme`. | Use theme text styles and deliberate weight/size hierarchy. Avoid a platform-widget default font quietly replacing the app's type. Keep labels readable when text scales. |
| Shape and spacing | The theme uses 12px input corners, 16px card corners, and 16px input padding. Screens commonly use 16px horizontal gutters and 8/12/16px gaps. | Follow these as current working patterns, not a rigid token scale. Keep alignment and grouping consistent within a screen; do not add one-off dimensions without a layout reason. |
| Navigation | [`Navigation`](lib/features/navigation/presentation/navigation.dart) uses five destinations: Groups, Camera, Map, Feed, Profile. Compact windows use a centered, floating icon-only capsule; windows at least 600 logical pixels wide use a scrollable labeled rail. | Keep active state recognizable through icon size, filled shape and selection pill. Keep tooltip and accessibility labels for icon-only navigation. New secondary navigation should have a clear relationship to its content. |
| Web frame | [`MyApp`](lib/app/app.dart) centers the app on black, with a 450px cap on compact windows and a 1000px cap on wider windows. | Treat the black frame as an implementation constraint, not a brand token. Review wider layouts intentionally. |

## Component and interaction language

- **Actions:** One visually dominant action per immediate task, named for its
  result (for example, “Create group” or “Apply to group”). Use a filled warm
  action with a contrasting foreground for a primary action; secondary actions
  may be outlined or textual. The current shared `SubmitButton` and some
  screens do not consistently follow this hierarchy, so copy their behavior
  only after checking the rendered result.
- **Cards and panels:** Rounded neutral surfaces with quiet borders organize
  information. A card should make a distinct decision or group legible; do not
  repeat a large card for every distant milestone when a compact summary can
  answer the current task. The existing achievements catalog is an example to
  improve, not a template for new progress screens.
- **Inputs:** Keep a persistent label, a visible resting affordance, and a
  distinct focus/error state. The shared theme supplies a visible resting outline; screen-specific outlines
  still need review. Do not treat
  loose-looking text fields as intentional minimalism.
- **Feedback:** State changes need accurate, local confirmation and a clear
  recovery path. Place messages where they do not cover the action needed to
  recover. Never claim that a restart is required unless the current flow
  actually requires one.
- **Sheets and overlays:** Their height should follow content where practical.
  Keep map controls, attribution, bottom actions, and status messages clear as
  sheets expand or transient messages appear.

### XP feedback and profile identity

User and group profile headers show a circular XP ring around the avatar and a
visible “Lv” badge at the ring's lower-left. Keep XP progress in the ring rather
than repeating it in a separate profile section; exact amounts remain available
from the indicator's tooltip and semantics. Achievement pages contain the
rewards themselves.

Other users' profiles show their public level progress and earned achievements.
Keep in-progress totals and unclaimed reward details private; the public
achievement view is read-only.

Confirmed XP increases use one dismissible, themed notice over the lower part
of the current route and above the bottom navigation, with separate personal
and named-group amounts. Keep it inside the system gesture inset and do not
shift the route when it appears.
Initial loads,
repeated server totals, and queued uploads are not reward events. Remove
redundant success/loading toasts when the content already confirms the change;
retain actionable failures. If XP cannot be loaded, keep the saved action and
recover the profile total on refresh without inventing a reward amount.

## Map, artwork, and progression semantics

The map is the central browsing surface. Individual markers are about 48×56px
and currently use the **group image** rather than the artwork photo
([marker source](lib/widgets/custom_marker/presentation/custom_marker_content.dart)).
That supports group recognition but repeats imagery across a group's pins.
When changing markers, assess the normal, selected, clustered, and gone states
at actual map size and against light/dark map backgrounds. Show an artwork
photo and group name clearly on selection; never rely on tiny decoration or
color alone to explain whether an artwork is gone. Custom group outlines and
emblems are expressive decoration; factual presence and selection need a
separate, stronger visual channel.

Personal achievements and group appearance have different owners and effects.
Use explicit language for these states:

| Scope | States users need to distinguish |
| --- | --- |
| Personal reward | In progress → Ready to collect → Collected. Displayed on profile is a separate choice. |
| Group style | Locked/earned, previewed or edited, saved as a preset, and active on the group's map are separate states. |
| Pin presence | Here/gone is factual status, not an achievement or decorative emblem. |

Final personal achievement tiers use a highlighted name chip and a small mark
to distinguish them from earlier hard tiers. Hard group pin presets carry a
small earned emblem; the emblem is tied to the preset, while its shape and
colors remain editable. These marks express rarity and must not be used as a
pin's presence indicator.

Before an action, show the reward or design in the form users will actually
see. Say what is counted and what remains; keep detailed rules available on
demand. Prefer one primary noun for a pin/artwork within a flow and define
product-specific terms such as “place.” Current copy does not yet meet all of
these aims; see the [progression review](../docs/PROGRESSION_UX_REVIEW.md).

## Review conditions and known exceptions

For a substantial Flutter UI change, inspect the affected task at narrow
phone, typical phone, and wider widths, with both themes when theme behavior
is relevant. Include long text, empty/loading/error content, text scaling, and
the overlay or sheet states that the flow can reach. Judge touch targets,
labels, focus, and contrast as part of the rendered interaction, not just the
static screenshot. Use focused widget/golden tests for deterministic components
and a running app for navigation, map, camera, and cross-screen behavior.

Do **not** infer a design rule from these current exceptions:

- Light-theme peach labels have weak contrast on the light surface.
- Settings uses a different font, blue headings, and raised white cards.
- Primary form actions, screen-specific text fields, and sheet heights vary by screen.
- The desktop web view still has a bounded content area on black; adaptive
  map/detail and feed layouts need further review.
- Achievement cards overload the page while concealing reward meaning, and
  the pin editor can preview one style while a different one is active.

These are recorded in the two reviews linked above. A review should distinguish
an existing implementation, a deliberate design choice, and a proposed fix.

## Pin photo entries

The main Feed and pin details use the photo layout described in
[Pin photos and updates](../docs/PIN_ENTRY_DESIGN.md) (6 October 2026). The
User Images and Group Images lists show each entry as a tappable photograph,
starting with its thumbnail and fading to full resolution as it loads;
tapping it opens pin details with that photo selected. Selecting a photo in a Profile Pins grid opens pin details with that
photo selected, including while its thumbnail is loading or unavailable.
Selecting a Group Pins grid photo opens the corresponding image list at that
entry. Show full photographs in the main Feed and pin details using contain
fitting, with contributor, group, date, caption and photo-specific likes below
the image. Keep map previews behind an explicit control.

Main Feed image cards retain the established top overlay with contributor and
group identity. Place the overlapping user and group profile pictures at its
upper left, immediately before the profile name. Show the contributor badge
without the user's level, and a place name when city, state, or country
resolves; show coordinates only when none resolves. Keep update photos
visually consistent with original photos; do not show an update label or icon
in the feed. When multiple photos are available, show a centered dot progress
indicator over the photo; swiping changes photos.
Previous/next photo buttons also remain available for touch, keyboard and
assistive navigation. Keep their labels explicit and their targets at least
48 logical pixels; progress dots complement those controls.
The Map/Photo thumbnail inset switches the main card view and provides the
way back to the photo while the map fills the card. Its Map caption uses text
without an extra map glyph. Keep its target at least
48 logical pixels. Main Feed posts use a subtle outlined surface around the
photo and metadata.
Place likes, group name, and photo age under the image, followed by title and
description. The attribution header reserves the same 48 px height in the main
feed and in pin details, even when the detail view hides the feed options menu.
Pin details keep the selected photo, contributor, date, caption, photo
navigation, and likes together. They do not show separate update or mark-gone
buttons; photo updates and gone reports use the regular camera flow.

Photo updates start in the regular camera approval screen. After capture, let
people select a synced pin within 50 m from the selected group, or leave the
new-pin option selected. Show each nearby pin's photo to the left of its title;
tapping the thumbnail opens pin details. A selected pin can optionally be
marked gone with the photo, off by default.

## Group pin builder

Group admins configure pin appearance in Group settings, after the group edit
form. The builder previews a combination of earned colors and geometric shapes
and saves it explicitly. Achievement rows describe color and shape rewards;
editing no longer lives in the achievements tab. Group pins omit decorative
sun, star and spark badges, including legacy designs, following the user's
color-and-shape-only direction (November 2026).
