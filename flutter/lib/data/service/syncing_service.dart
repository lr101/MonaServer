import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/repository/group_repository.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/account_data_cleanup.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
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
  late String userId;
  late AccountDataSessionGuard _sessionGuard;
  final Logger _logger = Logger();

  @override
  SyncState build() {
    ref.listen(userGroupServiceProvider, (_, _) => ());
    _pinsApi = ref.watch(pinApiProvider);
    _groupRepository = ref.watch(groupRepositoryProvider);
    _pinRepository = ref.watch(pinRepositoryProvider);
    userId = ref.watch(userIdProvider);
    _sessionGuard = ref.watch(accountDataSessionGuardProvider);
    ref.listen(
      lastSeenProvider(GlobalDataRepository.lastSeenKey),
      (_, _) => (),
    ); // keep provider alive
    ref.listen(
      userServiceProvider(userId),
      (_, _) => (),
    ); // keep provider alive
    syncToBackend();
    return SyncState.init;
  }

  Future<void> _cacheGroupImageBestEffort(
    IImageRepository repository,
    String groupId,
    String url,
    int generation,
  ) async {
    try {
      await repository.overrideUrl(
        groupId,
        url,
        true,
        sessionGeneration: generation,
      );
    } catch (error) {
      debugPrint('Unable to cache synced group image $groupId: $error');
    }
  }

  void toInit() {
    state = SyncState.init;
  }

  Future<void> syncToBackend() async {
    final sessionGeneration = _sessionGuard.generation;
    state = SyncState.syncing;
    const key = GlobalDataRepository.lastSeenKey;
    final lastSeen = ref.read(lastSeenProvider(key));
    final userId = ref.read(userIdProvider);
    try {
      _logger.i("Syncing groups of user $userId and lastSeen: $lastSeen");
      await syncFromBackend(lastSeen, sessionGeneration);
      await syncOfflinePins(sessionGeneration);
      await _sessionGuard.runIfCurrent(
        sessionGeneration,
        () => ref.read(lastSeenProvider(key).notifier).setLastSeenNow(),
      );
      if (!_sessionGuard.isCurrent(sessionGeneration)) return;
      state = SyncState.finished;
      _logger.i("Successfully finished syncing");
    } catch (e) {
      state = SyncState.failed;
      _logger.i("Failed syncing with error: $e");
      rethrow;
    }
  }

  Future<void> syncFromBackend(
    DateTime? lastSeen, [
    int? sessionGeneration,
  ]) async {
    final generation = sessionGeneration ?? _sessionGuard.generation;
    final response = await _pinsApi.callSync(lastSeen: lastSeen);
    if (response == null) {
      throw Exception("no sync possible");
    }

    final localUserGroups = await _groupRepository.watchUserGroups().first;
    for (final groupId in removedUserGroupIds(
      localUserGroups.map((group) => group.groupId),
      response,
    )) {
      if (!await _sessionGuard.runIfCurrent(generation, () async {
        await _groupRepository.delete(groupId);
        await _pinRepository.updateKeepAlive(groupId, false, true);
      })) {
        return;
      }
    }

    if (response.deletedPins.isNotEmpty) {
      if (!await _sessionGuard.runIfCurrent(
        generation,
        () => _pinRepository.deleteMultiple(response.deletedPins),
      )) {
        return;
      }
    }

    for (final groupUpdate in response.groupUpdates) {
      final groupDto = groupUpdate.group;
      final existingGroup = await _groupRepository.get(groupDto.id);
      if (!await _sessionGuard.runIfCurrent(generation, () async {
        await _groupRepository.put(
          GroupEntity.fromGroupDto(
            groupDto,
            false,
            true,
            keepAlive: true,
            isActivated: existingGroup?.isActivated ?? true,
          ),
        );
      })) {
        return;
      }

      if (groupUpdate.pinsAdded.isNotEmpty) {
        if (!await _sessionGuard.runIfCurrent(
          generation,
          () => _pinRepository.putMultiple(
            groupUpdate.pinsAdded
                .map((pin) => PinEntity.fromDto(pin, false))
                .toList(),
          ),
        )) {
          return;
        }
      }

      final profileImage = groupDto.profileImage;
      if (profileImage != null) {
        await _cacheGroupImageBestEffort(
          ref.read(groupProfileRepoProvider),
          groupDto.id,
          profileImage,
          generation,
        );
      }
      final profileImageSmall = groupDto.profileImageSmall;
      if (profileImageSmall != null) {
        await _cacheGroupImageBestEffort(
          ref.read(groupProfileSmallRepoProvider),
          groupDto.id,
          profileImageSmall,
          generation,
        );
      }
      final pinImage = groupDto.pinImage;
      if (pinImage != null) {
        await _cacheGroupImageBestEffort(
          ref.read(groupPinImageRepoProvider),
          groupDto.id,
          pinImage,
          generation,
        );
      }
    }
  }

  Future<void> syncOfflinePins([int? sessionGeneration]) async {
    final generation = sessionGeneration ?? _sessionGuard.generation;
    final offlinePins = (await _pinRepository.getAll()).where(
      (e) => e.lastSynced == null,
    );
    for (final pin in offlinePins) {
      if (!_sessionGuard.isCurrent(generation)) return;
      Uint8List? image;
      if (!_sessionGuard.isCurrent(generation)) {
        return;
      }
      image = await ref
          .read(pinImageRepositoryProvider)
          .fetchImage(pin.pinId, true, sessionGeneration: generation);
      if (!_sessionGuard.isCurrent(generation)) return;
      try {
        _logger.i("Trying to sync $pin to online backend");
        final newPin = await _pinsApi.createPin(pin.toRequestDto(image!));
        if (!await _sessionGuard.runIfCurrent(generation, () async {
          await _pinRepository.put(
            PinEntity.fromDto(newPin!, false, keepAlive: true),
          );
          await _pinRepository.delete(pin.pinId);
        })) {
          return;
        }
      } on ApiException catch (e) {
        if (e.code == 409) {
          _logger.i("Pin $pin already exists on online backend");
          await _sessionGuard.runIfCurrent(
            generation,
            () => _pinRepository.delete(pin.pinId),
          );
        }
      } catch (e) {
        if (kDebugMode) print(e);
      }
    }
  }
}
