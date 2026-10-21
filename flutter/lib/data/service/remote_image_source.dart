import 'dart:async';

import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum RemoteImageKind { pin, user, group, groupPin }

enum RemoteImagePolicy { thumbnail, previewThenFull }

/// Stable value identity. URL signatures are transport metadata, not pixels.
class RemoteImageReference {
  const RemoteImageReference({
    required this.kind,
    required this.id,
    this.photoId,
    this.thumbnailUrl,
    this.imageUrl,
    this.contentRevision = '',
  });
  final RemoteImageKind kind;
  final String id;
  final String? photoId;
  final String? thumbnailUrl;
  final String? imageUrl;
  final String contentRevision;

  @override
  bool operator ==(Object other) =>
      other is RemoteImageReference &&
      kind == other.kind &&
      id == other.id &&
      photoId == other.photoId &&
      thumbnailUrl == other.thumbnailUrl &&
      imageUrl == other.imageUrl &&
      contentRevision == other.contentRevision;
  @override
  int get hashCode =>
      Object.hash(kind, id, photoId, thumbnailUrl, imageUrl, contentRevision);
}

/// Adapts asset-specific metadata endpoints to one package-cache identity.
/// Pin photos retain their shared history renewal; avatars use batch reads.
class RemoteImageSources {
  RemoteImageSources({
    required this.pins,
    required this.registry,
    required this.batch,
  });
  final PinImageSources pins;
  final SuppliedImageUrlRegistry registry;
  final BatchReadCoalescer batch;

  void invalidate(RemoteImageReference image, int attempt, String url) {
    final small = attempt.isEven;
    final kind = switch (image.kind) {
      RemoteImageKind.pin =>
        small ? BatchReadKind.pinImageThumbnail : BatchReadKind.pinImage,
      RemoteImageKind.user =>
        small ? BatchReadKind.userImageSmall : BatchReadKind.userImage,
      RemoteImageKind.group =>
        small ? BatchReadKind.groupImageSmall : BatchReadKind.groupImage,
      RemoteImageKind.groupPin => BatchReadKind.groupPinImage,
    };
    final id = image.photoId == null
        ? image.id
        : 'photo:${image.id}:${image.photoId}';
    registry.invalidate(kind, id, url);
  }

  FutureOr<PinImageSource?> resolve(
    RemoteImageReference image, {
    required int attempt,
    String revision = '',
  }) {
    if (image.kind == RemoteImageKind.pin) {
      final result = pins.resolve((
        pinId: image.id,
        photoId: image.photoId,
        thumbnailUrl: image.thumbnailUrl,
        imageUrl: image.imageUrl,
        attempt: attempt,
      ));
      PinImageSource? withRevision(PinImageSource? source) {
        if (source == null ||
            revision.isEmpty && image.contentRevision.isEmpty) {
          return source;
        }
        return PinImageSource(
          url: source.url,
          cacheKey: '${source.cacheKey}:${image.contentRevision}:$revision',
        );
      }

      return result is Future<PinImageSource?>
          ? result.then(withRevision)
          : withRevision(result);
    }
    final small = attempt.isEven;
    final kind = switch (image.kind) {
      RemoteImageKind.user =>
        small ? BatchReadKind.userImageSmall : BatchReadKind.userImage,
      RemoteImageKind.group =>
        small ? BatchReadKind.groupImageSmall : BatchReadKind.groupImage,
      RemoteImageKind.groupPin => BatchReadKind.groupPinImage,
      RemoteImageKind.pin => throw StateError('Pin adapter handled above'),
    };
    String? url = attempt < 2 ? registry.lookup(kind, image.id) : null;
    url ??= attempt < 2 ? (small ? image.thumbnailUrl : image.imageUrl) : null;
    if (url != null && url.isNotEmpty) return _source(image, url, revision);
    return _resolveRemote(image, kind, revision);
  }

  Future<PinImageSource?> _resolveRemote(
    RemoteImageReference image,
    BatchReadKind kind,
    String revision,
  ) async {
    String? url;
    try {
      url = (await batch.readKey(BatchReadKey(kind, image.id))).imageUrl;
      registry.register(kind, image.id, url, notify: false);
    } on BatchReadFailure catch (error) {
      if (error.status != 404) rethrow;
    }
    if (url == null || url.isEmpty) return null;
    return _source(image, url, revision);
  }

  PinImageSource _source(
    RemoteImageReference image,
    String url,
    String revision,
  ) {
    final object = Uri.parse(url).replace(query: '', fragment: '');
    return PinImageSource(
      url: url,
      cacheKey: '${pins.namespace}:$object:${image.contentRevision}:$revision',
    );
  }
}

final remoteImageSourcesProvider = Provider<RemoteImageSources>(
  (ref) => RemoteImageSources(
    pins: ref.watch(pinImageSourcesProvider),
    registry: ref.watch(pinImageSourcesProvider).registry,
    batch: ref.watch(pinImageSourcesProvider).batch,
  ),
);

