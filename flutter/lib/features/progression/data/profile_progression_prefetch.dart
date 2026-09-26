import 'dart:async';

typedef ProfileProgressionLoader<T> = Future<T> Function(String id);

void preloadUserProfileProgressions<T>(
  Iterable<String> userIds,
  ProfileProgressionLoader<T> load,
) => _preload(userIds, load);

void preloadGroupProfileProgressions<T>(
  Iterable<String> groupIds,
  ProfileProgressionLoader<T> load,
) => _preload(groupIds, load);

void _preload<T>(Iterable<String> ids, ProfileProgressionLoader<T> load) {
  for (final id in ids.toSet()) {
    if (id.isEmpty) continue;
    try {
      unawaited(load(id).then<void>((_) {}, onError: (_, _) {}));
    } catch (_) {
      // Progression preloading is an optimization; it must not fail the host
      // account or list load.
    }
  }
}
