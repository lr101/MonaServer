# User and group profile alignment

The group profile now uses the same filled Settings gear in the top-right toolbar as the personal profile. It has three content tabs (Members, Pins, Achievements), stats without an action strip, and no repeated member description teaser.

Group settings contains the full group name, description, external link, season details, Share, admin-only Edit, Report and Leave. Share uses the existing native share/clipboard behavior with a labeled settings row. Members without an invite link do not get a Share action. The page guards membership before showing information or actions, including direct settings links.

The long-name toolbar calculation reserves the gear's width. Leave from settings returns home rather than reopening the group just left; pending navigation remains protected. Public/locked non-member group overviews retain their previous behavior.

This supersedes the fourth settings tab and Share placement selected in the earlier [five-option comparison](../ui-achievement-menu-options/README.md). Its screenshots remain historical.

## Evidence

- [Group profile](group-profile.png): 360×740, light.
- [Personal profile](user-profile.png): 360×740, light.
- [Group settings](group-settings.png): 360×740, light.
- [Narrow group profile](group-profile-320-dark.png): 320×740, dark.

The existing local PostgreSQL/PostGIS, Go API on 8081, RustFS on 9100, and connected Flutter Chrome debug server on 4173 were used. Screenshots were captured after real local password sign-in. The dark narrow capture uses a fresh reload after viewport changes to clear a Flutter debug-tooltip overlay assertion; browser journeys use fresh touch contexts and check for uncaught page errors.

16 focused Flutter tests passed, including Share native/clipboard fallback, absent invite links, private/public non-member direct settings access, 320 px / 200% text with a long name, role gates, and Leave root/prior/pending/settings-route recovery. The settings-route and non-member guards were checked with failing tests before their fixes. Focused analysis and `git diff --check` passed.

Both final Playwright journeys passed (57.4 s total), including real sign-in, top-row settings navigation, Share presence only within settings, Leave cancellation, edit/report return navigation, tier details, and real reward collection with temporary-data cleanup. No uncaught browser errors were reported. [Compare the profiles and settings](index.html).

## Inline admin editing

Admins now get the complete edit form directly on Group settings instead of an Edit group navigation row. Photo, name, description, website/link, visibility and admin selection use the existing shared form. Save changes stays on Settings. Sharing, season information, Report and Leave follow the form; regular members retain the read-only settings page and non-members remain blocked.

Admin selection and text drafts are isolated by group. Existing photos that load after opening the form become available for saving, while selected replacement photos remain intact. Ownership transfer removes editing controls from the former admin.