/// Upload revisions survive process restarts; old disk entries expire under the
/// package's normal policy. No credentials or signed URLs enter preferences.
class ImageContentRevisions extends Notifier<Map<String, String>> {
  static const prefix = 'remote-image-revision:';
  SharedPreferences? _preferences;
  @override
  Map<String, String> build() {
    watchSession(ref);
    _preferences = null;
    try {
      _preferences = ref.watch(sharedPreferencesProvider);
    } catch (_) {
      // Isolated widget tests do not bootstrap platform preferences.
    }
    return {
      if (_preferences case final prefs?)
        for (final key in prefs.getKeys().where(
          (key) => key.startsWith(prefix),
        ))
          key.substring(prefix.length): prefs.getString(key) ?? '',
    };
  }

  Future<void> replace(String key) async {
    final revision = const Uuid().v4();
    // Publish immediately so a completed upload cannot retain the old frame.
    state = {...state, key: revision};
    if (_preferences case final prefs?) {
      if (!await prefs.setString('$prefix$key', revision)) {
        throw StateError('Could not persist image content revision');
      }
    }
  }
}

final imageContentRevisionsProvider =
    NotifierProvider<ImageContentRevisions, Map<String, String>>(
      ImageContentRevisions.new,
    );

String imageRevisionKey(RemoteImageKind kind, String id) => '${kind.name}:$id';

final remoteImageSourceProvider = FutureProvider.autoDispose
    .family<PinImageSource?, ({RemoteImageReference image, int attempt})>((
      ref,
      request,
    ) {
      final revision = ref.watch(
        imageContentRevisionsProvider.select(
          (values) =>
              values[imageRevisionKey(request.image.kind, request.image.id)] ??
              '',
        ),
      );
      if (request.image.kind == RemoteImageKind.pin) {
        final image = request.image;
        final provider = pinImageSourceProvider((
          pinId: image.id,
          photoId: image.photoId,
          thumbnailUrl: image.thumbnailUrl,
          imageUrl: image.imageUrl,
          attempt: request.attempt,
        ));
        PinImageSource? withRevision(PinImageSource? source) {
          if (source == null ||
              revision.isEmpty && image.contentRevision.isEmpty) {
            return source;
          }
          return PinImageSource(
            url: source.url,
            cacheKey: '${source.cacheKey}:${image.contentRevision}:$revision',
          );
        }

        final state = ref.watch(provider);
        if (state.hasValue) return withRevision(state.value);
        return ref.watch(provider.future).then(withRevision);
      }
      return ref
          .watch(remoteImageSourcesProvider)
          .resolve(request.image, attempt: request.attempt, revision: revision);
    }, retry: (_, _) => null);

/// Listen before resolving. Each event needs a new sequence: equal asset keys
/// are deduplicated by Riverpod, but may represent different sync updates.
final remoteImageMetadataProvider = StreamProvider.autoDispose
    .family<
      ({BatchReadKey key, int sequence}),
      ({RemoteImageKind kind, String id, String? photoId})
    >((ref, image) {
      final registry = ref.watch(pinImageSourcesProvider).registry;
      var sequence = 0;
      final id = image.photoId == null
          ? image.id
          : 'photo:${image.id}:${image.photoId}';
      final kinds = switch (image.kind) {
        RemoteImageKind.pin => {
          BatchReadKind.pinImageThumbnail,
          BatchReadKind.pinImage,
        },
        RemoteImageKind.user => {
          BatchReadKind.userImageSmall,
          BatchReadKind.userImage,
        },
        RemoteImageKind.group => {
          BatchReadKind.groupImageSmall,
          BatchReadKind.groupImage,
        },
        RemoteImageKind.groupPin => {BatchReadKind.groupPinImage},
      };
      return registry.changes
          .where((key) => key.id == id && kinds.contains(key.kind))
          .map((key) => (key: key, sequence: ++sequence));
    });

/// The same provider used by widgets is available to zoom/composition callers.
ImageProvider<Object> remoteImageProvider(
  PinImageSource source, {
  int? cacheWidth,
}) => ResizeImage.resizeIfNeeded(
  cacheWidth,
  null,
  CachedNetworkImageProvider(source.url, cacheKey: source.cacheKey),
);

Future<void> replaceRemoteImage(
  Ref ref, {
  required RemoteImageKind kind,
  required String id,
  String? thumbnailUrl,
  String? imageUrl,
}) async {
  final registry = ref.read(suppliedImageUrlRegistryProvider);
  final kinds = switch (kind) {
    RemoteImageKind.user => (
      BatchReadKind.userImageSmall,
      BatchReadKind.userImage,
    ),
    RemoteImageKind.group => (
      BatchReadKind.groupImageSmall,
      BatchReadKind.groupImage,
    ),
    RemoteImageKind.groupPin => (
      BatchReadKind.groupPinImage,
      BatchReadKind.groupPinImage,
    ),
    RemoteImageKind.pin => (
      BatchReadKind.pinImageThumbnail,
      BatchReadKind.pinImage,
    ),
  };
  registry.register(kinds.$1, id, thumbnailUrl);
  registry.register(kinds.$2, id, imageUrl);
  await ref
      .read(imageContentRevisionsProvider.notifier)
      .replace(imageRevisionKey(kind, id));
}
