import 'dart:async';
import 'dart:collection';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/group_repository.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/repository/pin_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
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

  Future<GroupEntity?> load(String groupId) {
    final activeLoad = _activeLoads[groupId];
    if (activeLoad != null) return activeLoad;

    final load = _load(groupId);
    _activeLoads[groupId] = load;
    unawaited(
      load.then<void>(
        (_) {
          if (identical(_activeLoads[groupId], load)) {
            _activeLoads.remove(groupId);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_activeLoads[groupId], load)) {
            _activeLoads.remove(groupId);
          }
        },
      ),
    );
    return load;
  }

  Future<GroupEntity?> _load(String groupId) async {
    final groupRepository = ref.read(groupRepositoryProvider);
    final groupsApi = ref.read(groupApiProvider);
    final initialGroup = await groupRepository.get(groupId);

    if (initialGroup != null && !initialGroup.onlySession) {
      return initialGroup;
    }

    final groupDto = await groupsApi.getGroup(groupId);
    if (groupDto == null) {
      if (initialGroup?.onlySession == true) {
        await groupRepository.delete(groupId);
      }
      return null;
    }

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

  @override
  Stream<List<GroupEntity>> build() {
    // watch providers
    _groupRepository = ref.watch(groupRepositoryProvider);
    _membersApi = ref.watch(memberApiProvider);
    _groupsApi = ref.watch(groupApiProvider);
    _pinRepository = ref.watch(pinRepositoryProvider);
    _pinsApi = ref.watch(pinApiProvider);
    _userId = ref.watch(userIdProvider);

    // listen to repository so that updates propagate automatically
    return _groupRepository.watchUserGroups();
  }

  Future<void> sync(DateTime? lastSeen) async {
    final remoteGroups = await _groupsApi.getGroupsByIds(
      userId: _userId,
      withUser: true,
      withImages: true,
      updatedAfter: lastSeen,
    );
    if (remoteGroups == null) throw Exception("no sync possible");
    for (final groupId in remoteGroups.deleted) {
      await _syncLeave(groupId);
    }
    for (final group in remoteGroups.items) {
      await _syncJoin(group);
    }
  }

  Future<void> _syncJoin(GroupDto groupDto) async {
    // update group entity
    final groupId = groupDto.id;
    final groupEntity = GroupEntity.fromGroupDto(
      groupDto,
      false,
      true,
      keepAlive: true,
      isActivated: true,
    );
    await _groupRepository.put(groupEntity);

    // update group pins
    await _syncGroupPins(
      _pinRepository,
      _pinsApi,
      groupId,
      onlySession: false,
      keepAlive: true,
    );

    // Media is an offline cache concern, not part of the join transaction.
    prefetchGroupMediaInBackground(ref, groupDto, keepAlive: true);
  }

  Future<void> _syncLeave(String groupId) async {
    await _groupRepository.delete(groupId);
    // make group pins not keepAlive and onlySession
    await _pinRepository.updateKeepAlive(groupId, false, true);
  }

  Future<String?> joinGroup(String groupId, {String? inviteUrl}) async {
    try {
      final result = await _membersApi.joinGroup(
        groupId,
        _userId,
        inviteUrl: inviteUrl,
      );
      if (result != null) {
        await _syncJoin(result);
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
    try {
      await _membersApi.deleteMemberFromGroup(groupId, _userId);
      await _syncLeave(groupId);
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
    try {
      final result = await _groupsApi.addGroup(data);
      if (result != null) {
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
    try {
      final result = await _groupsApi.updateGroup(groupId, data);
      if (result != null) {
        final entity = GroupEntity.fromGroupDto(
          result,
          /* onlySession */ false,
          /* userIsMember */ true,
          isActivated: true,
          keepAlive: true,
        );
        await _groupRepository.put(entity);

        prefetchGroupMediaInBackground(ref, result, keepAlive: true);
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
  IPinRepository pinRepository,
  PinsApi pinsApi,
  String groupId, {
  required bool onlySession,
  required bool keepAlive,
}) async {
  final pins = await pinsApi.getPinImagesByIds(
    groupId: groupId,
    withImage: false,
  );
  if (pins == null) return;

  final pinEntities = pins.items
      .map((pin) => PinEntity.fromDto(pin, onlySession, keepAlive: keepAlive))
      .toList();
  await pinRepository.putMultiple(pinEntities);
}

void prefetchGroupMediaInBackground(
  Ref ref,
  GroupDto groupDto, {
  required bool keepAlive,
}) {
  final queue = ref.read(_groupMediaPrefetchQueueProvider);
  unawaited(
    queue
        .add(() => prefetchGroupMedia(ref, groupDto, keepAlive: keepAlive))
        .then<void>((_) {}, onError: (Object error, StackTrace stackTrace) {}),
  );
}

Future<void> prefetchGroupMedia(
  Ref ref,
  GroupDto groupDto, {
  required bool keepAlive,
}) async {
  final groupId = groupDto.id;
  final cacheWrites = <Future<Object?>>[];
  final profileImage = groupDto.profileImage;
  if (profileImage != null) {
    cacheWrites.add(
      ref
          .read(groupProfileRepoProvider)
          .overrideUrl(groupId, profileImage, keepAlive),
    );
  }

  final profileImageSmall = groupDto.profileImageSmall;
  if (profileImageSmall != null) {
    cacheWrites.add(
      ref
          .read(groupProfileSmallRepoProvider)
          .overrideUrl(groupId, profileImageSmall, keepAlive),
    );
  }

  final pinImage = groupDto.pinImage;
  if (pinImage != null) {
    cacheWrites.add(
      ref
          .read(groupPinImageRepoProvider)
          .overrideUrl(groupId, pinImage, keepAlive),
    );
  }

  await Future.wait(cacheWrites);
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
