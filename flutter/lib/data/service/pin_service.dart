import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/filter_service.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/view_service.dart';
import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pin_service.g.dart';

@riverpod
class PinUserService extends _$PinUserService {
  late IPinRepository _pinRepository;
  late PinsApi _pinsApi;
  late String _userId;

  @override
  Stream<List<PinEntity>> build(String userId) async* {
    final hiddenUsers = ref.watch(hiddenUserServiceProvider);
    final hiddenPosts = ref.watch(hiddenPostsServiceProvider);
    _pinRepository = ref.watch(pinRepositoryProvider);
    _pinsApi = ref.watch(pinApiProvider);
    _userId = ref.watch(userIdProvider);

    final pinStream = _pinRepository.getPinsByUser(userId).map((e) {
      e.removeWhere(
        (e) => hiddenUsers.contains(e.creator) || hiddenPosts.contains(e.pinId),
      );
      e.sort((a, b) => b.creationDate.compareTo(a.creationDate));
      return e;
    });

    yield await pinStream.first;

    await _remoteFetch();

    yield* pinStream;
  }

  // update non-user pins
  Future<void> _remoteFetch() async {
    final stream = _pinRepository.getPinsByUser(this.userId);
    final pins = await stream.first;
    final isUser = this.userId == _userId;
    if (pins.isEmpty && !isUser) {
      final remotePins = await _pinsApi.getPinImagesByIds(
        userId: this.userId,
        withImage: false,
      );
      if (remotePins != null) {
        final pins = remotePins.items
            .map((e) => PinEntity.fromDto(e, true))
            .toList();
        await _pinRepository.putMultiple(pins);
      }
    }
  }
}

@riverpod
Stream<PinEntity?> pinById(Ref ref, String pinId) async* {
  final repo = ref.watch(pinRepositoryProvider);
  final api = ref.watch(pinApiProvider);

  bool hasFetched = false;
  await for (final pin in repo.watchById(pinId)) {
    if (pin == null && !hasFetched) {
      hasFetched = true;
      api.getPin(pinId).then((pinDto) async {
        if (pinDto != null) {
          await repo.put(
            PinEntity.fromDto(pinDto, true),
          ); // This update will automatically trigger the stream again!
        }
      });
    }
    yield pin;
  }
}

@riverpod
class PinGroupServiceUnfiltered extends _$PinGroupServiceUnfiltered {
  late IPinRepository _pinRepository;
  late PinsApi _pinsApi;

  @override
  Stream<List<PinEntity>> build(String groupId) async* {
    _pinRepository = ref.watch(pinRepositoryProvider);
    _pinsApi = ref.watch(pinApiProvider);
    ref.watch(userGroupServiceProvider);

    final cachedPins = await _pinRepository.getPinsByGroup(groupId).first;
    yield cachedPins;

    unawaited(_refreshInBackground(cachedPins, groupId));
    yield* _pinRepository.getPinsByGroup(groupId);
  }

  Future<void> _refreshInBackground(
    List<PinEntity> cachedPins,
    String groupId,
  ) async {
    try {
      await _remoteFetch(cachedPins);
      if (ref.mounted) {
        ref.read(pinGroupRefreshErrorStateProvider(groupId).notifier).clear();
      }
    } catch (error, stackTrace) {
      // Keep cached pins available when a background refresh is unavailable.
      if (cachedPins.isEmpty && ref.mounted) {
        ref
            .read(pinGroupRefreshErrorStateProvider(groupId).notifier)
            .setError(error, stackTrace);
      }
    }
  }

