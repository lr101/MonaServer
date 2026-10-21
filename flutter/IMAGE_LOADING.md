# Image loading

Display remote media with `RemoteImage`, or the convenience adapters
`RemotePinImage` and `RemoteRoundImage`. Identify the asset with a value-based
`RemoteImageReference`: asset kind, resource ID, optional pin photo ID, supplied
variant URLs, and an optional content revision. Do not download display bytes
through Drift first.

## Display policies

- `thumbnail` stops at the first usable thumbnail. It falls back to the full
  object and then permits one renewed thumbnail/full cycle. Use it for grids,
  selectors, compact avatars, and inset photos. Newly decoded thumbnails fade
  in over 320 ms with an ease-out curve; memory-cached images appear immediately.
- `previewThenFull` starts preview and full variants independently. The decoded
  preview stays visible while the decoded full image fades over it for 320 ms
  with an ease-out curve, then is released. Reduced motion replaces it immediately.
  Each variant permits one metadata renewal, so a missing preview cannot block a full photo and a failed
  full image cannot hide a usable preview. Use it for feed/detail photographs,
  large image-only lists opened from user/group profiles, and profile headers.

The widget bounds decoding to its physical display width (720 pixels for
thumbnail displays, 2160 for full displays). Keep `BoxFit.contain` and centered
alignment for full photographs. Parent gestures remain active while images load
or fail. Late metadata from sync revives failed displays; signature-only updates
do not discard successfully decoded images. The package widget stays mounted
while URL metadata resolves. Replacements, including avatar content revisions,
keep the last decoded frame while loading and if refresh fails. A later sync
can retry a failed replacement without clearing that frame. Reduced motion
disables both thumbnail and replacement fades.

## Resolution and identity

`PhotoLibrary` owns stable original/update photo IDs and persisted last-good
metadata. It hydrates cached records before starting gallery refreshes, and
profile and group views share those records instead of loading photo history
separately for each pin. Gallery discovery uses the authenticated cursor
endpoint and publishes a complete, deterministically sorted snapshot. A failed
refresh leaves the previous snapshot intact. `ImageGrid` mounts visible tiles
and a small nearby cache window, so photo bytes load only as images approach
the viewport. Pull to refresh retries a cold or stale gallery without
remounting the screen. Failed sync discovery scopes are retained for app-resume
retry even when only the map or active feed is mounted.

When a signed URL expires, image consumers request renewal by photo ID. The
owner coalesces concurrent requests, resolves at most 100 URLs per call, and
publishes new URL metadata without changing decoded-image identity. Detail
history and accepted uploads update the same owner, so an older gallery
response cannot remove a newly accepted photo. Confirmed deletion or group
access loss clears the affected persisted records and original/update URL
registry entries. Group removal fences older pages, including previously
unknown pins, so a late response cannot republish a departed group's photos.

`remoteImageSourceProvider` supplies URL/cache-key pairs. Known URL metadata
resolves synchronously so remounting a cached tile does not flash a placeholder.
Pin originals and updates use the shared supplied-URL registry. Update photos
renew by stable photo ID through the batched resolver. User, group, and group-pin artwork
adapt their corresponding batch kinds. All displays share the existing package
cache; `remoteImageProvider(source, cacheWidth: ...)` exposes the same provider
identity for consumers that need an `ImageProvider`.

Cache keys exclude signed query strings and fragments. Pin originals and photo
history references therefore reuse the same cached object when its path matches.
The persisted login scopes cache entries, and a different login replaces the
widget's retained frame as well as its provider identity.

Mutable avatars need more than a stable object path. Successful user and group
uploads call `replaceRemoteImage`: register the returned URLs, publish a new
content revision immediately, and persist that revision in preferences. Mounted
widgets rebuild and native cache entries from before the upload are bypassed,
including after restart. `contentRevision` also allows a caller to supply a
server-side revision when one is available. Changes made on another device at
an unchanged path still depend on the server/browser/package cache freshness;
the current API does not supply an avatar content revision.

## Byte access and offline storage

`image_service.dart` and the byte repositories remain for editing existing
images, custom map-marker/appearance composition, and deliberate offline
retention. A supplied local image or camera draft can still use a memory image.
Photo downloads fetch full bytes only when requested and recheck photo metadata
and contributor ownership before saving.

Package caching is temporary display storage. The OS may evict native files;
the web HTML image loader uses browser caching and does not promise persistent
offline images. Explicitly saved pins and camera outbox drafts retain their
existing durable-storage ownership. Do not replace those stores with the display
cache or promise that a previously viewed image will be available offline.

Regression coverage includes URL/identity resolution, bounded retries, delayed
full-image upgrade, preview retention after failure, renewed full images, late
sync metadata, mutable-avatar replacement, persisted upload revisions, session
isolation, grid mounting, navigation, and the feed/detail light/dark goldens.
