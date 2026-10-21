import 'dart:async';
import 'dart:convert';

import 'package:buff_lisa/data/service/photo_library.dart';
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
    this.renewPhoto,
  });

  final SuppliedImageUrlRegistry registry;
  final BatchReadCoalescer batch;
  final Future<List<PinPhotoDto>> Function(String) getPhotos;
  final String namespace;
  final Future<PinPhotoDto?> Function(String)? renewPhoto;
  final Map<String, Future<List<PinPhotoDto>>> _renewals = {};

  FutureOr<PinImageSource?> resolve(PinImageRequest request) {
    if (request.attempt < 2) {
      final small = request.attempt.isEven;
      final kind = small
          ? BatchReadKind.pinImageThumbnail
          : BatchReadKind.pinImage;
      final cacheId = request.photoId == null
          ? request.pinId
          : 'photo:${request.pinId}:${request.photoId}';
      // A neighbouring display may already have renewed this photo. Prefer
      // its shared URL to the older snapshot retained by a grid entry.
      final url =
          registry.lookup(kind, cacheId) ??
          (small ? request.thumbnailUrl : request.imageUrl);
      if (url != null && url.isNotEmpty) return _source(url);
    }
    return _resolveRemote(request);
  }

  PinImageSource _source(String url) {
    final object = Uri.parse(url).replace(query: '', fragment: '');
    return PinImageSource(url: url, cacheKey: '$namespace:$object');
  }

  Future<PinImageSource?> _resolveRemote(PinImageRequest request) async {
    final thumbnail = request.attempt.isEven;
    final renew = request.attempt >= 2;
    String? url;
    if (renewPhoto != null) {
      final cacheId = request.photoId == null
          ? request.pinId
          : 'photo:${request.pinId}:${request.photoId}';
      final kind = thumbnail
          ? BatchReadKind.pinImageThumbnail
          : BatchReadKind.pinImage;
      var shared = registry.lookup(kind, cacheId, renewedOnly: renew);
      if (shared == null) {
        final photo = await renewPhoto!(request.photoId ?? request.pinId);
        if (photo == null) return null;
        for (final id in [
          'photo:${photo.pinId}:${photo.id}',
          if (photo.isOriginal) photo.pinId,
        ]) {
          registry.register(
            BatchReadKind.pinImage,
            id,
            photo.image,
            renewed: true,
          );
          registry.register(
            BatchReadKind.pinImageThumbnail,
            id,
            photo.imageThumbnail,
            renewed: true,
          );
        }
        shared = thumbnail ? photo.imageThumbnail : photo.image;
      }
      return shared == null || shared.isEmpty ? null : _source(shared);
    }
    if (request.photoId != null) {
      if (renew) {
        final cacheId = 'photo:${request.pinId}:${request.photoId}';
        final kind = thumbnail
            ? BatchReadKind.pinImageThumbnail
            : BatchReadKind.pinImage;
        url = registry.lookup(kind, cacheId, renewedOnly: true);
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
                  renewed: true,
                );
                registry.register(
                  BatchReadKind.pinImage,
                  id,
                  photo.image,
                  notify: false,
                  renewed: true,
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
    return _source(url);
  }
}

final imageSessionNamespaceProvider = Provider<String>((ref) {
  final session = watchSession(ref);
  // Persisted logins reuse native disk entries across restarts. A new login
  // gets a different namespace; credentials never appear in cache keys.
  return session.userId != null && session.refreshToken != null
      ? sha256
            .convert(utf8.encode('${session.userId}:${session.refreshToken}'))
            .toString()
      : const Uuid().v4();
});

final pinImageSourcesProvider = Provider<PinImageSources>((ref) {
  return PinImageSources(
    registry: ref.watch(suppliedImageUrlRegistryProvider),
    batch: ref.watch(batchReadCoalescerProvider),
    getPhotos: ref.watch(photoLibraryProvider).refreshHistory,
    renewPhoto: ref.watch(photoLibraryProvider).renew,
    namespace: ref.watch(imageSessionNamespaceProvider),
  );
});

final pinImageSourceProvider = FutureProvider.autoDispose
    .family<PinImageSource?, PinImageRequest>((ref, request) {
      return ref.watch(pinImageSourcesProvider).resolve(request);
    }, retry: (_, _) => null);
