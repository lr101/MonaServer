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

User and group profiles wait for complete pin and update-photo metadata before
showing the grid. Once metadata arrives, `ImageGrid` mounts visible tiles and a
small nearby cache window. Each tile uses the shared resolver's
thumbnail/full fallback and renewal policy, then fades in as its image arrives.
The gallery remains interactive while slow images load, and refreshes keep the
previous grid visible until replacement metadata arrives.

Group profiles use the same complete index pagination and wait for every pin's
update-photo history before publishing a snapshot. Their grid and opened group
feed share that completed, sorted snapshot, keeping the selected tile index
stable. Missing images finish as tappable unavailable tiles, and late metadata
can retry them.

`remoteImageSourceProvider` supplies URL/cache-key pairs. Known URL metadata
resolves synchronously so remounting a cached tile does not flash a placeholder.
Pin originals use the
existing batch coalescer and supplied-URL registry. Pin photo updates renew with
one shared in-flight history read per pin. User, group, and group-pin artwork
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
