import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_service.g.dart';

@riverpod
Stream<Uint8List?> getUserProfile(Ref ref, String userId) {
  final repo = ref.watch(userImageRepoProvider);
  final isUser = ref.watch(userIdProvider) == userId;
  return _watchImageStages([
    _ImageLoadStage(repository: repo, id: userId),
  ], keepAlive: isUser);
}

/// Loads the 100 px profile variant first, then replaces it with the regular
/// profile image when that download completes. Both stages use the shared
/// repositories and their persistent caches.
final getUserProfileProgressiveProvider = StreamProvider.autoDispose
    .family<Uint8List?, String>((ref, userId) {
      final smallRepo = ref.watch(userImageSmallRepoProvider);
      final fullRepo = ref.watch(userImageRepoProvider);
      final isUser = ref.watch(userIdProvider) == userId;
      return _watchImageStages(
        [
          _ImageLoadStage(repository: smallRepo, id: userId),
          _ImageLoadStage(repository: fullRepo, id: userId),
        ],
        keepAlive: isUser,
        emitNullValues: false,
      );
    });

@riverpod
Stream<Uint8List?> getUserProfileSmall(Ref ref, String userId) {
  final repo = ref.watch(userImageSmallRepoProvider);
  final isUser = ref.watch(userIdProvider) == userId;
  return _watchImageStages([
    _ImageLoadStage(repository: repo, id: userId),
  ], keepAlive: isUser);
}

@riverpod
Stream<Uint8List?> groupProfilePictureById(Ref ref, String groupId) {
  final userGroup = ref.watch(
    userGroupServiceProvider.select(
      (e) => e.value?.any((f) => f.groupId == groupId),
    ),
  );
  final repo = ref.watch(groupProfileRepoProvider);
  return _watchImageStages([
    _ImageLoadStage(repository: repo, id: groupId),
  ], keepAlive: userGroup ?? false);
}

/// Uses the server's tiny group profile image as an immediate preview and
/// upgrades it from the regular profile image through the same image cache.
final groupProfilePictureProgressiveByIdProvider = StreamProvider.autoDispose
    .family<Uint8List?, String>((ref, groupId) {
      final userGroup = ref.watch(
        userGroupServiceProvider.select(
          (groups) => groups.value?.any((group) => group.groupId == groupId),
        ),
      );
      final smallRepo = ref.watch(groupProfileSmallRepoProvider);
      final fullRepo = ref.watch(groupProfileRepoProvider);
      return _watchImageStages(
        [
          _ImageLoadStage(repository: smallRepo, id: groupId),
          _ImageLoadStage(repository: fullRepo, id: groupId),
        ],
        keepAlive: userGroup ?? false,
        emitNullValues: false,
      );
    });

@riverpod
Stream<Uint8List?> groupProfilePictureSmallById(Ref ref, String groupId) {
  final userGroup = ref.watch(
    userGroupServiceProvider.select(
      (e) => e.value?.any((f) => f.groupId == groupId),
    ),
  );
  final repo = ref.watch(groupProfileSmallRepoProvider);
  return _watchImageStages([
    _ImageLoadStage(repository: repo, id: groupId),
  ], keepAlive: userGroup ?? false);
}

/// Uses a presigned URL already returned by a group search response.
final groupProfilePictureSmallByUrlProvider = StreamProvider.autoDispose
    .family<Uint8List?, ({String groupId, String url})>((ref, image) {
      final userGroup = ref.watch(
        userGroupServiceProvider.select(
          (e) => e.value?.any((f) => f.groupId == image.groupId),
        ),
      );
      final repo = ref.watch(groupProfileSmallRepoProvider);
      return _watchImageStages([
        _ImageLoadStage(
          repository: repo,
          id: image.groupId,
          imageUrl: image.url,
        ),
      ], keepAlive: userGroup ?? false);
    });

@riverpod
Stream<Uint8List?> groupPinImageById(Ref ref, String groupId) {
  final userGroup = ref.watch(
    userGroupServiceProvider.select(
      (e) => e.value?.any((f) => f.groupId == groupId),
    ),
  );
  final repo = ref.watch(groupPinImageRepoProvider);
  return _watchImageStages([
    _ImageLoadStage(repository: repo, id: groupId),
  ], keepAlive: userGroup ?? false);
}

class _ImageLoadStage {
  const _ImageLoadStage({
    required this.repository,
    required this.id,
    this.imageUrl,
    this.fetchEndpointWhenUrlMissing = true,
  });

  final IImageRepository repository;
  final String id;
  final String? imageUrl;
  final bool fetchEndpointWhenUrlMissing;

  bool get shouldLoad =>
      imageUrl?.isNotEmpty == true || fetchEndpointWhenUrlMissing;

  Future<Uint8List?> fetch(bool keepAlive) {
    if (imageUrl case final url? when url.isNotEmpty) {
      return repository.fetchImageFromUrl(id, url, keepAlive);
    }
    if (fetchEndpointWhenUrlMissing) {
      return repository.fetchImage(id, keepAlive);
    }
    return Future<Uint8List?>.value();
  }
}

