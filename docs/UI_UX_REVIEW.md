# Stick-It UI/UX review

Date: 2026-09-26. Scope: consumer Flutter app, including its web interaction model. Admin web is outside this review.

Method: applied the online [Vercel Web Design Guidelines skill](https://github.com/vercel-labs/agent-skills/blob/main/skills/web-design-guidelines/SKILL.md) and its [current checklist](https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md). Translated HTML-specific guidance into Flutter semantics, focus, routing, forms, and interaction requirements. Findings below come from source inspection and call-path tracing, not a live visual audit. The session's preview automation host was unavailable; no services were started and no browser, device, screen-reader, contrast, or responsive-layout measurements were performed. No application behavior was changed.

Priority: P1 = potential loss of work, incorrect core output, or inaccessible core task; P2 = task friction, misleading state, or poor recovery; P3 = lower-impact clarity. Acceptance checks are proposed checks, not tests already run.

## P1 — address first

### 1. Gallery photo location is discarded

`flutter/lib/features/camera/presentation/select_location.dart:33` — the map starts at hardcoded coordinates. When `widget.center` is supplied, the current-position fallback is skipped but the supplied center is never assigned. Camera gallery import extracts EXIF coordinates and passes them through the router, so a geotagged photo still opens at the default location.

**Impact:** users must find the location again or accidentally publish in the wrong place.

**Fix:** prefer supplied photo coordinates, then current location, then an explicitly explained fallback. Show a readable location summary before publishing and let users change it.

**Acceptance:** import a photo geotagged far from the default; the selector opens at that coordinate. With no EXIF and no location permission, show an explained fallback and a usable manual selection path.

### 2. Upload closes before even local persistence completes

`flutter/lib/features/camera/presentation/image_upload.dart:169` — `addPinToGroup(...).then(...)` is launched without awaiting it, then the entire review flow is popped at line 175. The service first writes the pin and image, then performs the request (`flutter/lib/data/service/pin_service.dart:494`). Only API exceptions get the service's failure message; other persistence/transport errors have no recovery in this screen.

**Impact:** the form disappears before a safe handoff is confirmed. Failure leaves users without their editable review screen or a clear task-specific recovery path. Existing success/failure snackbars do not resolve this early-navigation problem.

**Fix:** await a confirmed local save or successful upload before navigating. Preserve the photo and text on failure. Distinguish “Saved, waiting to upload” from “Uploaded”; expose persistent delivery status. Verify actual web persistence before promising offline retention.

**Acceptance:** simulate local image-write failure, API failure, and slow success. Failure preserves the review and permits retry; success creates one pin; queued work remains visibly pending.

### 3. Logout silently destroys pending posts

`flutter/lib/features/settings/presentation/settings.dart:206` — the confirmation says only “Confirm Logout.” Logout calls `cleanup.clearCaches()` (`flutter/lib/data/service/global_data_service.dart:103`), which deletes every local table, including offline pins/images (`flutter/lib/data/service/account_cleanup_service.dart:44`). The separate cache-deletion dialog does warn about unsynced posts; logout does not.

**Impact:** a routine account action can irreversibly erase a user's unsynced photos without informed confirmation.

**Fix:** detect pending posts and show their count plus the explicit consequence before logout. Offer “Stay signed in” and a way to inspect pending uploads. Keep account-isolation cleanup intact.

**Acceptance:** create an unsynced post and initiate logout. The warning identifies pending work; cancel preserves it; confirmed logout follows the documented cleanup policy.

### 4. Map positioning has no accessible zoom/pan alternative

`flutter/lib/features/map_home/presentation/map_home.dart:102` and `flutter/lib/features/camera/presentation/select_location.dart:74` — interaction flags permit only pinch zoom and drag. Neither screen supplies zoom buttons; location selection also lacks a search or coordinate-entry alternative.

**Impact:** precision placement is difficult with a mouse and the core positioning task lacks a keyboard-operated alternative. Wheel and double-click zoom are explicitly excluded.

**Fix:** add labeled zoom controls, keyboard panning, and an accessible location search or coordinate picker. Enable appropriate desktop interactions. Keep the selected position understandable outside the visual map.

**Acceptance:** position and confirm a pin with keyboard only, mouse without a touchpad, and screen-reader navigation. Verify both map screens.

## P2 — usability and recovery

### 5. Group filters are hidden behind an unlabeled gesture target

`flutter/lib/widgets/group_selector/presentation/group_filter.dart:33` — the filter trigger is a `GestureDetector` containing avatars and a small filter icon, with no explicit accessible name, focus handling, or keyboard activation. It sits inside another tappable profile/status container.

**Impact:** filtering is hard to discover and keyboard users cannot reliably reach the control that determines what appears in their feed/map.

**Fix:** use a focusable labeled button such as “Groups: 3 selected,” with a standard touch target. Give selected groups explicit checked semantics and provide a clear way to close the sheet.

**Acceptance:** Tab reaches the trigger; Enter/Space opens it; assistive technology announces its purpose and group selection state.

### 6. “Upload” disappears while composing

`flutter/lib/features/camera/presentation/image_upload.dart:136` — the only submit control is hidden whenever the keyboard is visible; Description uses a newline action.

**Impact:** after writing a description, users must discover that dismissing the keyboard brings submission back.

**Fix:** keep a visible publish action above the keyboard or in the app bar. Label the screen “Review pin” and the action according to whether it uploads or queues work.

**Acceptance:** on a small phone with the description field focused, the primary action remains visible and reachable without obscuring the field.

### 7. Back navigation discards unfinished composition

`flutter/lib/features/camera/presentation/image_upload.dart:60` and `flutter/lib/widgets/group_edit_template/presentation/group_edit_template.dart:66` — photo review and group editing have no dirty-state navigation guard or draft restoration. The reviewed app source contains no `PopScope`, `WillPopScope`, or browser unload guard.

**Impact:** an accidental Back loses the photo review text or group edits with no warning.

**Fix:** preserve a local draft or confirm discarding changed content. Cover app back navigation and supported browser navigation; avoid warning for unchanged forms.

**Acceptance:** edit text, then use app Back, Android Back, and browser Back. Users can stay and retain edits, or explicitly discard them.

### 8. Notification setting reports permission that was not granted

`flutter/lib/features/settings/presentation/state/notification_state.dart:14` — enabling awaits `requestPermission()` but ignores its boolean result and unconditionally sets `AsyncData(true)`. The initial state reads OS permission while disabling changes app preferences/topic subscription, conflating two different states.

**Impact:** users are told notifications are enabled after denying permission, and the setting can disagree with their saved preference when revisited.

**Fix:** represent app preference and OS permission separately. Reflect the actual request result; explain denial and provide an OS-settings path where appropriate. Do not claim the app can revoke OS permission.

**Acceptance:** deny permission, revisit settings, and restart. The displayed state stays truthful. Test an OS-authorized account with app notifications disabled.

### 9. “Current Password” is required but unused

`flutter/lib/features/settings/presentation/sub_widgets/change_password.dart:47` and `:123` — current password receives only format validation. The submit path sends only the new password; the current field is never read for authentication.

**Impact:** users waste effort entering a credential and receive a false impression that it was verified. Forgotten-current-password users can be blocked by a field the actual request does not need.

**Fix:** align the screen with the intended account policy: remove the field if the authenticated session authorizes this action, or implement actual reauthentication. Add password autofill hints and named visibility controls.

**Acceptance:** the screen requires only inputs actually used, and an incorrect current password cannot appear to have been verified.

### 10. Every sync failure is called “Offline”

`flutter/lib/features/navigation/presentation/syncing_preview.dart:16` — all `SyncState.failed` outcomes produce “Offline,” without cause, retry, or pending-upload count.

**Impact:** users can blame their connection for server failures and cannot tell whether their photos are safe or what to do next.

**Fix:** show “Sync failed” unless offline status is known; expose retry and pending-work status. Use actionable errors and accessible status announcements.

**Acceptance:** distinguish disconnected network from a reachable API returning an error; retry gives feedback and does not duplicate submissions.

### 11. Group search can display results from an older query

`flutter/lib/features/group_search/presentation/group_search.dart:81` — requests append their response without checking whether the search term or request generation changed. The one-second debounce at line 142 also makes the list feel slow to respond.

**Impact:** a slow earlier query can populate the list after a newer search, making results appear irrelevant or inconsistent.

**Fix:** capture query and generation when requesting; discard stale responses and fence disposal. Use a shorter debounce and visible searching feedback; give the search field a clear purpose label.

**Acceptance:** delay query A, complete query B, then complete A. Only B's results remain. Clearing search during a request also works.

### 12. New users get an unhelpful group empty state

`flutter/lib/features/group_user_list/presentation/user_groups.dart:41` — missing/error data becomes `[]`; the shared scaffold uses the pagination package's generic state builders. Finding a group is buried in a plus-menu (`flutter/lib/features/group_user_list/presentation/pop_up_menu_create_group.dart:11`).

**Impact:** “not loaded,” “failed,” and “no groups yet” can appear equivalent, and the first useful action is hidden.

**Fix:** render distinct loading, failure-with-retry, and empty states. Empty groups should offer “Find groups” and “Create group” directly. An empty filtered feed should offer “Change filters,” rather than the same generic no-items treatment.

**Acceptance:** separately exercise first-time account, group request failure, and all groups filtered out; each screen explains its state and offers the appropriate next action.

### 13. Group privacy is expressed only with lock icons

`flutter/lib/widgets/group_edit_template/presentation/group_edit_template.dart:194` — “Group privacy” is followed by an open-lock icon, switch, and closed-lock icon. There is no explicit selected-value label or explanation of discoverability and membership consequences.

**Impact:** users must infer which state is public/private and what it means before sharing content.

**Fix:** use labeled “Public” / “Private” choices, explaining the actual discovery and joining rules from the contract. Expose the current value to assistive technology.

**Acceptance:** users can identify the selected privacy setting and its consequences without interpreting icons; screen readers announce the selected option.

### 14. Account-deletion code delivery has no recovery action

`flutter/lib/features/settings/presentation/sub_widgets/delete_account.dart:27` — code delivery happens once on opening the screen, with transient snackbar feedback. There is no resend action or persistent delivery-failure state. The form also uses a non-scrollable Column at line 49.

**Impact:** users whose email is delayed or whose initial request fails must leave and reopen the page. Small-height/large-text layouts with the keyboard need visual overflow verification.

**Fix:** show persistent delivery feedback and an explicit resend action with cooldown, distinguish invalid/expired codes, and make the form scrollable. Preserve code entry where appropriate.

**Acceptance:** fail the initial send, resend successfully without leaving, then submit an expired code and recover. Check small phones and enlarged text with the keyboard open.

## P3 — clarity and web conventions

### 15. Settings contain a dead option and an ambiguous switch

`flutter/lib/features/settings/presentation/settings.dart:39` — Language is styled as navigation but has no handler. At line 46, “Toggle theme” shows the switch enabled for light mode alongside a dark-mode icon.

**Fix:** display language as noninteractive information until selection works. Use “Dark mode” with matching boolean semantics or explicit Light/Dark/System choices.

**Acceptance:** every navigation-style row opens something; the theme label, icon, and state agree.

### 16. Main tabs do not participate in browser navigation

`flutter/lib/features/navigation/presentation/navigation.dart:92` — tab selection updates a provider and PageView rather than the route. Groups, camera, map, feed, and profile share `/home`.

**Impact:** users cannot bookmark/share a particular tab, and browser Back does not retrace tab changes.

**Fix:** represent tabs in routes, retaining per-tab state where useful. Define consistent Back behavior before implementation.

**Acceptance:** opening a tab URL directly selects it; reload preserves that tab; browser Back follows the agreed navigation model.

## Suggested implementation order

1. Correct photo coordinates, confirm upload handoff, and warn about pending work at logout.
2. Make map controls and group filtering keyboard/screen-reader usable.
3. Preserve unfinished forms and provide truthful upload, sync, and permission states.
4. Improve group onboarding/search, privacy choices, account recovery, and settings labels.
5. Add route-aware tabs and perform live visual/accessibility verification.

## Live verification still required

Use the repository's disposable local stack and scenarios before claiming browser validation. Check 360px phone, landscape phone, tablet, and desktop layouts; 200% text scale; keyboard-only navigation; TalkBack and browser screen readers; both themes; denied camera/location/notification permissions; empty groups; delayed responses; and failed uploads. Measure actual contrast and target sizes rather than inferring them from icon dimensions. Do not treat this source review as evidence that camera capture, object storage, PostGIS, or production integration behavior was exercised.
