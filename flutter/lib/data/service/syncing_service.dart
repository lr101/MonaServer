import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/drift_repo.dart';
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
    final isCurrent = accountOperation(ref);
    if (!isCurrent()) return;
    state = SyncState.syncing;
    const key = GlobalDataRepository.lastSeenKey;
    final lastSeen = ref.read(lastSeenProvider(key));
    final userId = ref.read(userIdProvider);
    try {
      _logger.i("Syncing groups of user $userId and lastSeen: $lastSeen");
      await syncFromBackend(lastSeen);
      if (!isCurrent()) return;
      await syncOfflinePins();
      if (!isCurrent()) return;
      ref.read(lastSeenProvider(key).notifier).setLastSeenNow();
      state = SyncState.finished;
      _logger.i("Successfully finished syncing");
    } catch (e) {
      if (!isCurrent()) return;
      state = SyncState.failed;
      _logger.i("Failed syncing with error: $e");
      rethrow;
    }
  }

  Future<void> syncFromBackend(DateTime? lastSeen) async {
    final isCurrent = accountOperation(ref);
    if (!isCurrent()) return;
    final groupRepository = _groupRepository;
    final pinRepository = _pinRepository;
    final response = await _pinsApi.callSync(lastSeen: lastSeen);
    if (!isCurrent()) return;
    if (response == null) {
      throw Exception("no sync possible");
    }

    final localUserGroups = await groupRepository.watchUserGroups().first;
    for (final groupId in removedUserGroupIds(
      localUserGroups.map((group) => group.groupId),
      response,
    )) {
      await groupRepository.delete(groupId);
      await pinRepository.updateKeepAlive(groupId, false, true);
    }

    if (response.deletedPins.isNotEmpty) {
      await pinRepository.deleteMultiple(response.deletedPins);
    }

    for (final groupUpdate in response.groupUpdates) {
      final groupDto = groupUpdate.group;
      final existingGroup = await groupRepository.get(groupDto.id);
      await groupRepository.put(
        GroupEntity.fromGroupDto(
          groupDto,
          false,
          true,
          keepAlive: true,
          isActivated: existingGroup?.isActivated ?? true,
        ),
      );

      if (groupUpdate.pinsAdded.isNotEmpty) {
        await pinRepository.putMultiple(
          groupUpdate.pinsAdded
              .map((pin) => PinEntity.fromDto(pin, false))
              .toList(),
        );
      }

      if (!isCurrent()) return;
      prefetchGroupMediaInBackground(ref, groupDto, keepAlive: true);
    }
  }

  Future<void> syncOfflinePins() async {
    final isCurrent = accountOperation(ref);
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
        _logger.i("Trying to sync $pin to online backend");
        final newPin = await pinsApi.createPin(pin.toRequestDto(image!));
        await pinRepository.put(
          PinEntity.fromDto(newPin!, false, keepAlive: true),
        );
        await pinRepository.delete(pin.pinId);
      } on ApiException catch (e) {
        if (e.code == 409) {
          _logger.i("Pin $pin already exists on online backend");
          await pinRepository.delete(pin.pinId);
        }
      } catch (e) {
        if (kDebugMode) print(e);
      }
    }
  }
}
