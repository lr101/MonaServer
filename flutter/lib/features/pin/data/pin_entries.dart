import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/entity/user_pins_entity.dart';
import 'package:buff_lisa/data/repository/pin_photo_history_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/repository/user_pins_repository.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';

int countUniqueContributedSticks(Iterable<PinEntity> entries) =>
    entries.map((entry) => entry.pinId).toSet().length;

final profilePhotoHistoryRevisionProvider = StreamProvider<int>((ref) {
  return ref.watch(pinPhotoHistoryRepositoryProvider).watchChanges();
});

/// Projects photographs into posts while retaining one PinEntity per map place.
List<PinEntity> buildPinEntries(
  List<PinEntity> pins,
  Map<String, List<PinPhotoDto>> photosByPin, {
  String? contributorId,
  Set<String> hiddenUserIds = const {},
}) {
  final entries = <PinEntity>[];
  for (final pin in pins) {
    if (!hiddenUserIds.contains(pin.creator) &&
        (contributorId == null || pin.creator == contributorId)) {
      entries.add(pin);
    }
    for (final photo in photosByPin[pin.pinId] ?? const <PinPhotoDto>[]) {
      if (photo.isOriginal ||
          (photo.contributorId != null &&
              hiddenUserIds.contains(photo.contributorId)) ||
          (contributorId != null && photo.contributorId != contributorId)) {
        continue;
      }
      entries.add(pin.withPhotoUpdate(photo));
    }
  }
  entries.sort((a, b) {
    final byDate = b.creationDate.compareTo(a.creationDate);
    return byDate != 0 ? byDate : b.entryId.compareTo(a.entryId);
  });
  return entries;
}

Stream<List<PinEntity>> _entries(
  Ref ref,
  List<PinEntity> pins, {
  String? contributorId,
}) async* {
  final hiddenPosts = ref.watch(hiddenPostsServiceProvider);
  final hiddenUserIds = ref.watch(hiddenUserServiceProvider).toSet();
  final visiblePins = pins
      .where((pin) => !hiddenPosts.contains(pin.pinId))
      .toList();
  final photos = <String, List<PinPhotoDto>>{};
  if (visiblePins.isNotEmpty) {
    final expiry = Timer(const Duration(minutes: 45), ref.invalidateSelf);
    ref.onDispose(expiry.cancel);
  }
  List<PinEntity> project() => buildPinEntries(
    visiblePins,
    photos,
    contributorId: contributorId,
    hiddenUserIds: hiddenUserIds,
  );

  yield project();
  Future<(int, List<PinPhotoDto>)> load(int index) async {
    try {
      return (
        index,
        await ref.read(pinApiProvider).getPinPhotos(visiblePins[index].pinId) ??
            const <PinPhotoDto>[],
      );
    } catch (_) {
      // A photo-history failure should not hide an existing pin.
      return (index, const <PinPhotoDto>[]);
    }
  }

  const maxConcurrent = 8;
  final pending = <int, Future<(int, List<PinPhotoDto>)>>{};
  var nextIndex = 0;
  while (nextIndex < visiblePins.length || pending.isNotEmpty) {
    while (nextIndex < visiblePins.length && pending.length < maxConcurrent) {
      pending[nextIndex] = load(nextIndex);
      nextIndex++;
    }
    final (index, history) = await Future.any(pending.values);
    pending.remove(index);
    photos[visiblePins[index].pinId] = history;
  }
  // Keep profile and feed grids stable while histories are loading. Emitting
  // after each request completes made update photos appear a few at a time and
  // repeatedly refreshed the grid. Publish the complete projection together.
  yield project();
}

