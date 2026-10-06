import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/entity/user_pins_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/repository/group_repository.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/pending_pin_repository.dart';
import 'package:buff_lisa/data/repository/pin_photo_history_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/repository/user_pins_repository.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/pending_pin_uploader.dart';
import 'package:buff_lisa/features/progression/data/group_achievement_provider.dart';
import 'package:buff_lisa/features/progression/data/group_xp_provider.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'syncing_service.g.dart';

enum SyncState { init, syncing, finished, failed }

Set<String> removedUserGroupIds(
  Iterable<String> localGroupIds,
  SyncDto response,
) {
  final remoteGroupIds = response.groupUpdates
      .map((groupUpdate) => groupUpdate.group.id)
      .toSet();
  final removed = localGroupIds.toSet();
  removed.removeWhere(remoteGroupIds.contains);
  return removed;
}

@riverpod
class SyncingService extends _$SyncingService {
  late PinsApi _pinsApi;
  late IGroupRepository _groupRepository;
  late IPinRepository _pinRepository;

  @override
  SyncState build() {
    _pinsApi = ref.watch(pinApiProvider);
    _groupRepository = ref.watch(groupRepositoryProvider);
    _pinRepository = ref.watch(pinRepositoryProvider);
    return SyncState.init;
  }

  Future<void> syncToBackend({bool Function()? isActive}) async {
    final owner = ref;
    final accountIsCurrent = accountOperation(owner);
    bool isCurrent() =>
        owner.mounted && accountIsCurrent() && (isActive?.call() ?? true);
    if (!isCurrent()) return;
    state = SyncState.syncing;
    const key = GlobalDataRepository.lastSeenKey;
    final lastSeen = ref.read(lastSeenProvider(key));
    try {
      Object? firstError;
      StackTrace? firstStackTrace;
      Set<String> deletedPinIds = const {};
      try {
        deletedPinIds = await _syncFromBackend(lastSeen, isCurrent);
      } catch (error, stackTrace) {
        firstError = error;
        firstStackTrace = stackTrace;
      }
      if (!isCurrent()) return;
      try {
        // A failed remote pull must not prevent an already-saved post from
        // getting its next upload attempt on app open or resume.
        await _syncOfflinePins(isCurrent);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
      if (!isCurrent()) return;
      if (firstError == null) {
        try {
          await _syncCurrentUserProfile(deletedPinIds, isCurrent);
        } catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      }
      if (!isCurrent()) return;
      if (firstError != null) {
        Error.throwWithStackTrace(firstError, firstStackTrace!);
      }
      ref.read(lastSeenProvider(key).notifier).setLastSeenNow();
      state = SyncState.finished;
    } catch (e) {
      if (!isCurrent()) return;
      state = SyncState.failed;
      rethrow;
    }
  }

  Future<Set<String>> _syncFromBackend(
    DateTime? lastSeen,
    bool Function() isCurrent,
  ) async {
    if (!isCurrent()) return const {};
    final groupRepository = _groupRepository;
    final pinRepository = _pinRepository;
    final response = await _pinsApi.callSync(lastSeen: lastSeen);
    if (!isCurrent()) return const {};
    if (response == null) {
      throw Exception("no sync possible");
    }

    final localUserGroups = await groupRepository.watchUserGroups().first;
    if (!isCurrent()) return const {};
    for (final groupId in removedUserGroupIds(
      localUserGroups.map((group) => group.groupId),
      response,
    )) {
      if (!isCurrent()) return const {};
      await groupRepository.delete(groupId);
      if (!isCurrent()) return const {};
      await pinRepository.updateKeepAlive(groupId, false, true);
    }

    if (!isCurrent()) return const {};
    if (response.deletedPins.isNotEmpty) {
      final affectedGroups = <String>{};
      for (final pinId in response.deletedPins) {
        if (!isCurrent()) return const {};
        final deletedPin = await pinRepository.get(pinId);
        if (!isCurrent()) return const {};
        if (deletedPin != null) affectedGroups.add(deletedPin.groupId);
      }
      await pinRepository.deleteMultiple(response.deletedPins);
      for (final groupId in affectedGroups) {
        ref.invalidate(groupAchievementsProvider(groupId));
      }
    }

    for (final groupUpdate in response.groupUpdates) {
      if (!isCurrent()) return const {};
      final groupDto = groupUpdate.group;
      registerGroupImageUrls(ref, groupDto);
      final existingGroup = await groupRepository.get(groupDto.id);
      if (!isCurrent()) return const {};
      final syncedPinStyle = groupDto.pinStyle?.value ?? 'classic';
      final achievementStateChanged =
          existingGroup == null ||
          existingGroup.pinStyle != syncedPinStyle ||
          (groupDto.lastUpdated != null &&
              groupDto.lastUpdated != existingGroup.lastUpdated);
      await groupRepository.put(
        GroupEntity.fromGroupDto(
          groupDto,
          false,
          true,
          keepAlive: true,
          isActivated: existingGroup?.isActivated ?? true,
        ),
      );

      if (achievementStateChanged) {
        ref.invalidate(groupAchievementsProvider(groupDto.id));
      }

      if (!isCurrent()) return const {};
      if (groupUpdate.pinsAdded.isNotEmpty) {
        for (final pin in groupUpdate.pinsAdded) {
          registerPinImageUrl(ref, pin);
        }
        await pinRepository.putMultiple(
          groupUpdate.pinsAdded
              .map((pin) => PinEntity.fromDto(pin, false))
              .toList(),
        );
        final creatorIds = groupUpdate.pinsAdded
            .map((pin) => pin.creationUser)
            .toSet();
        for (final creatorId in creatorIds) {
          ref.invalidate(userXpProvider(creatorId));
        }
        ref.invalidate(groupProgressionProvider(groupDto.id));
        ref.invalidate(groupAchievementsProvider(groupDto.id));
      }

      if (!isCurrent()) return const {};
      prefetchGroupMediaInBackground(ref, groupDto, keepAlive: true);
    }
    return response.deletedPins.toSet();
  }

  Future<void> _syncCurrentUserProfile(
    Set<String> deletedPinIds,
    bool Function() isCurrent,
  ) async {
    if (!isCurrent()) return;
    final userId = ref.read(userIdProvider);
    if (userId.isEmpty) return;

    final profileRepository = ref.read(userPinsRepositoryProvider);
    final historyRepository = ref.read(pinPhotoHistoryRepositoryProvider);
    final existingProfile = await profileRepository.get(userId);
    if (!isCurrent()) return;
    final cachedProfilePins = <PinEntity>[];
    if (existingProfile != null) {
      const batchSize = 500;
      for (
        var start = 0;
        start < existingProfile.pins.length;
        start += batchSize
      ) {
        final pinIds = existingProfile.pins
            .skip(start)
            .take(batchSize)
            .toList();
        cachedProfilePins.addAll(
          (await _pinRepository.getList(pinIds)).whereType<PinEntity>(),
        );
      }
    }
    if (!isCurrent()) return;
    final cachedProfilePinIds = cachedProfilePins
        .map((pin) => pin.pinId)
        .toSet();
    final hasMissingProfilePins =
        existingProfile != null &&
        existingProfile.pins.any(
          (pinId) => !cachedProfilePinIds.contains(pinId),
        );

    // Store the start of this walk as the next incremental watermark. If a pin
    // changes while pages are loading, the next sync will include that change.
    final syncStartedAt = DateTime.now().toUtc();
    final updatedAfter = hasMissingProfilePins ? null : existingProfile?.ttl;
    final profileDeletedPinIds = {...deletedPinIds};
    final profilePinIds = updatedAfter == null
        ? <String>{}
        : (existingProfile?.pins.toSet() ?? <String>{});
    profilePinIds.removeAll(profileDeletedPinIds);

    final changedPins = <String, PinWithOptionalImageDto>{};
    const pageSize = 100;
    DateTime? beforeDate;
    String? beforeId;
    for (var page = 0; ; page++) {
      if (!isCurrent()) return;
      final response = await _pinsApi.getPinImagesByIds(
        userId: userId,
        withImage: false,
        page: page,
        size: pageSize,
        updatedAfter: updatedAfter,
        beforeCreationDate: beforeDate,
        beforeId: beforeId,
      );
      if (!isCurrent()) return;
      if (response == null) {
        throw StateError('Profile pin sync returned no response');
      }
      profileDeletedPinIds.addAll(response.deleted);
      for (final pin in response.items) {
        if (profileDeletedPinIds.contains(pin.id)) continue;
        changedPins[pin.id] = pin;
        profilePinIds.add(pin.id);
      }
      final items = response.items;
      if (items.length < pageSize) break;
      final last = items.last;
      if (beforeDate == last.creationDate && beforeId == last.id) break;
      beforeDate = last.creationDate;
      beforeId = last.id;
    }
    profilePinIds.removeAll(profileDeletedPinIds);

    if (!isCurrent()) return;
    final now = DateTime.now().toUtc();
    final photoCache = await historyRepository.getMultiple(profilePinIds);
    if (!isCurrent()) return;
    final historyIdsToRefresh = <String>{...changedPins.keys};
    for (final pinId in profilePinIds) {
      final cachedHistory = photoCache[pinId];
      if (cachedHistory == null ||
          now.difference(cachedHistory.fetchedAt) >=
              const Duration(minutes: 45)) {
        historyIdsToRefresh.add(pinId);
      }
    }

    final photosByPin = <String, List<PinPhotoDto>>{};
    final idsToRefresh = historyIdsToRefresh.toList();
    const maxConcurrentHistoryRequests = 8;
    for (
      var start = 0;
      start < idsToRefresh.length;
      start += maxConcurrentHistoryRequests
    ) {
      if (!isCurrent()) return;
      final batch = idsToRefresh.skip(start).take(maxConcurrentHistoryRequests);
      final results = await Future.wait(
        batch.map((pinId) async {
          try {
            final photos = await _pinsApi.getPinPhotos(pinId);
            return MapEntry(pinId, photos ?? const <PinPhotoDto>[]);
          } catch (_) {
            // Photo history is best-effort for profile publication. Keeping a
            // failed pin out of this write leaves its cached history intact;
            // uncached pins will be retried the next time profile sync runs.
            return null;
          }
        }),
      );
      photosByPin.addEntries(
        results.whereType<MapEntry<String, List<PinPhotoDto>>>(),
      );
    }

    if (!isCurrent()) return;
    final pinsToCache = changedPins.values
        .where((pin) => !profileDeletedPinIds.contains(pin.id))
        .map((pin) => PinEntity.fromDto(pin, false, keepAlive: true))
        .toList();
    await _pinRepository.putMultiple(pinsToCache);
    if (!isCurrent()) return;
    final additionalDeletedPinIds = profileDeletedPinIds
        .difference(deletedPinIds)
        .toList();
    await _pinRepository.deleteMultiple(additionalDeletedPinIds);
    if (!isCurrent()) return;
    await historyRepository.putMultiple(photosByPin);
    if (!isCurrent()) return;
    await historyRepository.deleteMultiple(profileDeletedPinIds);
    if (!isCurrent()) return;

    final profilePinsById = {
      for (final pin in cachedProfilePins) pin.pinId: pin,
      for (final pin in pinsToCache) pin.pinId: pin,
    };
    final profileHistoriesByPin = {
      for (final entry in photoCache.entries) entry.key: entry.value.photos,
      ...photosByPin,
    };
    await _prefetchCurrentProfileImages(
      userId: userId,
      pinIds: profilePinIds,
      pinsById: profilePinsById,
      historiesByPin: profileHistoriesByPin,
      isCurrent: isCurrent,
    );
    if (!isCurrent()) return;

    // Publishing the index last prevents a profile opened during sync from
    // seeing a partially cached set of photos and metadata.
    await profileRepository.put(
      UserPinsEntity(
        userId: userId,
        pins: profilePinIds.toList(growable: false),
        keepAlive: true,
        ttl: syncStartedAt,
        onlySession: false,
      ),
    );
  }

  Future<void> _prefetchCurrentProfileImages({
    required String userId,
    required Set<String> pinIds,
    required Map<String, PinEntity> pinsById,
    required Map<String, List<PinPhotoDto>> historiesByPin,
    required bool Function() isCurrent,
  }) async {
    final candidates = <String, ({String url, DateTime date})>{};
    for (final pinId in pinIds) {
      final pin = pinsById[pinId];
      for (final photo in historiesByPin[pinId] ?? const <PinPhotoDto>[]) {
        final isOwnUpdate = !photo.isOriginal && photo.contributorId == userId;
        final isOwnOriginal = photo.isOriginal && pin?.creator == userId;
        final imageUrl = photo.image;
        if ((!isOwnUpdate && !isOwnOriginal) ||
            imageUrl == null ||
            imageUrl.isEmpty) {
          continue;
        }
        final imageId = isOwnOriginal ? pinId : photo.id;
        candidates[imageId] = (url: imageUrl, date: photo.observedAt);
      }
    }
    if (candidates.isEmpty || !isCurrent()) return;

    final ordered = candidates.entries.toList()
      ..sort((a, b) => b.value.date.compareTo(a.value.date));
    final imageRepository = ref.read(pinImageRepositoryProvider);
    const pageSize = 18;
    const maxConcurrent = 6;
    for (
      var start = 0;
      start < ordered.length && start < pageSize;
      start += maxConcurrent
    ) {
      if (!isCurrent()) return;
      final batch = ordered.skip(start).take(maxConcurrent).toList();
      await Future.wait(
        batch.map((entry) async {
          if (!isCurrent()) return;
          try {
            await imageRepository.fetchImageFromUrl(
              entry.key,
              entry.value.url,
              false,
            );
          } catch (_) {
            // Photo byte prefetch is best-effort; the stored URL remains usable.
          }
        }),
      );
    }
  }

  Future<void> _syncOfflinePins(bool Function() isCurrent) async {
    if (!isCurrent()) return;
    final pending = ref.read(pendingPinRepositoryProvider);
    final owner = ref.read(userIdProvider);
    final queuedIds = (await pending.forOwner(owner))
        .map((row) => row.pinId)
        .toSet();
    final images = ref.read(pinImageRepositoryProvider);
    // Upgrade Android drafts made by earlier versions into the shared outbox.
    for (final pin in (await _pinRepository.getAll()).where(
      (item) => item.lastSynced == null && item.creator == owner,
    )) {
      if (!isCurrent()) return;
      if (queuedIds.contains(pin.pinId)) continue;
      final image = await images.fetchImage(pin.pinId, true);
      if (!isCurrent()) return;
      if (image != null) await pending.enqueue(pin, image);
    }
    if (!isCurrent()) return;
    await ref.read(pendingPinUploaderProvider).uploadAll(isActive: isCurrent);
  }
}
