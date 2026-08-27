
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
  repo.fetchImage(userId, isUser); // async
  return repo.watchImageBytes(userId);
}

@riverpod
Stream<Uint8List?> getUserProfileSmall(Ref ref, String userId)  {
  final repo = ref.watch(userImageSmallRepoProvider);
  final isUser = ref.watch(userIdProvider) == userId;
  repo.fetchImage(userId, isUser);
  return repo.watchImageBytes(userId);
}

@riverpod
Stream<Uint8List?> groupProfilePictureById(Ref ref, String groupId)  {
  final userGroup = ref.watch(userGroupServiceProvider.select((e) => e.value?.any((f) => f.groupId == groupId)));
  final repo = ref.watch(groupProfileRepoProvider);
  if (userGroup != null) repo.fetchImage(groupId, userGroup);
  return repo.watchImageBytes(groupId);
}


@riverpod
Stream<Uint8List?> groupProfilePictureSmallById(Ref ref, String groupId)  {
  final userGroup = ref.watch(userGroupServiceProvider.select((e) => e.value?.any((f) => f.groupId == groupId)));
  final repo = ref.watch(groupProfileRepoProvider);
  if (userGroup != null) repo.fetchImage(groupId, userGroup);
  return repo.watchImageBytes(groupId);
}


@riverpod
Stream<Uint8List?> groupPinImageById(Ref ref, String groupId)  {
  final userGroup = ref.watch(userGroupServiceProvider.select((e) => e.value?.any((f) => f.groupId == groupId)));
  final repo = ref.watch(groupPinImageRepoProvider);
  if (userGroup != null) repo.fetchImage(groupId, userGroup);
  return repo.watchImageBytes(groupId);
}

class PinImageInfo {
  PinImageInfo({required this.image, required this.width, required this.height});
  final Uint8List image;
  final int width;
  final int height;
}

@riverpod
Stream<PinImageInfo?> getPinImageInfo(Ref ref, String pinId) async*  {
  final repo = ref.watch(pinImageRepositoryProvider);
  await repo.fetchImage(pinId, false);
  yield* repo.watchImageBytes(pinId).asyncMap((e) async {
    if (e == null) return null;
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(e, (ui.Image img) {
      completer.complete(img);
    });
    final res = await completer.future;
    return PinImageInfo(image: e, width: res.width, height: res.height);
  });
}