  // Group pins are refreshed when a pin consumer is active. The global sync
  // may already have populated joined groups, but the details view uses this
  // same refresh path for every membership state.
  Future<void> _remoteFetch(List<PinEntity> cachedPins) async {
    final membershipBeforeFetch = _currentMembership();
    await _reconcileCachePolicy(cachedPins, membershipBeforeFetch);

    final remotePins = await _pinsApi.getPinImagesByIds(
      groupId: groupId,
      withImage: false,
      updatedAfter: _oldestSyncTime(cachedPins),
    );
    if (remotePins == null) return;

    if (remotePins.deleted.isNotEmpty) {
      await _pinRepository.deleteMultiple(remotePins.deleted);
    }

    final latestIsUserGroup = _currentMembership() ?? false;

    final pins = remotePins.items
        .map(
          (e) => PinEntity.fromDto(
            e,
            !latestIsUserGroup,
            keepAlive: latestIsUserGroup,
          ),
        )
        .toList();
    await _pinRepository.putMultiple(pins);

    // Membership may change while the repository batch is being written.
    // Align the cache policy with the state visible after the write.
    await Future<void>.delayed(Duration.zero);
    final joinedAfterWrite = _currentMembership();
    if (joinedAfterWrite != null && joinedAfterWrite != latestIsUserGroup) {
      await _pinRepository.updateKeepAlive(
        groupId,
        joinedAfterWrite,
        !joinedAfterWrite,
      );
    }
  }

  bool? _currentMembership() {
    final userGroups = ref.read(userGroupServiceProvider).value;
    if (userGroups == null) return null;
    return userGroups.any((group) => group.groupId == groupId);
  }

  Future<void> _reconcileCachePolicy(
    List<PinEntity> cachedPins,
    bool? isUserGroup,
  ) async {
    if (isUserGroup == null || cachedPins.isEmpty) return;

    final onlySession = !isUserGroup;
    final needsUpdate = cachedPins.any(
      (pin) => pin.keepAlive != isUserGroup || pin.onlySession != onlySession,
    );
    if (needsUpdate) {
      await _pinRepository.updateKeepAlive(groupId, isUserGroup, onlySession);
    }
  }
}

