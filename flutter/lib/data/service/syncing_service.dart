import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/repository/group_repository.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/features/progression/data/group_achievement_provider.dart';
import 'package:buff_lisa/features/progression/data/group_xp_provider.dart';
import 'package:buff_lisa/features/progression/data/profile_picture_progression_provider.dart';
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
      await _syncFromBackend(lastSeen, isCurrent);
      if (!isCurrent()) return;
      await _syncOfflinePins(isCurrent);
      if (!isCurrent()) return;
      ref.read(lastSeenProvider(key).notifier).setLastSeenNow();
      state = SyncState.finished;
    } catch (e) {
      if (!isCurrent()) return;
      state = SyncState.failed;
      rethrow;
    }
  }

  Future<void> _syncFromBackend(
    DateTime? lastSeen,
    bool Function() isCurrent,
  ) async {
    if (!isCurrent()) return;
    final groupRepository = _groupRepository;
    final pinRepository = _pinRepository;
    final response = await _pinsApi.callSync(lastSeen: lastSeen);
    if (!isCurrent()) return;
    if (response == null) {
      throw Exception("no sync possible");
    }

    final localUserGroups = await groupRepository.watchUserGroups().first;
    if (!isCurrent()) return;
    for (final groupId in removedUserGroupIds(
      localUserGroups.map((group) => group.groupId),
      response,
    )) {
      if (!isCurrent()) return;
      await groupRepository.delete(groupId);
      if (!isCurrent()) return;
      await pinRepository.updateKeepAlive(groupId, false, true);
    }

    if (!isCurrent()) return;
    if (response.deletedPins.isNotEmpty) {
      final affectedGroups = <String>{};
      for (final pinId in response.deletedPins) {
        if (!isCurrent()) return;
        final deletedPin = await pinRepository.get(pinId);
        if (!isCurrent()) return;
        if (deletedPin != null) affectedGroups.add(deletedPin.groupId);
      }
      await pinRepository.deleteMultiple(response.deletedPins);
      for (final groupId in affectedGroups) {
        ref.invalidate(groupAchievementsProvider(groupId));
      }
    }

    for (final groupUpdate in response.groupUpdates) {
      if (!isCurrent()) return;
      final groupDto = groupUpdate.group;
      registerGroupImageUrls(ref, groupDto);
      final existingGroup = await groupRepository.get(groupDto.id);
      if (!isCurrent()) return;
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

      if (!isCurrent()) return;
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
          ref.invalidate(userAvatarProgressionProvider(creatorId));
        }
        ref.invalidate(groupProgressionProvider(groupDto.id));
        ref.invalidate(groupAvatarProgressionProvider(groupDto.id));
        ref.invalidate(groupAchievementsProvider(groupDto.id));
      }

      if (!isCurrent()) return;
      prefetchGroupMediaInBackground(ref, groupDto, keepAlive: true);
    }
  }

  Future<void> _syncOfflinePins(bool Function() isCurrent) async {
    if (!isCurrent()) return;
    final pinRepository = _pinRepository;
    final pinsApi = _pinsApi;
    final images = ref.read(pinImageRepositoryProvider);
    final offlinePins = (await pinRepository.getAll()).where(
      (e) => e.lastSynced == null,
    );
    for (final pin in offlinePins) {
      if (!isCurrent()) return;
      final image = await images.fetchImage(pin.pinId, true);
      if (!isCurrent()) return;
      try {
        final newPin = await pinsApi.createPin(pin.toRequestDto(image!));
        if (!isCurrent()) return;
        ref.invalidate(userXpProvider(ref.read(userIdProvider)));
        ref.invalidate(groupProgressionProvider(pin.groupId));
        ref.invalidate(groupAvatarProgressionProvider(pin.groupId));
        ref.invalidate(groupAchievementsProvider(pin.groupId));
        await pinRepository.put(
          PinEntity.fromDto(newPin!, false, keepAlive: true),
        );
        if (!isCurrent()) return;
        await pinRepository.delete(pin.pinId);
      } on ApiException catch (e) {
        if (!isCurrent()) return;
        if (e.code != 409) rethrow;
        // Preserve the legacy duplicate policy until server idempotency lands.
        ref.invalidate(userXpProvider(ref.read(userIdProvider)));
        ref.invalidate(groupProgressionProvider(pin.groupId));
        ref.invalidate(groupAvatarProgressionProvider(pin.groupId));
        ref.invalidate(groupAchievementsProvider(pin.groupId));
        await pinRepository.delete(pin.pinId);
      } catch (_) {
        if (!isCurrent()) return;
        rethrow;
      }
    }
  }
}
