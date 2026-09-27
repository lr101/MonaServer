# Achievements and pin appearance: live UX review

**Reviewed 27 September 2026 on `develop` commit `fc7fd635`.** The review branch was fast-forwarded from `7466c002` to the freshly fetched `origin/develop`. Earlier reports and screenshots were preserved. This review changes documentation only; the concept below is not implemented in Flutter.

[Observed screenshots](progression-ux-review/index.html) · [Interactive proposed concept](progression-ux-review/concept.html)

## Main finding

The achievement page shows **a lot of configuration and progress, but little help deciding what to do**. The missing information is not another progress bar: it is what counts, what the reward looks like, who receives it, and what changes after the action.

Pin appearance has the same problem. It mixes unlocking, choosing the group's active style, editing a different style, and saving a design. On the map, the group image is clear, but artwork identity and presence status receive much less emphasis.

The recommended direction is three distinct tasks:

1. **My progress:** rewards ready now, the next useful goal, and a separate earned collection.
2. **My profile badge:** preview and choose what other people see.
3. **Group map appearance:** preview a design in context, then explicitly apply it to this group.

Keep the existing reward economy initially. The first improvements can change presentation without changing eligibility, XP amounts, or authorization.

## Evidence and boundaries

- Rebuilt the latest worktree: `E2E_API_URL=http://127.0.0.1:8081 mise run flutter-build-web`, successful in 105.84 seconds. Ran the current Go API, dedicated disposable PostGIS database, RustFS, and Flutter static server locally.
- Used Chromium 153 through Playwright, navigating the real Flutter Wasm app. Fresh screenshots use 390×844 and 320×740 viewports. This pass focuses on mobile-sized web UX; the earlier review covers desktop framing.
- Started as `stickitviewer`: inspected all personal tracks, claimed First stick, and chose it as the profile badge. Observed level 1 / 5 XP become level 2 / 25 XP.
- Added a dedicated disposable group, **Canal Art Explorers**, owned by `stickitowner`, with 25 pins. Used existing repository images as recognizable sample artwork and the app logo as the group image; these are test content, not real street-art observations.
- As owner: claimed Moss and Sunset, opened the editor while Classic remained active, changed Moss to a red-outline teardrop with a star, saved it, switched the editor to Sunset, activated Moss, and inspected clustered and individual map markers. Opened a nearby pin, marked it gone, inspected its marker, and restored it to here.
- The inline preview host was unavailable; screenshots came from a local Playwright browser. Some Flutter semantic locators caused nested-scroll jumps, so visible controls were also operated using pointer coordinates. Those automation artifacts are not counted as product defects.
- The new avatar/tab spacing is visibly improved. Old overlap findings are not repeated as current defects. Compact avatar changes are also included in this build.
- This is a heuristic walkthrough, not a user study. Expected user benefits below are hypotheses to test, not measured conversion or comprehension improvements. No production data was touched.

## Personal achievements

### A1. The page answers “what exists?” before “what can I do?”

**Observed:** The landing viewport contains the profile header, Likes, the level card, instructions, and roughly one full achievement. A second immediately claimable reward, First crew, is much farther down. All three thresholds of each track receive large cards, repeating icons, progress bars, difficulty/XP pills, and “Keep going to unlock this reward.” The bottom even renders “Other milestones · 0/0 earned.”

**Evidence:** [Landing](progression-ux-review/01-personal-overview.png), [distant ready reward](progression-ux-review/03-personal-groups.png), [bottom of catalog](progression-ux-review/04-personal-lower-tracks.png).

