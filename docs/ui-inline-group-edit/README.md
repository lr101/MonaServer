# Inline group editing

Group admins now get the existing edit form directly within Group settings. It includes photo, name, description, link, visibility and admin selection; Save changes stays on Settings. Season details, sharing, Report and Leave follow the form. Regular members retain read-only information and non-members remain blocked.

The shared form has an embedded layout without a second Scaffold or app bar. Standalone creation/editing retains its existing shell. The group photo can arrive asynchronously without blocking saving or overwriting a replacement selected by the user. Admin selection is local to the form and text drafts reset when switching group IDs. Transferring ownership changes the former admin's settings view to read-only.

21 focused Flutter tests passed. They cover direct inline save, 320 px / 200% text, ownership transfer, cross-group draft/admin isolation, delayed photo initialization, replacement photo preservation, standalone creation initialization, role/privacy guards, sharing fallback and Leave navigation recovery. Focused analysis reports no issues, and `git diff --check` passes. The delayed-photo and cross-group draft issues were reproduced with failing tests before their fixes.

Both final Playwright journeys passed (about one minute total): member settings/catalog navigation and a real admin form update through the local API, staying on Settings, report navigation, reward collection, and temporary-data cleanup. The save test asserts the returned API name matches the edited value. Services: local PostgreSQL/PostGIS, Go API on 8081, RustFS on 9100, and connected Flutter Chrome debug on 4173. Browser checks do not establish native Android behavior.

Rendered evidence: [admin form](admin-settings-top.png), [save and actions](admin-settings-actions.png), and [actual saved edit](admin-settings-saved.png). The comparison uses the app's existing art asset; the save journey uses a transparent fixture photo.
