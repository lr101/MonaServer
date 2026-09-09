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
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
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
  late SessionIdentity _session;
  final Logger _logger = Logger();

  @override
  SyncState build() {
    ref.listen(userGroupServiceProvider, (_, _) => ());
    _pinsApi = ref.watch(pinApiProvider);
    _groupRepository = ref.watch(groupRepositoryProvider);
    _pinRepository = ref.watch(pinRepositoryProvider);
    userId = ref.watch(userIdProvider);
    _session = watchSession(ref);
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
    final session = _session;
    final sessionUserId = session.userId ?? ref.read(userIdProvider);
    try {
      _logger.i(
        "Syncing groups of user $sessionUserId and lastSeen: $lastSeen",
      );
      await syncFromBackend(lastSeen, session: session);
      await syncOfflinePins(session: session);
      if (!isCurrentSession(ref, session)) return;
      ref.read(lastSeenProvider(key).notifier).setLastSeenNow();
      state = SyncState.finished;
      _logger.i("Successfully finished syncing");
    } catch (e) {
      if (!isCurrentSession(ref, session)) return;
      state = SyncState.failed;
      _logger.i("Failed syncing with error: $e");
      rethrow;
    }
  }

  Future<void> syncFromBackend(
    DateTime? lastSeen, {
    SessionIdentity? session,
    String? sessionUserId,
  }) async {
    final expectedSession =
        session ??
        (sessionUserId == null
            ? captureSession(ref)
            : SessionIdentity(userId: sessionUserId, refreshToken: null));
    final response = await _pinsApi.callSync(lastSeen: lastSeen);
    if (!isCurrentSession(ref, expectedSession)) return;
    if (response == null) {
      throw Exception("no sync possible");
    }

    final localUserGroups = await _groupRepository.watchUserGroups().first;
    for (final groupId in removedUserGroupIds(
      localUserGroups.map((group) => group.groupId),
      response,
    )) {
      if (!isCurrentSession(ref, expectedSession)) return;
      await _groupRepository.delete(groupId);
      if (!isCurrentSession(ref, expectedSession)) return;
      await _pinRepository.updateKeepAlive(groupId, false, true);
    }

    if (response.deletedPins.isNotEmpty) {
      if (!isCurrentSession(ref, expectedSession)) return;
      await _pinRepository.deleteMultiple(response.deletedPins);
      if (!isCurrentSession(ref, expectedSession)) return;
    }

    for (final groupUpdate in response.groupUpdates) {
      if (!isCurrentSession(ref, expectedSession)) return;
      final groupDto = groupUpdate.group;
      registerGroupImageUrls(ref, groupDto);
      final existingGroup = await _groupRepository.get(groupDto.id);
      if (!isCurrentSession(ref, expectedSession)) return;
      await _groupRepository.put(
        GroupEntity.fromGroupDto(
          groupDto,
          false,
          true,
          keepAlive: true,
          isActivated: existingGroup?.isActivated ?? true,
        ),
      );
      if (!isCurrentSession(ref, expectedSession)) return;

      if (groupUpdate.pinsAdded.isNotEmpty) {
        if (!isCurrentSession(ref, expectedSession)) return;
        for (final pin in groupUpdate.pinsAdded) {
          registerPinImageUrl(ref, pin);
        }
        if (!isCurrentSession(ref, expectedSession)) return;
        await _pinRepository.putMultiple(
          groupUpdate.pinsAdded
              .map((pin) => PinEntity.fromDto(pin, false))
              .toList(),
        );
        if (!isCurrentSession(ref, expectedSession)) return;
      }

      prefetchGroupMediaInBackground(
        ref,
        groupDto,
        keepAlive: true,
        session: expectedSession,
      );
    }
  }

  Future<void> syncOfflinePins({
    SessionIdentity? session,
    String? sessionUserId,
  }) async {
    final expectedSession =
        session ??
        (sessionUserId == null
            ? captureSession(ref)
            : SessionIdentity(userId: sessionUserId, refreshToken: null));
    final offlinePins = (await _pinRepository.getAll()).where(
      (e) => e.lastSynced == null,
    );
    for (final pin in offlinePins) {
      if (!isCurrentSession(ref, expectedSession)) return;
      final image = await ref
          .read(pinImageRepositoryProvider)
          .fetchImage(pin.pinId, true);
      try {
        if (!isCurrentSession(ref, expectedSession)) return;
        _logger.i("Trying to sync $pin to online backend");
        final newPin = await _pinsApi.createPin(pin.toRequestDto(image!));
        if (!isCurrentSession(ref, expectedSession)) return;
        await _pinRepository.put(
          PinEntity.fromDto(newPin!, false, keepAlive: true),
        );
        if (!isCurrentSession(ref, expectedSession)) return;
        await _pinRepository.delete(pin.pinId);
        if (!isCurrentSession(ref, expectedSession)) return;
      } on ApiException catch (e) {
        if (e.code == 409 && isCurrentSession(ref, expectedSession)) {
          _logger.i("Pin $pin already exists on online backend");
          if (!isCurrentSession(ref, expectedSession)) return;
          await _pinRepository.delete(pin.pinId);
        }
      } catch (e) {
        if (kDebugMode) print(e);
      }
    }
  }
}
