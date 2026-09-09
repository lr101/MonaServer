import 'dart:async';
import 'dart:collection';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/group_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/batch_read_coalescer.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openapi/api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_service.g.dart';

final groupMetadataLoaderProvider = Provider<GroupMetadataLoader>(
  (ref) => GroupMetadataLoader(ref),
);

final _groupMediaPrefetchQueueProvider = Provider<_SerialAsyncTaskQueue>(
  (ref) => _SerialAsyncTaskQueue(),
);

class _SerialAsyncTaskQueue {
  final Queue<_QueuedAsyncTask> _tasks = Queue<_QueuedAsyncTask>();
  bool _running = false;

  Future<void> add(Future<void> Function() task) {
    final queued = _QueuedAsyncTask(task);
    _tasks.add(queued);
    _startNext();
    return queued.completer.future;
  }

  void _startNext() {
    if (_running || _tasks.isEmpty) return;
    _running = true;
    final queued = _tasks.removeFirst();
    Future<void>.sync(queued.task)
        .then<void>(
          queued.completer.complete,
          onError: queued.completer.completeError,
        )
        .whenComplete(() {
          _running = false;
          _startNext();
        });
  }
}

class _QueuedAsyncTask {
  _QueuedAsyncTask(this.task);

  final Future<void> Function() task;
  final Completer<void> completer = Completer<void>();
}

class GroupMetadataLoader {
  GroupMetadataLoader(this.ref);

  final Ref ref;
  final Map<String, Future<GroupEntity?>> _activeLoads = {};
  final Map<String, SessionIdentity> _activeLoadSessions = {};

  Future<GroupEntity?> load(String groupId) {
    final session = captureSession(ref);
    final activeLoad = _activeLoads[groupId];
    if (activeLoad != null && _activeLoadSessions[groupId] == session) {
      return activeLoad;
    }

    final load = _load(groupId, session);
    _activeLoads[groupId] = load;
    _activeLoadSessions[groupId] = session;
    unawaited(
      load.then<void>(
        (_) {
          if (identical(_activeLoads[groupId], load)) {
            _activeLoads.remove(groupId);
            _activeLoadSessions.remove(groupId);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_activeLoads[groupId], load)) {
            _activeLoads.remove(groupId);
            _activeLoadSessions.remove(groupId);
          }
        },
      ),
    );
    return load;
  }

  Future<GroupEntity?> _load(String groupId, SessionIdentity session) async {
    final groupRepository = ref.read(groupRepositoryProvider);
    final groupsApi = ref.read(groupApiProvider);
    final initialGroup = await groupRepository.get(groupId);

    if (initialGroup != null && !initialGroup.onlySession) {
      return initialGroup;
    }

    final groupDto = await groupsApi.getGroup(groupId);
    if (!isCurrentSession(ref, session)) return null;
    if (groupDto == null) {
      if (initialGroup?.onlySession == true) {
        await groupRepository.delete(groupId);
      }
      return null;
    }
    registerGroupImageUrls(ref, groupDto);

    final latestGroup = await groupRepository.get(groupId);
    // Unjoined groups can be opened before the first user-group snapshot is
    // available. Use the state that is already loaded and let the repository
    // stream reconcile membership when that snapshot arrives.
    final latestUserGroups =
        ref.read(userGroupServiceProvider).value ?? const <GroupEntity>[];
    if (initialGroup?.userIsMember == true && latestGroup == null) {
      return null;
    }
    final isCurrentUserGroup =
        latestGroup?.userIsMember == true ||
        latestUserGroups.any((group) => group.groupId == groupId);
    final groupEntity = GroupEntity.fromGroupDto(
      groupDto,
      !isCurrentUserGroup,
      isCurrentUserGroup,
      keepAlive: isCurrentUserGroup,
      isActivated: latestGroup?.isActivated ?? isCurrentUserGroup,
    );
    if (!isCurrentSession(ref, session)) return null;
    await groupRepository.put(groupEntity);
    return groupEntity;
  }
}

@riverpod
class GroupService extends _$GroupService {
  Future<GroupEntity?>? _hydration;

  @override
  Stream<GroupEntity?> build(String groupId) {
    final groupRepository = ref.watch(groupRepositoryProvider);
    return groupRepository.watchById(groupId);
  }

  Future<GroupEntity?> hydrate() async {
    final activeHydration = _hydration;
    if (activeHydration != null) return activeHydration;

    final hydration = _hydrate();
    _hydration = hydration;
    try {
      return await hydration;
    } finally {
      if (identical(_hydration, hydration)) {
        _hydration = null;
      }
    }
  }

  Future<GroupEntity?> _hydrate() {
    return ref.read(groupMetadataLoaderProvider).load(groupId);
  }
}

