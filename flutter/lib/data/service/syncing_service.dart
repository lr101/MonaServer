import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/repository/group_repository.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
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
  final Logger _logger = Logger();

  @override
  SyncState build() {
    ref.listen(userGroupServiceProvider, (_, _) => ());
    _pinsApi = ref.watch(pinApiProvider);
    _groupRepository = ref.watch(groupRepositoryProvider);
    _pinRepository = ref.watch(pinRepositoryProvider);
    userId = ref.watch(userIdProvider);
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

  void toInit() {
    state = SyncState.init;
  }

  Future<void> syncToBackend() async {
    state = SyncState.syncing;
    const key = GlobalDataRepository.lastSeenKey;
    final lastSeen = ref.read(lastSeenProvider(key));
    final userId = ref.read(userIdProvider);
    try {
      _logger.i("Syncing groups of user $userId and lastSeen: $lastSeen");
      await syncFromBackend(lastSeen);
      await syncOfflinePins();
      ref.read(lastSeenProvider(key).notifier).setLastSeenNow();
      state = SyncState.finished;
      _logger.i("Successfully finished syncing");
    } catch (e) {
      state = SyncState.failed;
      _logger.i("Failed syncing with error: $e");
      rethrow;
    }
  }

  Future<void> syncFromBackend(DateTime? lastSeen) async {
    final response = await _pinsApi.callSync(lastSeen: lastSeen);
    if (response == null) {
      throw Exception("no sync possible");
    }

    final localUserGroups = await _groupRepository.watchUserGroups().first;
    for (final groupId in removedUserGroupIds(
      localUserGroups.map((group) => group.groupId),
      response,
    )) {
      await _groupRepository.delete(groupId);
      await _pinRepository.updateKeepAlive(groupId, false, true);
    }

    if (response.deletedPins.isNotEmpty) {
      await _pinRepository.deleteMultiple(response.deletedPins);
    }

    for (final groupUpdate in response.groupUpdates) {
      final groupDto = groupUpdate.group;
      final existingGroup = await _groupRepository.get(groupDto.id);
      await _groupRepository.put(
        GroupEntity.fromGroupDto(
          groupDto,
          false,
          true,
          keepAlive: true,
          isActivated: existingGroup?.isActivated ?? true,
        ),
      );

      if (groupUpdate.pinsAdded.isNotEmpty) {
        await _pinRepository.putMultiple(
          groupUpdate.pinsAdded
              .map((pin) => PinEntity.fromDto(pin, false))
              .toList(),
        );
      }

      prefetchGroupMediaInBackground(ref, groupDto, keepAlive: true);
    }
  }

  Future<void> syncOfflinePins() async {
    final offlinePins = (await _pinRepository.getAll()).where(
      (e) => e.lastSynced == null,
    );
    for (final pin in offlinePins) {
      final image = await ref
          .read(pinImageRepositoryProvider)
          .fetchImage(pin.pinId, true);
      try {
        _logger.i("Trying to sync $pin to online backend");
        final newPin = await _pinsApi.createPin(pin.toRequestDto(image!));
        await _pinRepository.put(
          PinEntity.fromDto(newPin!, false, keepAlive: true),
        );
        await _pinRepository.delete(pin.pinId);
      } on ApiException catch (e) {
        if (e.code == 409) {
          _logger.i("Pin $pin already exists on online backend");
          await _pinRepository.delete(pin.pinId);
        }
      } catch (e) {
        if (kDebugMode) print(e);
      }
    }
  }
}