class PinGroupRefreshError {
  const PinGroupRefreshError(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

@riverpod
class PinGroupRefreshErrorState extends _$PinGroupRefreshErrorState {
  @override
  PinGroupRefreshError? build(String groupId) => null;

  void clear() => state = null;

  void setError(Object error, StackTrace stackTrace) {
    state = PinGroupRefreshError(error, stackTrace);
  }
}

DateTime? _oldestSyncTime(List<PinEntity> pins) {
  DateTime? oldest;
  for (final pin in pins) {
    final lastSynced = pin.lastSynced;
    if (lastSynced == null) return null;
    if (oldest == null || lastSynced.isBefore(oldest)) oldest = lastSynced;
  }
  return oldest;
}

@riverpod
Future<List<PinEntity>> pinGroupService(Ref ref, String groupId) async {
  final rawPinsAsync = ref.watch(pinGroupServiceUnfilteredProvider(groupId));
  final refreshError = ref.watch(pinGroupRefreshErrorStateProvider(groupId));
  final hiddenUsers = ref.watch(hiddenUserServiceProvider);
  final hiddenPosts = ref.watch(hiddenPostsServiceProvider);

  if (refreshError != null) {
    Error.throwWithStackTrace(refreshError.error, refreshError.stackTrace);
  }
  if (rawPinsAsync.hasError) {
    Error.throwWithStackTrace(
      rawPinsAsync.error!,
      rawPinsAsync.stackTrace ?? StackTrace.current,
    );
  }
  final pins = rawPinsAsync.value ?? [];

  return pins
      .where(
        (pin) =>
            !hiddenUsers.contains(pin.creator) &&
            !hiddenPosts.contains(pin.pinId),
      )
      .toList();
}

@Riverpod(keepAlive: true)
PinService pinService(Ref ref) => PinService(ref: ref);

class PinService {
  final Ref ref;
  late IPinRepository _pinRepository;
  late IImageRepository _pinImageRepository;
  late PinsApi _pinsApi;

  PinService({required this.ref}) {
    _pinRepository = ref.watch(pinRepositoryProvider);
    _pinImageRepository = ref.watch(pinImageRepositoryProvider);
    _pinsApi = ref.read(pinApiProvider);
    ref.listen(userGroupServiceProvider, (_, _) => ());
  }

  Future<String?> addPinToGroup(
    PinEntity pin,
    Uint8List image, {
    bool showPrompt = false,
  }) async {
    try {
      if (showPrompt)
        CustomErrorSnackBar.loadingMessage(message: "Uploading image");
      // await ref.read(userGroupServiceProvider.notifier).setIsActive(pin.groupId, true);
      await _addPinToRemote(pin, image);
      if (showPrompt)
        CustomErrorSnackBar.message(
          message: "Succesfully uploaded",
          type: CustomErrorSnackBarType.success,
        );
    } on ApiException catch (e) {
      if (showPrompt && kIsWeb) {
        CustomErrorSnackBar.message(
          message: "Uploading failed. Not stored offline on web.",
          type: CustomErrorSnackBarType.error,
        );
      } else if (showPrompt) {
        CustomErrorSnackBar.message(
          message: "Uploading failed. Stored offline.",
          type: CustomErrorSnackBarType.warning,
        );
      }
      return e.message;
    }
    return null;
  }

  Future<void> _addPinToRemote(PinEntity pin, Uint8List image) async {
    await _pinRepository.put(pin);
    await _pinImageRepository.addImage(pin.pinId, image, true);
    final result = await _pinsApi.createPin(pin.toRequestDto(image));
    final newPin = PinEntity.fromDto(result!, false);
    await _pinRepository.replacePin(pin.pinId, newPin);
    await _pinImageRepository.delete(pin.pinId);
    await _pinImageRepository.addImage(newPin.pinId, image, false);
  }

  Future<String?> deletePinFromGroup(
    String pinId, {
    bool showPrompt = false,
  }) async {
    try {
      if (showPrompt)
        CustomErrorSnackBar.loadingMessage(message: "Deleting image");
      final pin = await _pinRepository.get(pinId);
      if (pin != null && pin.keepAlive == false) {
        await _pinsApi.deletePin(pinId);
      }
      await _pinRepository.delete(pinId);
      if (showPrompt)
        CustomErrorSnackBar.message(
          message: "Succesfully deleted",
          type: CustomErrorSnackBarType.success,
        );
    } on ApiException catch (e) {
      if (showPrompt) {
        CustomErrorSnackBar.message(
          message: "Deleting failed",
          type: CustomErrorSnackBarType.error,
        );
      }
      return e.message;
    }
    return null;
  }
}

@riverpod
Set<PinEntity> activatedPinsWithoutLoading(Ref ref) {
  final viewState = ref.watch(viewServiceProvider);
  final pins = <PinEntity>{};
  if (viewState == ViewState.group) {
    final groups = ref.watch(activeGroupsProvider).value ?? {};

    for (final group in groups) {
      final p = ref.watch(pinGroupServiceProvider(group.groupId)).value ?? [];
      pins.addAll(p);
    }
  } else {
    final userId = ref.watch(userIdProvider);
    final p = ref.watch(pinUserServiceProvider(userId)).value ?? [];
    pins.addAll(p);
  }
  return pins;
}

@riverpod
AsyncValue<List<PinEntity>> sortedActivatedPins(Ref ref) {
  // Watch the groups. If they change, this whole function runs again.
  final groups = ref.watch(activeGroupsProvider).value ?? {};
  final pins = <PinEntity>[];

  for (final group in groups) {
    final p = ref.watch(pinGroupServiceProvider(group.groupId)).value ?? [];
    pins.addAll(p);
  }

  // Sort the newly combined list
  pins.sort((a, b) => b.creationDate.compareTo(a.creationDate));

  return AsyncData(pins);
}

@riverpod
Future<List<PinEntity>?> sortedGroupPins(Ref ref, String groupId) async {
  final pins = ref.watch(pinGroupServiceProvider(groupId)).value?.toList();
  if (pins == null) return null;
  pins.sort((a, b) => b.creationDate.compareTo(a.creationDate));
  return pins;
}