/// Explicit metadata loading for consumers that do not need the full details
/// state. Watching the group stream alone never starts a network request.
final groupMetadataProvider = StreamProvider.autoDispose
    .family<GroupEntity?, String>((ref, groupId) async* {
      final keepAlive = ref.keepAlive();
      try {
        final group = await ref.read(groupMetadataLoaderProvider).load(groupId);
        if (group == null) {
          yield null;
          return;
        }
        yield* ref.read(groupRepositoryProvider).watchById(groupId);
      } finally {
        keepAlive.close();
      }
    });

@riverpod
class UserGroupService extends _$UserGroupService {
  late IGroupRepository _groupRepository;
  late MembersApi _membersApi;
  late GroupsApi _groupsApi;
  late IPinRepository _pinRepository;
  late PinsApi _pinsApi;
  late String _userId;
  late SessionIdentity _session;

  @override
  Stream<List<GroupEntity>> build() {
    // watch providers
    _groupRepository = ref.watch(groupRepositoryProvider);
    _membersApi = ref.watch(memberApiProvider);
    _groupsApi = ref.watch(groupApiProvider);
    _pinRepository = ref.watch(pinRepositoryProvider);
    _pinsApi = ref.watch(pinApiProvider);
    _userId = ref.watch(userIdProvider);
    _session = watchSession(ref);

    // listen to repository so that updates propagate automatically
    return _groupRepository.watchUserGroups();
  }

  Future<void> sync(DateTime? lastSeen) async {
    final session = _session;
    final sessionUserId = session.userId ?? _userId;
    final remoteGroups = await _groupsApi.getGroupsByIds(
      userId: sessionUserId,
      withUser: true,
      withImages: true,
      updatedAfter: lastSeen,
    );
    if (!isCurrentSession(ref, session)) return;
    if (remoteGroups == null) throw Exception("no sync possible");
    for (final groupId in remoteGroups.deleted) {
      await _syncLeave(groupId, session: session);
    }
    for (final group in remoteGroups.items) {
      await _syncJoin(group, session: session);
    }
  }

  Future<void> _syncJoin(
    GroupDto groupDto, {
    bool toleratePinSyncErrors = false,
    SessionIdentity? session,
  }) async {
    final expectedSession = session ?? captureSession(ref);
    if (!isCurrentSession(ref, expectedSession)) return;
    // update group entity
    final groupId = groupDto.id;
    registerGroupImageUrls(ref, groupDto);
    final groupEntity = GroupEntity.fromGroupDto(
      groupDto,
      false,
      true,
      keepAlive: true,
      isActivated: true,
    );
    if (!isCurrentSession(ref, expectedSession)) return;
    await _groupRepository.put(groupEntity);

    // update group pins
    try {
      await _syncGroupPins(
        ref,
        _pinRepository,
        _pinsApi,
        groupId,
        onlySession: false,
        keepAlive: true,
        session: expectedSession,
      );
    } catch (_) {
      if (!toleratePinSyncErrors) rethrow;
    }
    if (!isCurrentSession(ref, expectedSession)) return;

    // Media is an offline cache concern, not part of the join transaction.
    prefetchGroupMediaInBackground(
      ref,
      groupDto,
      keepAlive: true,
      session: expectedSession,
    );
  }

  Future<void> _syncLeave(String groupId, {SessionIdentity? session}) async {
    final expectedSession = session ?? captureSession(ref);
    if (!isCurrentSession(ref, expectedSession)) return;
    await _groupRepository.delete(groupId);
    // make group pins not keepAlive and onlySession
    if (!isCurrentSession(ref, expectedSession)) return;
    await _pinRepository.updateKeepAlive(groupId, false, true);
  }

  Future<String?> joinGroup(String groupId, {String? inviteUrl}) async {
    final session = _session;
    final sessionUserId = session.userId ?? _userId;
    try {
      final result = await _membersApi.joinGroup(
        groupId,
        sessionUserId,
        inviteUrl: inviteUrl,
      );
      if (result != null && isCurrentSession(ref, session)) {
        await _syncJoin(result, toleratePinSyncErrors: true, session: session);
      } else {
        return "Failed to join group remotely";
      }
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return "Failed to sync joined group";
    }
    return null;
  }

  Future<String?> leaveGroup(String groupId) async {
    final session = _session;
    final sessionUserId = session.userId ?? _userId;
    try {
      await _membersApi.deleteMemberFromGroup(groupId, sessionUserId);
      await _syncLeave(groupId, session: session);
    } on ApiException catch (_) {
      return "Failed ro leave group";
    }
    return null;
  }

  Future<void> setIsActive(String groupId, bool active) async {
    final group = await _groupRepository.get(groupId);
    if (group != null) {
      group.isActivated = active;
      await _groupRepository.put(group);
    }
  }

