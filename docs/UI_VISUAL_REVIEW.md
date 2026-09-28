# Stick-It: live visual UI review

**2026-09-27 · 12 findings from navigating the running Flutter web app.** This is a new visual review; the earlier source-only review is not the evidence for these findings. No app code was changed.

Open the [screenshot gallery](ui-visual-review/index.html) for side-by-side visual evidence. Each finding below includes the navigation path, observed problem, source, and a possible fix. “High” marks overlap, clipping, or serious legibility; the remaining items are design recommendations grounded in the rendered screens.

## What ran

- Built this worktree with `E2E_API_URL=http://127.0.0.1:8081 mise run flutter-build-web` (successful, 116.55s).
- Ran the Go API, a dedicated disposable PostgreSQL/PostGIS database, RustFS image storage, and the local Flutter static server at `http://127.0.0.1:4173/`.
- Navigated with Playwright and Chromium **153.0.8010.12**, using Flutter accessibility semantics for targeting and direct mouse/touch actions. Inspected saved screenshots visually. Browser resources confirmed **main.dart.wasm + skwasm**.
- Viewports: **390×844**, **320×740**, **1440×900**, and **844×390** landscape. Inspected light and dark themes.
- Covered sign-in, Groups, group search, joined/unjoined group details, Members/Pins/Achievements, Feed and its menu, Map and expanded rankings, group filters, Profile and achievements, Settings, profile edit, cache confirmation, camera, location selection, photo review, pin details, and reporting.
- Camera used Chromium’s synthetic camera, not a physical camera. Location acquisition failed in this browser session and exposed the fallback/error UI. Black fixture photos/avatars and “Unknown Region” from the disposable data are **not classified as visual defects**. No production accounts, deletion, reporting, or publishing actions were used.
- Applied the [Vercel Web Design Guidelines skill](https://github.com/vercel-labs/agent-skills/blob/main/skills/web-design-guidelines/SKILL.md), focusing on actual rendered layout and appearance. Contrast target reference: [W3C Contrast (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

## Findings

### 01. Group avatar intrudes into the tab strip

**High — overlap.** Groups → open the joined public group. Reproduced at 390×844 and 1440×900, in light and dark themes.

**Observed:** The 80px avatar extends down into the Members icon row. The header looks assembled from overlapping pieces. The tabs also appear before the Members/Sticks/Description summary, separating each tab from its actual content.

**Source:** [`widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart:61`](../flutter/lib/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart#L61), [`widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart:69`](../flutter/lib/widgets/custom_scaffold/presentation/custom_avatar_scaffold.dart#L69), [`features/group_overview/presentation/sub_widgets/group_overview.dart:64`](../flutter/lib/features/group_overview/presentation/sub_widgets/group_overview.dart#L64). The shared header reserves 180px, positions an 80px avatar 60px from the top, and puts an icon-plus-label TabBar into the same app bar. Summary ListTiles are separate slivers after the tabs.

**Possible fix:** Give avatar/summary and tabs separate layout rows. Put the avatar beside compact member/pin counts, then description, then a pinned tab bar. Derive expanded height from that content rather than overlapping a fixed background and bottom slot.

**Evidence:** [Group header: avatar and Members icon share vertical space](ui-visual-review/05-group-phone.png) · [The same header collision persists on desktop](ui-visual-review/07-group-desktop.png) · [The same structure in dark mode](ui-visual-review/30-empty-group-dark.png)

### 02. Feed metadata runs past the right edge

**High — clipping.** Feed → resize to 320×740 with the seeded joined group.

**Observed:** The group name, separators, and age stay on a single line that is wider than the card. The age reaches the viewport edge and is clipped rather than aligning with the photo’s right gutter. The long group name is legitimate fixture content, not an artificially enormous string.

**Source:** [`widgets/custom_feed/presentation/like_buttons.dart:28`](../flutter/lib/widgets/custom_feed/presentation/like_buttons.dart#L28), [`widgets/custom_feed/presentation/like_buttons.dart:75`](../flutter/lib/widgets/custom_feed/presentation/like_buttons.dart#L75). The Row contains an unconstrained group-name Text and trailing date, with no Flexible/Expanded, wrapping, or overflow strategy.

**Possible fix:** Let the group name take the remaining space with ellipsis, preserve a fixed trailing date, or wrap metadata into two lines. Keep the whole row inside the photo’s horizontal padding. Verify at 320px with long names.

**Evidence:** [320px feed: metadata escapes the card gutter and clips at the viewport](ui-visual-review/17-feed-narrow.png) · [390px comparison](ui-visual-review/16-feed-phone.png)

### 03. Location-error toast covers the Next action

**High — overlay.** Camera → Take photo → location fallback → Select Location, while the location failure message is visible.

**Observed:** The red error toast sits directly over the bottom-right Next button. Only part of the button outline is visible, precisely when the user needs to continue by choosing a location manually. This was observed during an actual local browser location failure; no screenshot was mocked.

**Source:** [`widgets/custom_interaction/presentation/custom_error_snack_bar.dart:10`](../flutter/lib/widgets/custom_interaction/presentation/custom_error_snack_bar.dart#L10), [`features/camera/presentation/select_location.dart:100`](../flutter/lib/features/camera/presentation/select_location.dart#L100). The floating-snackbar overlay is positioned independently of the screen’s bottom action. Both occupy the same bottom band.

**Possible fix:** Use an inline location-status banner above the map, or a Scaffold-managed snackbar with an inset that clears a shared bottom action bar. A recoverable error must not obscure the recovery action.

**Evidence:** [Select Location: red error message obscures Next](ui-visual-review/12-photo-review-phone.png)

### 04. Light-theme active controls look faded

**High — legibility.** Sign in, navigation tabs, group tabs, form actions, filter sheet, and Delete Cache confirmation.

**Observed:** Active links and selected labels are pale orange on an almost-white surface. They can look less prominent than inactive gray controls. Feed metadata is similarly faint. In the light feed header, the overflow-menu dots are dark against a dark gray overlay, unlike the white author name.

**Source:** [`util/theme/data/material_theme.dart:13`](../flutter/lib/util/theme/data/material_theme.dart#L13), [`util/theme/data/material_theme.dart:192`](../flutter/lib/util/theme/data/material_theme.dart#L192), [`widgets/custom_feed/presentation/like_buttons.dart:81`](../flutter/lib/widgets/custom_feed/presentation/like_buttons.dart#L81), [`widgets/custom_feed/presentation/feed_card_image_header.dart:30`](../flutter/lib/widgets/custom_feed/presentation/feed_card_image_header.dart#L30). The same #FFB77C primary is used in both themes. Against #F4F6F8 it yields approximately 1.57:1 contrast. Feed metadata uses #9E9E9E, approximately 2.47:1 against that surface. These are calculations from source color values, not anti-aliased screenshot pixels. The feed header uses translucent gray and leaves the menu icon theme-dependent.

**Possible fix:** Use a darker orange for light-theme text/icons and reserve the peach for filled backgrounds with dark text. Use onSurfaceVariant for secondary metadata. Give photo headers a consistent scrim and explicitly contrasting menu icons. Check final foreground/background pairs against the 4.5:1 normal-text target.

**Evidence:** [Faint secondary sign-in links](ui-visual-review/01-login-phone.png) · [Faint metadata and dark overflow dots](ui-visual-review/16-feed-phone.png) · [Low-emphasis Cancel/Delete actions](ui-visual-review/34-cache-dialog-light.png)

### 05. Several form fields look like loose text

**Medium — affordance.** Sign in; Groups → + → Create a new group, before focusing any field.

**Observed:** The email/username field has almost no visible container. Group name, description, and URL likewise look like labels placed in empty space. This differs sharply from the clear outlined fields in photo review and profile editing.

**Source:** [`util/theme/data/material_theme.dart:138`](../flutter/lib/util/theme/data/material_theme.dart#L138), [`widgets/group_edit_template/presentation/group_edit_template.dart:66`](../flutter/lib/widgets/group_edit_template/presentation/group_edit_template.dart#L66), [`features/auth/presentation/auth.dart:271`](../flutter/lib/features/auth/presentation/auth.dart#L271). The global input decoration removes the resting border and uses a very subtle fill. Some screens inherit it, while others explicitly request OutlineInputBorder.

**Possible fix:** Choose one field treatment across the app: visible surface fill and/or a subtle resting outline, persistent labels, and a distinct focus border. Preserve clean spacing without relying on placeholder-like text to communicate that an area is editable.

**Evidence:** [Sign-in field is visually difficult to distinguish](ui-visual-review/01-login-phone.png) · [Group form resembles loose text](ui-visual-review/10-create-group-phone.png) · [Photo review already uses clearer outlined fields](ui-visual-review/13-approve-phone.png)

### 06. Settings looks like a different application

**Medium — consistency.** Profile → Settings, then Edit profile, in both themes.

**Observed:** Settings switches from the app’s Signika typography and orange styling to a platform-style list with a different font, bright blue section headings in light mode, white raised cards, and different spacing. Entering Edit profile switches the visual language back again.

**Source:** [`features/settings/presentation/settings.dart:32`](../flutter/lib/features/settings/presentation/settings.dart#L32), [`util/theme/data/material_theme.dart:114`](../flutter/lib/util/theme/data/material_theme.dart#L114). SettingsList from settings_ui is rendered without a custom theme that aligns its typography, section colors, surfaces, and separators with the app’s Material theme.

**Possible fix:** Apply the same text styles and color tokens to SettingsList, or build the settings sections from the app’s standard ListTiles. Keep section heading weight, card treatment, and side gutters consistent with adjacent screens.

**Evidence:** [Settings introduces blue headings and a different list/font treatment](ui-visual-review/20-settings-light.png) · [Settings in dark mode](ui-visual-review/21-settings-dark.png) · [Adjacent profile-edit screen uses the app’s own visual system](ui-visual-review/22-edit-profile-dark.png)

### 07. Desktop is a narrow phone strip on a black canvas

**Medium — desktop layout.** Resize any signed-in screen to 1440×900; observed on group details, profile, and group creation.

**Observed:** The entire app remains 450px wide with almost 500px of black space on each side. Light mode has especially harsh framing. Maps, lists, and forms cannot use the available space; this looks like an embedded phone preview rather than a desktop web app.

**Source:** [`app/app.dart:36`](../flutter/lib/app/app.dart#L36), [`app/app.dart:39`](../flutter/lib/app/app.dart#L39). The web builder explicitly supplies a black ColoredBox and caps all routed content at maxWidth: 450.

**Possible fix:** At minimum use a theme-matched outer surface and a deliberate centered app frame. Prefer responsive layouts: bounded reading/form columns, wider map/list views, and a navigation rail above a desktop breakpoint. A phone-width layout can remain an intentional small-screen mode.

**Evidence:** [1440px group screen retains a 450px application column](ui-visual-review/07-group-desktop.png) · [Same black framing around a light form](ui-visual-review/09-create-group-desktop.png)

### 08. Expanding rankings buries map controls

**Medium — overlay coordination.** Map → drag the ranking sheet upward using a touch gesture. Reproduced at 390×844.

**Observed:** The expanded sheet covers the recenter control and map attribution. The visible map remains at the top, but its recenter action stays below the sheet. The collapsed state has the controls immediately above the sheet, so expansion breaks their spatial relationship.

**Source:** [`features/map_home/presentation/map_home.dart:127`](../flutter/lib/features/map_home/presentation/map_home.dart#L127), [`features/map_home/presentation/map_home.dart:146`](../flutter/lib/features/map_home/presentation/map_home.dart#L146), [`features/map_home/presentation/map_home.dart:168`](../flutter/lib/features/map_home/presentation/map_home.dart#L168). Controls use fixed bottom offsets based on the collapsed 60px header. The ranking sheet is painted later in the Stack and grows over them; the surrounding notification listener does not reposition the overlays.

**Possible fix:** Track the live sheet extent and anchor recenter and attribution above it, with a small consistent gap. If expanded rankings intentionally replace map interaction, make that a clear mode and provide an obvious collapse action. Keep required map attribution visible.

**Evidence:** [Collapsed panel: recenter and attribution are visible](ui-visual-review/02-map-phone.png) · [Expanded panel covers the same controls](ui-visual-review/27-map-expanded-dark.png)

### 09. Dark mode leaves the map glaringly light

**Medium — theme mismatch.** Enable dark theme in Settings → return to Map.

**Observed:** The header, switches, navigation, and ranking sheet turn very dark while the map remains bright cream and blue. The largest surface does not participate in dark mode, producing a stark split across the screen.

**Source:** [`widgets/custom_map_setup/presentation/custom_tile_layer.dart:11`](../flutter/lib/widgets/custom_map_setup/presentation/custom_tile_layer.dart#L11). The tile layer always requests the same raster tile style regardless of theme.

**Possible fix:** Offer a dark cartographic style and select it with the app theme, or expose an explicit map-style setting. Prefer properly styled tiles over blanket image inversion, which can damage labels and marker colors.

**Evidence:** [Bright map against dark app surfaces](ui-visual-review/27-map-expanded-dark.png)

### 10. One group opens a mostly empty half-screen filter

**Medium — disproportionate sheet.** Map or Feed → tap the group-filter avatars with one joined group.

**Observed:** The filter sheet takes 60% of the screen for one row. Most of it is blank; the small header and Select All action are visually stranded at the top. There is no visible close button or drag handle. The one-row filter feels disproportionately heavy.

**Source:** [`widgets/group_selector/presentation/group_filter.dart:152`](../flutter/lib/widgets/group_selector/presentation/group_filter.dart#L152), [`widgets/group_selector/presentation/group_filter.dart:160`](../flutter/lib/widgets/group_selector/presentation/group_filter.dart#L160). The sheet uses a fixed viewport fraction and an Expanded list, independent of item count.

**Possible fix:** Use content-sized height with a sensible maximum and scrolling when needed. Add a clear drag handle/close control, and make the whole filter trigger a labeled control such as “Groups · 1 selected.” Avoid showing Select All as the dominant action for a one-item list.

**Evidence:** [A single row leaves most of the fixed-height sheet empty](ui-visual-review/03-filter-phone.png)

### 11. Primary form actions look like small secondary buttons

**Medium — action hierarchy.** Create group, photo review, Edit profile, and Report Issue.

**Observed:** Create/Upload are narrow orange outline pills, often isolated at the extreme bottom-right with a large empty gap after the form. Other screens place a similar pill immediately after their fields. Login instead uses a prominent filled, full-width action. The app lacks a consistent primary-action pattern.

**Source:** [`widgets/buttons/presentation/custom_submit_button.dart:51`](../flutter/lib/widgets/buttons/presentation/custom_submit_button.dart#L51), [`widgets/group_edit_template/presentation/group_edit_template.dart:231`](../flutter/lib/widgets/group_edit_template/presentation/group_edit_template.dart#L231), [`features/camera/presentation/image_upload.dart:135`](../flutter/lib/features/camera/presentation/image_upload.dart#L135). The shared SubmitButton styles an ElevatedButton with an orange border and bottom-right alignment. Screens place it variously in floatingActionButton, a fixed bottom area, or inline form content. Its declared height parameter is not applied in build.

**Possible fix:** Use a clear filled primary action with a consistent visible height. For long/task screens, use a padded bottom action bar; for short forms, place it consistently after the fields. Use labels such as “Create group” and “Publish pin.” Keep outlined buttons for secondary actions.

**Evidence:** [Small Submit button separated from a sparse form](ui-visual-review/10-create-group-phone.png) · [Upload is visually weak and distant from the form](ui-visual-review/13-approve-phone.png) · [Similar button placed differently in the report form](ui-visual-review/26-report-dark.png)

### 12. Group search opens as an unlabeled empty pill with a trash icon

**Lower — search clarity.** Groups → + → Search existing groups.

**Observed:** The page has no visible title or search prompt. An empty rounded search bar immediately shows a trash-can control. It gives little guidance about what can be searched, and the destructive-looking icon is an odd choice for clearing text that is not there yet.

**Source:** [`features/group_search/presentation/group_search.dart:54`](../flutter/lib/features/group_search/presentation/group_search.dart#L54), [`features/group_search/presentation/group_search.dart:55`](../flutter/lib/features/group_search/presentation/group_search.dart#L55), [`features/group_search/presentation/group_search.dart:64`](../flutter/lib/features/group_search/presentation/group_search.dart#L64). The SearchBar has a leading search icon but no hintText; a delete icon is always rendered in trailing controls.

**Possible fix:** Add “Search groups” as a persistent accessible label/visible hint and, if needed, a page heading. Use a conventional clear × only when the query is nonempty. Keep field dimensions aligned with the shared form system.

**Evidence:** [Empty search field with persistent trash icon and no hint](ui-visual-review/29-search-dark.png)

## Fix order

1. Correct the avatar/tab layout, constrain feed metadata, and keep toasts clear of primary actions.
2. Adjust light-theme foreground colors and establish shared input/button styles.
3. Align Settings with the app theme; coordinate map overlays; make filter-sheet height content-aware.
4. Improve desktop framing, provide a dark map style, and refine group-search presentation.

## Limits

This is an exploratory visual review, not a complete accessibility or regression certification. There was no physical Android camera/keyboard test, screen-reader test, or coverage of every data volume. Recommendations about desktop layout and sheet proportions are design judgments; overlap, clipping, the toast collision, and the documented color ratios have concrete evidence. Screenshots are unedited browser captures. The inline preview host was unavailable, so a local Playwright browser supplied the evidence.
