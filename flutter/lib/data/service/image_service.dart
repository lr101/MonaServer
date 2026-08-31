import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
  return _watchAndFetchImage(repo, userId, isUser);
}

@riverpod
Stream<Uint8List?> getUserProfileSmall(Ref ref, String userId) {
  final repo = ref.watch(userImageSmallRepoProvider);
  final isUser = ref.watch(userIdProvider) == userId;
  return _watchAndFetchImage(repo, userId, isUser);
}

@riverpod
Stream<Uint8List?> groupProfilePictureById(Ref ref, String groupId) {
  final userGroup = ref.watch(
    userGroupServiceProvider.select(
      (e) => e.value?.any((f) => f.groupId == groupId),
    ),
  );
  final repo = ref.watch(groupProfileRepoProvider);
  return _watchAndFetchImage(repo, groupId, userGroup ?? false);
}

@riverpod
Stream<Uint8List?> groupProfilePictureSmallById(Ref ref, String groupId) {
  final userGroup = ref.watch(
    userGroupServiceProvider.select(
      (e) => e.value?.any((f) => f.groupId == groupId),
    ),
  );
  final repo = ref.watch(groupProfileSmallRepoProvider);
  return _watchAndFetchImage(repo, groupId, userGroup ?? false);
}

@riverpod
Stream<Uint8List?> groupPinImageById(Ref ref, String groupId) {
  final userGroup = ref.watch(
    userGroupServiceProvider.select(
      (e) => e.value?.any((f) => f.groupId == groupId),
    ),
  );
  final repo = ref.watch(groupPinImageRepoProvider);
  return _watchAndFetchImage(repo, groupId, userGroup ?? false);
}

Stream<Uint8List?> _watchAndFetchImage(
  IImageRepository repo,
  String id,
  bool keepAlive,
) {
  late final StreamController<Uint8List?> controller;
  StreamSubscription<Uint8List?>? watcher;
  var cancelled = false;
  controller = StreamController<Uint8List?>(
    onListen: () {
      watcher = repo
          .watchImageBytes(id)
          .listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );
      unawaited(
        _fetchImageInBackground(
          repo,
          id,
          keepAlive,
          controller,
          () => !cancelled,
        ),
      );
    },
    onCancel: () async {
      cancelled = true;
      await watcher?.cancel();
      await controller.close();
    },
  );
  return controller.stream;
}

Future<void> _fetchImageInBackground(
  IImageRepository repo,
  String id,
  bool keepAlive,
  StreamController<Uint8List?> controller,
  bool Function() isActive,
) async {
  try {
    await repo.fetchImage(id, keepAlive);
  } catch (error, stackTrace) {
    if (isActive() && !controller.isClosed) {
      controller.addError(error, stackTrace);
    }
  }
}

class PinImageInfo {
  PinImageInfo({
    required this.image,
    required this.width,
    required this.height,
  });
  final Uint8List image;
  final int width;
  final int height;
}

@riverpod
Stream<PinImageInfo?> getPinImageInfo(Ref ref, String pinId) {
  final repo = ref.watch(pinImageRepositoryProvider);
  return _watchAndFetchImage(repo, pinId, false).asyncMap((e) async {
    if (e == null) return null;
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(e, (ui.Image img) {
      completer.complete(img);
    });
    final res = await completer.future;
    return PinImageInfo(image: e, width: res.width, height: res.height);
  });
}