  Future<String?> createGroup(CreateGroupDto data) async {
    final session = _session;
    try {
      final result = await _groupsApi.addGroup(data);
      if (result != null && isCurrentSession(ref, session)) {
        registerGroupImageUrls(ref, result);
        final entity = GroupEntity.fromGroupDto(
          result,
          /* onlySession */ false,
          /* userIsMember */ true,
          isActivated: true,
          keepAlive: true,
        );
        await _groupRepository.put(entity);
        return null;
      } else {
        return "Failed to create group remotely unexpectedly";
      }
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> updateGroup(UpdateGroupDto data, String groupId) async {
    final session = _session;
    try {
      final result = await _groupsApi.updateGroup(groupId, data);
      if (result != null && isCurrentSession(ref, session)) {
        registerGroupImageUrls(ref, result);
        final entity = GroupEntity.fromGroupDto(
          result,
          /* onlySession */ false,
          /* userIsMember */ true,
          isActivated: true,
          keepAlive: true,
        );
        await _groupRepository.put(entity);

        prefetchGroupMediaInBackground(
          ref,
          result,
          keepAlive: true,
          session: session,
        );
      } else {
        return "Failed to update group remotely";
      }
    } catch (e) {
      return e.toString();
    }
    return null;
  }
}

Future<void> _syncGroupPins(
  Ref ref,
  IPinRepository pinRepository,
  PinsApi pinsApi,
  String groupId, {
  required bool onlySession,
  required bool keepAlive,
  SessionIdentity? session,
}) async {
  final expectedSession = session ?? captureSession(ref);
  const pageSize = 20;
  final received = <String>{};
  DateTime? beforeCreationDate;
  String? beforeId;
  for (var page = 0; ; page++) {
    if (!isCurrentSession(ref, expectedSession)) return;
    final pins = await pinsApi.getPinImagesByIds(
      groupId: groupId,
      withImage: false,
      page: page,
      size: pageSize,
      beforeCreationDate: beforeCreationDate,
      beforeId: beforeId,
    );
    if (pins == null) return;
    if (!isCurrentSession(ref, expectedSession)) return;

    if (pins.deleted.isNotEmpty) {
      await pinRepository.deleteMultiple(pins.deleted);
      if (!isCurrentSession(ref, expectedSession)) return;
    }
    for (final pin in pins.items) {
      registerPinImageUrl(ref, pin);
    }
    final pinEntities = pins.items
        .where((pin) => received.add(pin.id))
        .map((pin) => PinEntity.fromDto(pin, onlySession, keepAlive: keepAlive))
        .toList();
    if (!isCurrentSession(ref, expectedSession)) return;
    await pinRepository.putMultiple(pinEntities);
    if (!isCurrentSession(ref, expectedSession)) return;
    if (pins.items.isEmpty) break;
    final last = pins.items.last;
    final cursorRepeated =
        beforeCreationDate == last.creationDate && beforeId == last.id;
    beforeCreationDate = last.creationDate;
    beforeId = last.id;
    if (pins.items.length < pageSize || cursorRepeated) break;
  }
}

void prefetchGroupMediaInBackground(
  Ref ref,
  GroupDto groupDto, {
  required bool keepAlive,
  SessionIdentity? session,
}) {
  final expectedSession = session ?? captureSession(ref);
  final queue = ref.read(_groupMediaPrefetchQueueProvider);
  unawaited(
    queue
        .add(
          () => prefetchGroupMedia(
            ref,
            groupDto,
            keepAlive: keepAlive,
            session: expectedSession,
          ),
        )
        .then<void>((_) {}, onError: (Object error, StackTrace stackTrace) {}),
  );
}

Future<void> prefetchGroupMedia(
  Ref ref,
  GroupDto groupDto, {
  required bool keepAlive,
  SessionIdentity? session,
}) {
  if (!isCurrentSession(ref, session)) return Future<void>.value();
  registerGroupImageUrls(ref, groupDto);
  return Future<void>.value();
}

@riverpod
Future<Set<GroupEntity>> activeGroups(Ref ref) async {
  return await ref.watch(
    userGroupServiceProvider.selectAsync(
      (groups) => groups.where((t) => t.isActivated == true).toSet(),
    ),
  );
}

@riverpod
Future<List<GroupEntity>> orderedGroups(Ref ref) async {
  final groupOrder = ref.watch(groupOrderServiceProvider);
  final groups = await ref.watch(userGroupServiceProvider.future);
  final groupList = groups.toList();
  groupList.sort(
    (a, b) => groupOrder.indexOf(a.groupId) - groupOrder.indexOf(b.groupId),
  );
  return groupList;
}

@riverpod
Future<bool> groupByIdActivated(Ref ref, String groupId) async {
  return await ref.watch(
    groupMetadataProvider(groupId).selectAsync((group) => group!.isActivated),
  );
}