final userPinEntriesProvider = StreamProvider.family<List<PinEntity>, String>((
  ref,
  userId,
) async* {
  final currentUserId = ref.watch(userIdProvider);
  final isCurrentUser = userId == currentUserId;
  if (isCurrentUser) ref.watch(profilePhotoHistoryRevisionProvider);
  final cached = ref.watch(pinUserServiceProvider(userId)).value ?? [];
  if (isCurrentUser) {
    yield* _currentUserEntries(ref, userId, cached);
    return;
  }

  final pins = {for (final pin in cached) pin.pinId: pin};
  yield buildPinEntries(
    cached
        .where(
          (pin) => !ref.read(hiddenPostsServiceProvider).contains(pin.pinId),
        )
        .toList(),
    const {},
    contributorId: userId,
    hiddenUserIds: ref.read(hiddenUserServiceProvider).toSet(),
  );
  try {
    final api = ref.read(pinApiProvider);
    final remotePins = <String, PinEntity>{};
    const pageSize = 100;
    DateTime? beforeDate;
    String? beforeId;
    while (true) {
      final result = await api.getPinImagesByIds(
        userId: userId,
        withImage: false,
        page: 0,
        size: pageSize,
        beforeCreationDate: beforeDate,
        beforeId: beforeId,
      );
      if (result == null) throw StateError('Pin search returned no response');
      final items = result.items;
      for (final item in items) {
        remotePins[item.id] = PinEntity.fromDto(item, true);
      }
      if (items.length < pageSize) break;
      final last = items.last;
      if (beforeDate == last.creationDate && beforeId == last.id) break;
      beforeDate = last.creationDate;
      beforeId = last.id;
    }
    pins.removeWhere((_, pin) => pin.lastSynced != null);
    pins.addAll(remotePins);
  } catch (_) {
    // Offline profiles still show cached original pins.
  }
  yield* _entries(ref, pins.values.toList(), contributorId: userId);
});

Stream<List<PinEntity>> _currentUserEntries(
  Ref ref,
  String userId,
  List<PinEntity> localPins,
) async* {
  final hiddenPosts = ref.watch(hiddenPostsServiceProvider);
  final hiddenUserIds = ref.watch(hiddenUserServiceProvider).toSet();
  final pinRepository = ref.watch(pinRepositoryProvider);
  final profileRepository = ref.watch(userPinsRepositoryProvider);
  final photoHistoryRepository = ref.watch(pinPhotoHistoryRepositoryProvider);

  List<PinEntity> visible(List<PinEntity> pins) => pins
      .where(
        (pin) =>
            !hiddenPosts.contains(pin.pinId) &&
            !hiddenUserIds.contains(pin.creator),
      )
      .toList();

  Future<List<PinEntity>> project(UserPinsEntity profile) async {
    final profilePinsById = {
      for (final pin in localPins)
        if (pin.lastSynced == null) pin.pinId: pin,
    };
    const batchSize = 500;
    for (var start = 0; start < profile.pins.length; start += batchSize) {
      final pinIds = profile.pins.skip(start).take(batchSize).toList();
      for (final pin in (await pinRepository.getList(
        pinIds,
      )).whereType<PinEntity>()) {
        profilePinsById[pin.pinId] = pin;
      }
    }
    final histories = await photoHistoryRepository.getMultiple(profile.pins);
    final photosByPin = {
      for (final entry in histories.entries) entry.key: entry.value.photos,
    };
    return buildPinEntries(
      visible(profilePinsById.values.toList()),
      photosByPin,
      contributorId: userId,
      hiddenUserIds: hiddenUserIds,
    );
  }

  // Read the local snapshot before emitting so an already-warmed profile is
  // presented as one complete grid instead of originals followed by updates.
  final initialProfile = await profileRepository.get(userId);
  var displayedWatermark = initialProfile?.ttl;
  var displayedPinIds = initialProfile?.pins.toSet() ?? <String>{};
  if (initialProfile == null) {
    // Keep locally authored originals available while the first sync completes.
    yield buildPinEntries(
      visible(localPins),
      const {},
      contributorId: userId,
      hiddenUserIds: hiddenUserIds,
    );
  } else {
    yield await project(initialProfile);
  }

  await for (final profile in profileRepository.watchById(userId)) {
    if (profile == null) continue;
    final profilePinIds = profile.pins.toSet();
    final samePinIndex =
        profilePinIds.length == displayedPinIds.length &&
        profilePinIds.every(displayedPinIds.contains);
    if (profile.ttl == displayedWatermark && samePinIndex) continue;
    final entries = await project(profile);
    displayedWatermark = profile.ttl;
    displayedPinIds = profilePinIds;
    yield entries;
  }
}

final groupPinEntriesProvider = StreamProvider.family<List<PinEntity>, String>(
  (ref, groupId) =>
      _entries(ref, ref.watch(groupDetailsPinsProvider(groupId)).value ?? []),
);

final activePinEntriesProvider = StreamProvider<List<PinEntity>>(
  (ref) => _entries(ref, ref.watch(sortedActivatedPinsProvider).value ?? []),
);
