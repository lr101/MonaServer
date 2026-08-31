# Flutter guidance

## Rebuild-sensitive providers

Providers that feed map markers, images, or other media need stable rebuild
behavior. An unintended provider rebuild can cause an expensive decode or make
the widget briefly show a placeholder. On map screens, that can look like a
marker flickering.

- Subscribe to the stable data stream before starting cache or network work.
  Do not make an async refresh the provider's stream initialization gate.
- Use `select` and stable provider parameters so unrelated state changes do not
  recreate media providers.
- If a database update changes only metadata, preserve the identity of cached
  image bytes. A new `Uint8List` with the same pixels is a new `ImageProvider`
  to Flutter, and an equal byte event should not reach dependent providers.
- Use `gaplessPlayback: true` when an image replacement must not blank the
  previous frame. This is a visual safeguard, not a substitute for preventing
  unnecessary rebuilds and decodes.
- Add a regression test when changing a provider that supplies media. Cover
  both the order of subscription and refresh, and the behavior of metadata-only
  updates.
