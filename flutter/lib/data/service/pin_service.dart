import 'dart:async';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
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

final pinUserRefreshCoordinatorProvider = Provider<_PinUserRefreshCoordinator>((
  ref,
) {
  // Keep the coordinator reactive to token rotation while tolerating
  // lightweight provider tests that override only userIdProvider.
  watchSession(ref);
  final coordinator = _PinUserRefreshCoordinator();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

class _PinUserRefreshCoordinator {
  final Map<_PinUserRefreshKey, Future<void>> _active = {};
  final Set<_PinUserRefreshKey> _complete = {};

  Future<void> ensure(
    String userId,
    SessionIdentity session,
    Future<void> Function() refresh,
  ) {
    final key = _PinUserRefreshKey(userId, session);
    if (_complete.contains(key)) return Future<void>.value();
    final active = _active[key];
    if (active != null) return active;

    final future = Future<void>.sync(refresh);
    final tracked = future.then<void>((_) => _complete.add(key));
    _active[key] = tracked;
    unawaited(
      tracked.then<void>(
        (_) {
          if (identical(_active[key], tracked)) _active.remove(key);
        },
        onError: (Object _, StackTrace __) {
          if (identical(_active[key], tracked)) _active.remove(key);
        },
      ),
    );
    return tracked;
  }

  void dispose() {
    _active.clear();
    _complete.clear();
  }
}

class _PinUserRefreshKey {
  const _PinUserRefreshKey(this.userId, this.session);

  final String userId;
  final SessionIdentity session;

  @override
  bool operator ==(Object other) =>
      other is _PinUserRefreshKey &&
      other.userId == userId &&
      other.session == session;

  @override
  int get hashCode => Object.hash(userId, session);
}

@riverpod
class PinUserService extends _$PinUserService {
  late IPinRepository _pinRepository;
  late PinsApi _pinsApi;
  late String _userId;
  late SessionIdentity _session;

  @override
  Stream<List<PinEntity>> build(String userId) async* {
    if (!ref.watch(accountSessionProvider).isActive) {
      yield [];
      return;
    }
    final hiddenUsers = ref.watch(hiddenUserServiceProvider);
    final hiddenPosts = ref.watch(hiddenPostsServiceProvider);
    _pinRepository = ref.watch(pinRepositoryProvider);
    _pinsApi = ref.watch(pinApiProvider);
    _userId = ref.watch(userIdProvider);
    _session = watchSession(ref);

    List<PinEntity>? initialPins;
    final pinStream = _pinRepository.getPinsByUser(userId).map((pins) {
      initialPins ??= List<PinEntity>.of(pins);
      final visiblePins = List<PinEntity>.of(pins);
      visiblePins.removeWhere(
        (e) => hiddenUsers.contains(e.creator) || hiddenPosts.contains(e.pinId),
      );
      visiblePins.sort((a, b) => b.creationDate.compareTo(a.creationDate));
      return visiblePins;
    });

    final visibleCachedPins = await pinStream.first;
    yield visibleCachedPins;

    await _remoteFetch(initialPins ?? visibleCachedPins);

    yield* pinStream;
  }

  // update non-user pins
  Future<void> _remoteFetch(List<PinEntity> cachedPins) async {
    final isUser = this.userId == _userId;
    if (isUser) return;
    final session = _session;
    await ref
        .read(pinUserRefreshCoordinatorProvider)
        .ensure(
          this.userId,
          session,
          () => _fetchAllRemotePages(session, cachedPins),
        );
  }

  Future<void> _fetchAllRemotePages(
    SessionIdentity session,
    List<PinEntity> cachedPins,
  ) async {
    const pageSize = 20;
    final received = <String>{};
    DateTime? beforeCreationDate;
    String? beforeId;
    for (var page = 0; ; page++) {
      if (!isCurrentSession(ref, session)) return;
      final remotePins = await _pinsApi.getPinImagesByIds(
        userId: this.userId,
        withImage: false,
        page: page,
        size: pageSize,
        beforeCreationDate: beforeCreationDate,
        beforeId: beforeId,
      );
      if (remotePins == null || !isCurrentSession(ref, session)) return;
      for (final pin in remotePins.items) {
        registerPinImageUrl(ref, pin);
      }
      final newPins = remotePins.items
          .where((pin) => received.add(pin.id))
          .map((e) => PinEntity.fromDto(e, true))
          .toList();
      if (!isCurrentSession(ref, session)) return;
      await _pinRepository.putMultiple(newPins);
      if (!isCurrentSession(ref, session)) return;
      if (remotePins.items.isEmpty) break;
      final last = remotePins.items.last;
      final cursorRepeated =
          beforeCreationDate == last.creationDate && beforeId == last.id;
      beforeCreationDate = last.creationDate;
      beforeId = last.id;
      if (remotePins.items.length < pageSize || cursorRepeated) break;
    }

    if (!isCurrentSession(ref, session)) return;
    final stalePins = cachedPins
        .where((pin) => !received.contains(pin.pinId))
        .map((pin) => pin.pinId)
        .toList();
    if (stalePins.isNotEmpty) {
      await _pinRepository.deleteMultiple(stalePins);
      if (!isCurrentSession(ref, session)) return;
    }
  }
}

@riverpod
Stream<PinEntity?> pinById(Ref ref, String pinId) async* {
  final repo = ref.watch(pinRepositoryProvider);
  final api = ref.watch(pinApiProvider);
  final session = captureSession(ref);

  bool hasFetched = false;
  await for (final pin in repo.watchById(pinId)) {
    if (pin == null && !hasFetched) {
      hasFetched = true;
      api.getPin(pinId).then((pinDto) async {
        if (pinDto != null && isCurrentSession(ref, session)) {
          registerPinImageUrl(ref, pinDto);
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
  SessionIdentity? _session;
  Future<void>? _refreshInProgress;

  @override
  Stream<List<PinEntity>> build(String groupId) async* {
    if (!ref.watch(accountSessionProvider).isActive) {
      yield [];
      return;
    }
    _pinRepository = ref.watch(pinRepositoryProvider);
    _pinsApi = ref.watch(pinApiProvider);
    _session = watchSession(ref);
    // Only a membership transition for this group changes the cache policy.
    // Group metadata or another group's update must not restart a full pin
    // refresh for this provider.
    ref.watch(
      userGroupServiceProvider.select((groups) {
        if (!groups.hasValue) return null;
        return groups.value!.any((group) => group.groupId == groupId);
      }),
    );

    final cachedPins = await _pinRepository.getPinsByGroup(groupId).first;
    yield cachedPins;

    final activeRefresh = _refreshInProgress;
    if (activeRefresh == null) {
      final refresh = _refreshInBackground(cachedPins, groupId, _session);
      _refreshInProgress = refresh;
      unawaited(
        refresh.whenComplete(() {
          if (identical(_refreshInProgress, refresh)) {
            _refreshInProgress = null;
          }
        }),
      );
    }
    yield* _pinRepository.getPinsByGroup(groupId);
  }

  Future<void> _refreshInBackground(
    List<PinEntity> cachedPins,
    String groupId,
    SessionIdentity? session,
  ) async {
    try {
      await _remoteFetch(cachedPins, session);
      if (isCurrentSession(ref, session)) {
        ref.read(pinGroupRefreshErrorStateProvider(groupId).notifier).clear();
      }
    } catch (error, stackTrace) {
      // Keep cached pins available when a background refresh is unavailable.
      if (cachedPins.isEmpty && isCurrentSession(ref, session)) {
        ref
            .read(pinGroupRefreshErrorStateProvider(groupId).notifier)
            .setError(error, stackTrace);
      }
    }
  }

  // Group pins are refreshed when a pin consumer is active. The global sync
  // may already have populated joined groups, but the details view uses this
  // same refresh path for every membership state.
  Future<void> _remoteFetch(
    List<PinEntity> cachedPins,
    SessionIdentity? session,
  ) async {
    if (!isCurrentSession(ref, session)) return;
    final membershipBeforeFetch = _currentMembership();
    await _reconcileCachePolicy(cachedPins, membershipBeforeFetch);

    // Keep a fixed watermark for the whole walk. Advancing it after each page
    // would skip rows that changed while the refresh was in progress.
    final updatedAfter = _oldestSyncTime(cachedPins);
    const pageSize = 20;
    final received = <String>{};
    DateTime? beforeCreationDate;
    String? beforeId;
    var latestIsUserGroup = _currentMembership() ?? false;
    for (var page = 0; ; page++) {
      if (!isCurrentSession(ref, session)) return;
      final remotePins = await _pinsApi.getPinImagesByIds(
        groupId: groupId,
        withImage: false,
        page: page,
        size: pageSize,
        updatedAfter: updatedAfter,
        beforeCreationDate: beforeCreationDate,
        beforeId: beforeId,
      );
      if (remotePins == null || !isCurrentSession(ref, session)) return;

      if (remotePins.deleted.isNotEmpty) {
        await _pinRepository.deleteMultiple(remotePins.deleted);
        if (!isCurrentSession(ref, session)) return;
      }

      latestIsUserGroup = _currentMembership() ?? false;
      for (final pin in remotePins.items) {
        registerPinImageUrl(ref, pin);
      }
      final pins = remotePins.items
          .where((pin) => received.add(pin.id))
          .map(
            (e) => PinEntity.fromDto(
              e,
              !latestIsUserGroup,
              keepAlive: latestIsUserGroup,
            ),
          )
          .toList();
      if (!isCurrentSession(ref, session)) return;
      await _pinRepository.putMultiple(pins);
      if (!isCurrentSession(ref, session)) return;
      if (remotePins.items.isEmpty) break;
      final last = remotePins.items.last;
      final cursorRepeated =
          beforeCreationDate == last.creationDate && beforeId == last.id;
      beforeCreationDate = last.creationDate;
      beforeId = last.id;
      if (remotePins.items.length < pageSize || cursorRepeated) break;
    }

    // Membership may change while the repository batch is being written.
    // Align the cache policy with the state visible after the write.
    await Future<void>.delayed(Duration.zero);
    if (!isCurrentSession(ref, session)) return;
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
