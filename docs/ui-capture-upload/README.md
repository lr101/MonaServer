# Floating approval action and reliable capture uploads

The Upload action on the photo approval screen is a centered pill with a
maximum width of 360 px. Its surrounding row is transparent; the form scrolls
behind it and receives trailing clearance based on the measured action height.
The action stays above the keyboard and respects the safe bottom inset.

Saving now shows progress, blocks duplicate submissions, and freezes the
selected group, pin and editable fields. Missing group selection and save/API
failures show persistent local feedback beside the action. A failed attempt
releases the lock for retry, including exceptions before the durable save
starts. Success keeps the lock while the route closes. Existing durable outbox
and photo-update retry/idempotency behavior remain unchanged.

- [Light approval screen](approval-light.png)
- [Narrow dark approval screen](approval-dark.png)
- [Return after successful upload](uploaded-light.png)

Verification uses the local Go API, PostGIS and RustFS with a connected Flutter
Chrome debug session. Playwright signs in, captures a synthetic camera image,
opens approval, and submits through the real API. One journey preserves a title
through rotation and submits with the field focused; another submits an
untitled photo and checks the narrow dark layout. Temporary posts are verified
and deleted. Native widget tests cover keyboard clearance, missing-group
feedback, unexpected-error recovery, storage failure/retry, single submission,
and preserving the success lock during navigation. Existing profile photo
updates and camera/lifecycle behavior are also checked.

A source review found no blocking issues. Browser and synthetic-inset checks
do not establish native Android camera, keyboard or system-bar behavior.

Final checks: 30 focused tests passed across approval, camera controls,
permissions, image processing and lifecycle. Focused analysis reported no
issues. Both capture/upload browser journeys passed together; the untitled
capture also passed after resizing to 320 px and changing to dark appearance.
