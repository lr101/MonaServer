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

## Implemented foundations

| Element | Current source and visual role | Guidance for new work |
| --- | --- | --- |
| Theme | [`MaterialTheme`](lib/util/theme/data/material_theme.dart) uses Material 3 and light/dark `ColorScheme`s. Light surface is `#F4F6F8`; dark surface is `#121519`. | Use `Theme.of(context).colorScheme` and themed components before adding literal colors. Treat dark and light as first-class states. |
| Brand accent | `primary` is peach `#FFB77C` in both themes; `onPrimary` is dark brown `#4B2800`. The light theme also defines a stronger orange container `#E88F1D`. | Peach works as a filled action or selected background with dark foreground. Do not assume it is readable as small text or an icon on a light surface. Check the actual foreground/background pair. |
| Supporting colors | Slate blue-gray is `secondary`; teal is `tertiary`. On-surface and outline roles are neutral. | Use these semantic roles sparingly. A group pin's customizable palette is content identity, not a second app-wide accent system. |
| Type | [`pubspec.yaml`](pubspec.yaml) bundles variable **Signika**; the theme applies it to `TextTheme`. | Use theme text styles and deliberate weight/size hierarchy. Avoid a platform-widget default font quietly replacing the app's type. Keep labels readable when text scales. |
| Shape and spacing | The theme uses 12px input corners, 16px card corners, and 16px input padding. Screens commonly use 16px horizontal gutters and 8/12/16px gaps. | Follow these as current working patterns, not a rigid token scale. Keep alignment and grouping consistent within a screen; do not add one-off dimensions without a layout reason. |
| Navigation | [`Navigation`](lib/features/navigation/presentation/navigation.dart) uses five Material 3 destinations with icon and label: Groups, Camera, Map, Feed, Profile. | Keep active state recognizable by icon, text, and shape, rather than pale color alone. New secondary navigation should have a clear relationship to its content. |
| Web frame | [`MyApp`](lib/app/app.dart) currently centers a maximum 450px app on black. | This is a current implementation constraint, not a desktop design rule. Review wide layouts intentionally; do not reproduce the black frame as a brand token. |

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
  distinct focus/error state. The current theme's nearly invisible resting
  border and varying screen-specific outlines are unresolved. Do not treat
  loose-looking text fields as intentional minimalism.
- **Feedback:** State changes need accurate, local confirmation and a clear
  recovery path. Place messages where they do not cover the action needed to
  recover. Never claim that a restart is required unless the current flow
  actually requires one.
- **Sheets and overlays:** Their height should follow content where practical.
  Keep map controls, attribution, bottom actions, and status messages clear as
  sheets expand or transient messages appear.

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
- Primary form actions, resting text fields, and sheet heights vary by screen.
- The desktop web view is a narrow phone column on black.
- Achievement cards overload the page while concealing reward meaning, and
  the pin editor can preview one style while a different one is active.

These are recorded in the two reviews linked above. A review should distinguish
an existing implementation, a deliberate design choice, and a proposed fix.
