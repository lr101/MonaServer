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
  });

  final IImageRepository repository;
  final String id;
  final String? imageUrl;

  Future<Uint8List?> fetch(
    bool keepAlive,
    ImageRequestCancellation cancellation,
  ) {
    if (imageUrl case final url? when url.isNotEmpty) {
      return repository.fetchImageFromUrl(
        id,
        url,
        keepAlive,
        cancellation: cancellation,
      );
    }
    return repository.fetchImage(id, keepAlive, cancellation: cancellation);
  }
}

/// Byte access for editing, map composition, and explicit offline retention.
/// Display widgets use RemoteImage and its package cache instead.
/// Stages are ordered from smallest/fastest to largest/highest quality; a later
/// stage replaces earlier bytes, while a late earlier stage cannot replace it.
Stream<Uint8List?> _watchImageStages(
  List<_ImageLoadStage> stages, {
  required bool keepAlive,
}) {
  if (stages.isEmpty) return const Stream<Uint8List?>.empty();

  late final StreamController<Uint8List?> controller;
  final watchers = <StreamSubscription<Uint8List?>>[];
  var displayedStage = -1;
  Uint8List? displayedImage;
  var cancelled = false;
  var fetching = false;
  final requestCancellation = ImageRequestCancellation();

  void showImage(int stage, Uint8List? bytes) {
    if (cancelled || stage < displayedStage) return;
    if (bytes == null || bytes.isEmpty) {
      if (bytes == null && stage == 0 && displayedStage < 0) {
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

  Future<void> fetchStages() async {
    if (cancelled || fetching) return;
    fetching = true;
    try {
      for (var index = 0; index < stages.length; index++) {
        if (cancelled) return;
        if (displayedStage > index) continue;
        try {
          showImage(
            index,
            await stages[index].fetch(keepAlive, requestCancellation),
          );
        } catch (error, stackTrace) {
          if (!cancelled) {
            controller.addError(error, stackTrace);
          }
        }
      }
    } finally {
      fetching = false;
    }
  }

  controller = StreamController<Uint8List?>(
    onListen: () {
      for (var index = 0; index < stages.length; index++) {
        final stageIndex = index;
        final stage = stages[stageIndex];
        watchers.add(
          stage.repository
              .watchImageBytes(stage.id)
              .listen(
                (bytes) => showImage(stageIndex, bytes),
                onError: (Object error, StackTrace stackTrace) {
                  if (!cancelled) {
                    controller.addError(error, stackTrace);
                  }
                },
              ),
        );
      }

      unawaited(fetchStages());
    },
    onCancel: () async {
      cancelled = true;
      requestCancellation.cancel();
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
