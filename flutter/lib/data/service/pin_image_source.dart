import 'dart:convert';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';
import 'package:uuid/uuid.dart';

/// Attempts are thumbnail, full fallback, renewed thumbnail, renewed full.
/// Bytes, download deduplication and decoding belong to the image package.
typedef PinImageRequest = ({
  String pinId,
  String? photoId,
  String? thumbnailUrl,
  String? imageUrl,
  int attempt,
});

class PinImageSource {
  const PinImageSource({required this.url, required this.cacheKey});
  final String url;
  final String cacheKey;
}

/// Shared URL policy for web and native clients. No database or byte I/O is
/// needed to display an image whose URL has already arrived with metadata.
class PinImageSources {
  PinImageSources({
    required this.registry,
    required this.batch,
    required this.getPhotos,
    required this.namespace,
  });

  final SuppliedImageUrlRegistry registry;
  final BatchReadCoalescer batch;
  final Future<List<PinPhotoDto>> Function(String) getPhotos;
  final String namespace;
  final Map<String, Future<List<PinPhotoDto>>> _renewals = {};

  Future<PinImageSource?> resolve(PinImageRequest request) async {
    final thumbnail = request.attempt.isEven;
    final renew = request.attempt >= 2;
    String? url;
    if (request.photoId != null) {
      if (renew) {
        final cacheId = 'photo:${request.pinId}:${request.photoId}';
        final kind = thumbnail
            ? BatchReadKind.pinImageThumbnail
            : BatchReadKind.pinImage;
        url = registry.lookup(kind, cacheId);
        if (url == null) {
          final photos = await _renewals.putIfAbsent(request.pinId, () async {
            try {
              final photos = await getPhotos(request.pinId);
              for (final photo in photos) {
                final id = 'photo:${request.pinId}:${photo.id}';
                registry.register(
                  BatchReadKind.pinImageThumbnail,
                  id,
                  photo.imageThumbnail,
                  notify: false,
                );
                registry.register(
                  BatchReadKind.pinImage,
                  id,
                  photo.image,
                  notify: false,
                );
              }
              return photos;
            } finally {
              _renewals.remove(request.pinId);
            }
          });
          final photo = photos
              .where((p) => p.id == request.photoId)
              .firstOrNull;
          url = thumbnail ? photo?.imageThumbnail : photo?.image;
        }
      } else {
        url = thumbnail ? request.thumbnailUrl : request.imageUrl;
      }
    } else {
      final kind = thumbnail
          ? BatchReadKind.pinImageThumbnail
          : BatchReadKind.pinImage;
      url = renew ? null : registry.lookup(kind, request.pinId);
      url ??= renew
          ? null
          : (thumbnail ? request.thumbnailUrl : request.imageUrl);
      if (url == null || url.isEmpty) {
        try {
          url = (await batch.readKey(BatchReadKey(kind, request.pinId)))
              .imageUrl;
        } on BatchReadFailure catch (error) {
          if (error.status != 404) rethrow;
        }
      }
    }
    if (url == null || url.isEmpty) return null;
    // A signed URL rotation is metadata, not new pixels. The object path
    // changes when an image is replaced; signatures only change its query.
    final object = Uri.parse(url).replace(query: '', fragment: '');
    return PinImageSource(url: url, cacheKey: '$namespace:$object');
  }
}

final pinImageSourcesProvider = Provider<PinImageSources>((ref) {
  final session = watchSession(ref);
  return PinImageSources(
    registry: ref.watch(suppliedImageUrlRegistryProvider),
    batch: ref.watch(batchReadCoalescerProvider),
    getPhotos: (id) async =>
        await ref.read(pinApiProvider).getPinPhotos(id) ?? [],
    // Persisted logins reuse native disk entries across restarts. A new login
    // gets a different namespace; credentials never appear in cache keys.
    namespace: session.userId != null && session.refreshToken != null
        ? sha256
              .convert(utf8.encode('${session.userId}:${session.refreshToken}'))
              .toString()
        : const Uuid().v4(),
  );
});

final pinImageSourceProvider = FutureProvider.autoDispose
    .family<PinImageSource?, PinImageRequest>((ref, request) {
      return ref.watch(pinImageSourcesProvider).resolve(request);
    }, retry: (_, _) => null);