/// Watches and fetches every remote image through the shared image repositories.
/// Stages are ordered from smallest/fastest to largest/highest quality; a later
/// stage replaces earlier bytes, while a late earlier stage cannot replace it.
Stream<Uint8List?> _watchImageStages(
  List<_ImageLoadStage> stages, {
  required bool keepAlive,
  bool emitNullValues = true,
}) {
  if (stages.isEmpty) return const Stream<Uint8List?>.empty();

  late final StreamController<Uint8List?> controller;
  final watchers = <StreamSubscription<Uint8List?>>[];
  var displayedStage = -1;
  Uint8List? displayedImage;
  var stageFailed = false;
  var cancelled = false;

  void showImage(int stage, Uint8List? bytes) {
    if (cancelled || stage < displayedStage) return;
    if (bytes == null || bytes.isEmpty) {
      if (bytes == null && emitNullValues && stage == 0 && displayedStage < 0) {
        displayedStage = stage;
        controller.add(null);
      }
      return;
    }
    if (stage == displayedStage && identical(displayedImage, bytes)) return;
    displayedStage = stage;
    displayedImage = bytes;
    controller.add(bytes);
  }

  controller = StreamController<Uint8List?>(
    onListen: () {
      for (var index = 0; index < stages.length; index++) {
        final stageIndex = index;
        final stage = stages[stageIndex];
        if (!stage.shouldLoad) continue;
        watchers.add(
          stage.repository
              .watchImageBytes(stage.id)
              .listen(
                (bytes) => showImage(stageIndex, bytes),
                onError: (Object error, StackTrace stackTrace) {
                  if (!cancelled) {
                    stageFailed = true;
                    controller.addError(error, stackTrace);
                  }
                },
              ),
        );
      }

      unawaited(() async {
        for (var index = 0; index < stages.length; index++) {
          if (cancelled) return;
          if (displayedStage > index) continue;
          try {
            showImage(index, await stages[index].fetch(keepAlive));
          } catch (error, stackTrace) {
            if (!cancelled) {
              stageFailed = true;
              controller.addError(error, stackTrace);
            }
          }
        }

        if (!cancelled &&
            !emitNullValues &&
            displayedImage == null &&
            !stageFailed) {
          controller.add(null);
        }
      }());
    },
    onCancel: () async {
      cancelled = true;
      for (final watcher in watchers) {
        await watcher.cancel();
      }
      await controller.close();
    },
  );
  return controller.stream;
}

@riverpod
Stream<Uint8List?> pinImageBytes(Ref ref, String pinId) {
  final repo = ref.watch(pinImageRepositoryProvider);
  return _watchImageStages([
    _ImageLoadStage(repository: repo, id: pinId),
  ], keepAlive: false);
}

final pinThumbnailBytesProvider = StreamProvider.autoDispose
    .family<Uint8List?, String>((ref, pinId) {
      final repo = ref.watch(pinThumbnailRepositoryProvider);
      return _watchImageStages([
        _ImageLoadStage(repository: repo, id: pinId),
      ], keepAlive: false);
    });

/// Streams a stored photo thumbnail first, then its full image, using the
/// shared pin repositories and their bounded persistent caches.
final pinPhotoProgressiveImageBytesProvider = StreamProvider.autoDispose
    .family<
      Uint8List?,
      ({String photoId, String? thumbnailUrl, String? imageUrl})
    >((ref, photo) {
      final thumbnailRepository = ref.watch(pinThumbnailRepositoryProvider);
      final imageRepository = ref.watch(pinImageRepositoryProvider);
      final cacheId = 'photo:${photo.photoId}';
      return _watchImageStages(
        [
          if (photo.thumbnailUrl case final thumbnailUrl?
              when thumbnailUrl.isNotEmpty)
            _ImageLoadStage(
              repository: thumbnailRepository,
              id: cacheId,
              imageUrl: thumbnailUrl,
              fetchEndpointWhenUrlMissing: false,
            ),
          if (photo.imageUrl case final imageUrl? when imageUrl.isNotEmpty)
            _ImageLoadStage(
              repository: imageRepository,
              id: cacheId,
              imageUrl: imageUrl,
              fetchEndpointWhenUrlMissing: false,
            ),
        ],
        keepAlive: false,
        emitNullValues: false,
      );
    });

/// Fetches the pin's original image after the request has settled.
///
/// Unlike [pinImageBytes], this future does not emit the cache's initial null
/// value while a background request is still in flight. Detail screens use
/// that distinction to avoid showing a missing-image state during loading.
final pinImageForDetailsProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, pinId) async {
      final repo = ref.watch(pinImageRepositoryProvider);
      final cachedImage = await ref.watch(pinImageBytesProvider(pinId).future);
      if (cachedImage != null) return cachedImage;

      return repo.fetchImage(pinId, false);
    });