**Source:** [user_achievements_tab.dart:17](../flutter/lib/features/achievement/presentation/user_achievements_tab.dart#L17), especially the unconditional track loop at line 59 and every-milestone loop at line 118.

**Better:** Start with “2 rewards ready,” then one next milestone per track. Put future thresholds behind “View all milestones.” Move completed rewards into Collection. Hide empty tracks. Move unrelated Likes/profile statistics out of the progress task's main reading path.

**Trade-off:** A complete catalog advertises long-term goals and supports completionists. A shorter overview can hide ambition. Keep a visible, one-step catalog entry and a compact “next: 10 → 50 pins” ladder rather than removing future goals entirely.

### A2. Completed, collected, and displayed are different states, but the page blurs them

**Observed:** First stick was 1/1 with a Claim button while its section said “0/3 earned.” After claiming, the card changed to “XP already earned” and “Show on profile.” After another action it became “Shown on profile.” A new user has to infer three different state transitions.

**Evidence:** [Before claim](progression-ux-review/01-personal-overview.png), [after claim](progression-ux-review/05-personal-claimed.png), [badge displayed](progression-ux-review/07-profile-badge-result.png).

**Source:** [claimed-only earned count:93](../flutter/lib/features/achievement/presentation/user_achievements_tab.dart#L93), [claim/display branch:248](../flutter/lib/features/achievement/presentation/user_achievements_tab.dart#L248).

**Better:** Use explicit labels: “In progress,” “Ready to collect,” “Collected,” and a separate “Displayed on profile” designation. Say “1 ready · 0 collected” rather than “0 earned” next to a completed goal. Collection and profile selection should be separate controls, not surprising successive meanings of the same button area.

**Trade-off:** Manual collection creates a moment of celebration and lets users notice the reward. It also makes administrative work out of an accomplishment already completed. Initially keep claiming but surface all ready rewards together; automatic XP awarding is a separate product decision, discussed below.

### A3. Rewards and XP occupy space without explaining their value

**Observed:** Before claiming, the reward pill emphasizes “Easy · 20 XP.” The profile-badge reward is not previewed. The result is actually a small colored text label beside the username, not the large generic icon on the milestone card. Claiming moved the level from 1 to 2 and reset the bar to its start, while the prominent number remained total XP. There was no explanation of what reaching a level enables.

**Evidence:** [Claim transition](progression-ux-review/05-personal-claimed.png), [actual badge result](progression-ux-review/07-profile-badge-result.png).

**Source:** [reward pill:214](../flutter/lib/features/achievement/presentation/user_achievements_tab.dart#L214), [XP card:82](../flutter/lib/features/progression/presentation/user_xp_card.dart#L82), [actual badge renderer](../flutter/lib/widgets/tiles/presentation/batch.dart).

**Better:** Show the real badge preview and “20 XP + First stick profile badge” before collection. Use “Level 2 · 0/50 XP toward level 3” with lifetime XP secondary. Explain XP briefly on demand. Do not suggest levels unlock functionality unless the product actually implements that benefit.

**Trade-off:** Rich reward art everywhere creates more clutter. Show a compact, faithful reward thumbnail in the overview and a full profile preview only in reward details/Collection. Difficulty can move into details; it provides less immediate help than “9 more pins.”

### A4. Progress requirements use terms users cannot reliably interpret

**Observed:** The page says “places,” “sticks,” and “pins” across related screens. It does not define what a place means. “Fan favorite” says to receive likes on fifty of your sticks, which reads as fifty distinct artworks.

**Source check:** [achievements.go:36](../go-server/internal/db/achievements.go#L36) actually counts distinct non-null `state_province_id` values for places. [Line 78](../go-server/internal/db/achievements.go#L78) counts qualifying like records for Fan favorite, not distinct liked pins. This semantic mismatch is source-confirmed; a 50-like scenario was not simulated. The fixture's missing regional data can explain its zero place progress, so that zero is not presented as a production counting bug.

**Evidence:** [Places and Groups](progression-ux-review/03-personal-groups.png), [likes requirements](progression-ux-review/04-personal-lower-tracks.png).

**Better:** Define the counted unit in plain language and align the requirement with the actual metric. For example, “Map pins in 3 different regions” with a “What counts?” explanation. If the intended target is total likes, say “Receive 50 likes on your pins.” Use one primary noun throughout. Show remaining effort and the next relevant action.

**Trade-off:** Explaining every eligibility edge case on every card would worsen the current density. Put the counted unit and remaining amount on the card; reveal region boundaries, exclusions, and retention rules in a short detail view.

## Group rewards and pin customization

### G1. Two progression systems look related but do not explain their relationship

**Observed:** The group has a second level/XP card plus pin-count milestones. Personal rewards give XP and a profile label; group milestones give shared pin designs. The group card says “Earn shared frames,” yet there is no actual map preview before collecting. Progress can read “25 / 10 active pins.”

**Evidence:** [Group landing](progression-ux-review/08-group-claimable.png), [claimable group rewards](progression-ux-review/09-group-rewards.png).

**Source:** [group_achievements_card.dart:203](../flutter/lib/features/progression/presentation/group_achievements_card.dart#L203) and [reward swatch:218](../flutter/lib/features/progression/presentation/group_achievements_card.dart#L218). Admin editing is gated at line 102; non-admin presentation is a small current-frame label at line 152.

**Better:** Label the scope directly: “Group rewards — earned together; changes every pin in this group.” Show one next group goal and a real reward preview. For completed goals, say “Goal reached: 10 active pins” and show the current group count separately. Explain “members can collect; the group admin chooses the map appearance.” Keep an always-discoverable read-only Appearance view, including before any reward unlocks.

**Trade-off:** A separate group level can support competition, but adds another abstract score. Keep it secondary until its distinct value is evident. Member voting on styles might be useful later, but it should not complicate the first clear admin workflow.

### G2. The design being edited is not necessarily the design being used

**Observed:** Classic was selected in Pin appearance while the expanded editor defaulted to Moss. Classic was absent from the editor's “Unlocked style” list. This makes it easy to edit something without changing the map. After saving Moss and switching the editor to Sunset, the button still said “Saved.”

**Evidence:** [Active Classic / edited Moss](progression-ux-review/11-editor-top.png), [different style still labeled Saved](progression-ux-review/15-editor-other-style.png).

**Source:** [admin style chips and editor input:145](../flutter/lib/features/progression/presentation/group_achievements_card.dart#L145), [editor default:115](../flutter/lib/features/progression/presentation/group_pin_customizer.dart#L115), [style switching:220](../flutter/lib/features/progression/presentation/group_pin_customizer.dart#L220). `_saved` is a single editor flag, set at line 155, rather than a per-style saved/draft state.

**Better:** Distinguish “Active on map,” “Previewing,” and “Unsaved changes.” Use a single preset chooser with the current preset marked. Make the main action “Apply to Canal Art Explorers.” If users can save an inactive preset, label that action “Save preset only.” Display Classic explicitly as either editable or a fixed default with an explanation.

**Trade-off:** Separating edit from activation is useful for administrators preparing designs. It becomes confusing when both selectors look equivalent. Keep advanced preset management, but make the common path preview-and-apply.

### G3. Save feedback does not establish a trustworthy result

**Observed:** Saving said “Pin design saved. It will appear after app restart.” Yet when I subsequently activated Moss, the saved red teardrop appeared on the map in the same session. The walkthrough does not establish that every active-style edit refreshes immediately; it demonstrates that the feedback does not accurately describe this observed path.

**Evidence:** [Save message](progression-ux-review/14-editor-save-feedback.png), [same-session map result](progression-ux-review/21-map-earned-style.png).

**Source:** [save and feedback:135](../flutter/lib/features/progression/presentation/group_pin_customizer.dart#L135), [map catalog provider](../flutter/lib/widgets/custom_marker/data/group_pin_design_provider.dart). The editor and markers use separate catalog-reading paths; the save method does not explicitly refresh the shared marker catalog.

**Better:** On confirmed save/apply, refresh the shared catalog and show “Applied to this group's pins” with “View on map.” Keep the previous live design on failure; retain the draft and offer retry. If delayed application is truly required, state that consistently and expose a deliberate reload action.

**Trade-off:** Immediate feedback can cause broad marker rebuilds. Refresh the relevant group's design data while preserving image-byte identity, following the repository's media-provider guidance. Do not trade clear feedback for flickering markers.

### G4. The editor asks for many choices without a useful comparison surface

**Observed:** Shape, ten colors, two numeric sliders, five badges, and shadow are stacked in a long form. At 320px they wrap across multiple rows and the preview scrolls out of view before the bottom actions. The preview is a small symbol on a blank surface. It does not show the map, a selected marker, or a gone pin.

**Evidence:** [Full controls](progression-ux-review/12-editor-bottom.png), [320px layout](progression-ux-review/16-editor-narrow.png).

**Source:** [preview:191](../flutter/lib/features/progression/presentation/group_pin_customizer.dart#L191), [badge controls:268](../flutter/lib/features/progression/presentation/group_pin_customizer.dart#L268). The renderer caps the drawing at a nominal 48×56 rather than enlarging it to fill all preview space.

**Better:** Offer a few complete presets first. Keep a preview visible above the controls with both enlarged editing view and actual map size. Put outline thickness, crop/zoom, and shadow under Advanced. Show normal, selected, and gone states. Use a neutral example map and a reset-to-preset action.

**Trade-off:** Full controls support group personality, while constrained presets preserve map legibility. Prefer presets plus advanced editing to removing customization. A large preview alone can mislead: always retain the actual-size comparison.

## The pin on the map and its detail screen

### P1. Group recognition wins over recognizing individual artworks

**Observed:** Twenty-five distinct pins in the test group became repeated owl logos. Different artwork appeared only after opening a pin or in the nearby preview. Dense markers and their decoration compete with street labels. This is not inherently wrong: the design makes ownership recognizable and keeps imagery stable. It optimizes a different task from browsing artworks visually.

**Evidence:** [Classic markers](progression-ux-review/19-map-individual-pins.png), [customized markers](progression-ux-review/21-map-earned-style.png), [selected artwork](progression-ux-review/22-pin-detail.png).

**Source:** [custom_marker_content.dart:192](../flutter/lib/widgets/custom_marker/presentation/custom_marker_content.dart#L192) explicitly uses the group profile picture. Individual markers occupy 48×56 at line 199.

**Better:** Keep a simple group identifier on unselected markers; reveal the actual photo in a selected-pin card with title, group, distance, and presence status. Reuse the useful photo-plus-group pattern already present in the nearby cue, but make it follow the selected pin. Retain clustering in dense areas and consider a list/map switch.

**Trade-off:** Photo markers improve visual browsing but are noisy, small, expensive, and can change with new photos. Group logos help community identity but make items within one group indistinguishable. A hybrid offers recognition at selection time without making every marker a miniature photo card.

### P2. Decorative badges and presence status compete at tiny sizes

**Observed:** The editor calls its arbitrary Star/Leaf/Sun/Spark choice an “Achievement badge.” On the map it becomes a tiny glyph beside the group image. Marking a pin gone adds desaturation and another small glyph; the difference is subtle, particularly for an already mostly monochrome group logo. The Original photo label in details also uses a star, adding another unrelated meaning for the same familiar symbol.

**Evidence:** [Badge controls](progression-ux-review/13-editor-changed.png), [gone marker near map center](progression-ux-review/24-map-gone.png), [Original star in details](progression-ux-review/22-pin-detail.png).

**Source:** [decorative badge:136](../flutter/lib/widgets/custom_marker/presentation/custom_marker_content.dart#L136) is 9×scale; [gone glyph:160](../flutter/lib/widgets/custom_marker/presentation/custom_marker_content.dart#L160) is 11×scale. Grayscale affects the image; custom outline and decoration retain their separate treatment.

**Better:** Give factual state a reserved visual channel: a clear gone treatment, a strong selected state, and a text status in the selection card. Keep decoration subordinate. Call freely chosen decoration “Emblem”; use “Earned reward” only for the actual unlock. If it represents a specific achievement, bind the icon to that achievement rather than offering arbitrary glyphs with the same label.

**Trade-off:** Aggressive gone styling can overwhelm the map and hide historical art. Default to clear status on selection plus a restrained but recognizable marker treatment; optionally filter gone pins. Do not rely on color alone, and do not let decoration erase the meaning of state.

### P3. Pin details loses the group context that the marker emphasized

**Observed:** Opening a branded group marker reveals the artwork, title, author, date, likes, and presence/update actions, but no visible group name or return path to that group in the content. Users cannot easily connect the map identity and its shared reward style to the artwork they opened.

**Evidence:** [Pin detail](progression-ux-review/22-pin-detail.png).

**Source:** [view_image.dart:83](../flutter/lib/features/pin/presentation/view_image.dart#L83) and [metadata builder:178](../flutter/lib/features/pin/presentation/view_image.dart#L178) assemble title, description, author, and photo date without a group row.

**Better:** Add a compact, linked group identity plus a plain-language status such as “Here · last observed …” where that observation is known. Keep photo origin/history distinct from the achievement emblem. Do not crowd the photo with more permanent overlays.

**Trade-off:** Every metadata row reduces visible photo area. Prioritize group and status over decorative labels, and disclose history details on demand.

## Decisions and trade-offs

| Decision | Option A | Option B | Recommendation |
|---|---|---|---|
| Personal achievement landing | Full milestone catalog: comprehensive but long | Ready rewards + next goals: focused but less aspirational | Focused overview; one-step full catalog |
| Granting XP | Manual claim: deliberate celebration, extra work | Automatic grant: immediate reward, easier to miss | Keep manual initially with Ready queue; test automatic later |
| Profile reward selection | Per-card “Show on profile”: locally convenient | Dedicated Collection preview: clearer identity choice | Collection with actual profile preview; post-claim shortcut |
| Group appearance location | Hidden within rewards: ties style to earning | Dedicated Appearance entry: easy to find | Appearance shows active, unlocked, and locked presets; rewards link into it |
| Editing | Every knob immediately: expressive, demanding | Presets + Advanced: simpler, one extra step | Presets with persistent map-size preview |
| Commit model | Save inactive preset separately: flexible, ambiguous | Apply selected design: obvious common outcome | Apply as primary; optional clearly labeled Save preset |
| Map identity | Artwork photo per marker: distinctive, noisy | Group image per marker: stable, repetitive | Group marker + selected artwork preview |
| Gone pins | Hide by default: uncluttered, loses history | Show everything: complete, noisy | Explicit filter and strong selected-pin status; test default with explorers |

An automatic reward policy would need careful treatment of the existing reward ledger, eligibility changes, and restore semantics. It is not a harmless label-only change. Do not silently alter those rules as part of visual cleanup.

## Proposed information structure

**My progress** opens with one compact level summary, a visible Ready count, one nearest goal per track, and Collection. Each compact goal answers: requirement, remaining effort, reward preview, and next action. Details explain what counts and show the full ladder.

**Group → Appearance** opens with the current map preview and “Applies to every pin in Canal Art Explorers.” An admin sees unlocked presets and an Apply action; members see the same current design and an explanation of who can change it. Locked presets show a preview and a direct link to the next group goal. Advanced editing is one disclosure level below preset selection.

**Map → selected pin** presents artwork, title, linked group, distance when available, and presence/observation status. Rewards remain available through the group, without turning the marker into an achievement dashboard.

The [interactive concept](progression-ux-review/concept.html) demonstrates these relationships using local sample state. Its Apply/Collect buttons do not call the real API. It is a low-fidelity proposal, not a finished visual redesign or tested Flutter patch.

## Suggested order

1. **Clarify existing behavior:** state labels, reward previews, counted units, empty-section removal, active-versus-editing labels, and truthful save feedback.
2. **Reduce scanning:** Ready queue, next-goal summaries, Collection, and a discoverable group Appearance entry.
3. **Improve the design loop:** persistent map preview, presets/advanced controls, shared catalog refresh, clear Apply/Undo semantics.
4. **Validate the map trade-off:** group markers versus photo markers versus a hybrid; test dense areas and gone pins before changing defaults.

## How to validate the proposal

Run short, counterbalanced sessions with newcomers, returning members, and group admins. Ask participants to think aloud; measure tasks without coaching.

| Task | Observe | Proposed success criterion, not a measured result |
|---|---|---|
| Find all rewards available now | Search time, missed ready rewards | Identify both fixture rewards without scrolling the full catalog |
| Explain a reward before collecting | Understand XP, badge, display choice | Predict what collection changes and what remains optional |
| Explain “three places” | Interpret the counted unit | Correctly describe the actual region-based requirement |
| Set a group design | Distinguish preview, saved, and active | Apply intended preset once and verify it on the map |
| Compare two styles at 320px | Preview retention, scrolling, mistakes | Choose without memorizing an offscreen preview |
| Find a specific nearby artwork | Marker versus selected-card recognition | Open the intended artwork with minimal wrong selections |
| Identify a gone pin | Confusion with achievement decoration | Distinguish presence from decoration without relying only on color |

Include one interrupted save, one server rejection, member-versus-admin access, and both light/dark map backgrounds. These are future validation tasks; this review does not claim they all ran.

## Design references

The walkthrough uses [Vercel's Web Design Guidelines skill](https://github.com/vercel-labs/agent-skills/blob/main/skills/web-design-guidelines/SKILL.md). The proposed grouping also follows [progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/): keep common tasks visible and reveal advanced options when needed. Reward previews favor [recognition over recall](https://www.nngroup.com/articles/recognition-and-recall/). Clear draft/active states and Apply feedback support [visibility of system status and user control](https://www.nngroup.com/articles/ten-usability-heuristics/). These principles motivate the alternatives; they do not substitute for testing them with this app's users.
