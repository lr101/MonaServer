import 'dart:async';

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

class _MetadataLoad {
  const _MetadataLoad({required this.dto, required this.fetched});

  final GroupDto? dto;
  final bool fetched;
}

@riverpod
class GroupService extends _$GroupService {
  Future<GroupEntity?>? _hydration;
  Future<_MetadataLoad>? _metadataRequest;
  bool _metadataOnly = false;

  @override
  Stream<GroupEntity?> build(String groupId) {
    final groupRepository = ref.watch(groupRepositoryProvider);
    ref.watch(userGroupServiceProvider);
    unawaited(
      _fetchMetadataIfMissing(
        consume: false,
      ).then<void>((_) {}, onError: (Object error, StackTrace stackTrace) {}),
    );
    return groupRepository.watchById(groupId);
  }

  Future<GroupEntity?> hydrate() async {
    final activeHydration = _hydration;
    if (activeHydration != null) return activeHydration;

    final hydration = _hydrate();
    _hydration = hydration;
    try {
      return await hydration;
    } catch (_) {
      if (identical(_hydration, hydration)) _hydration = null;
      rethrow;
    }
  }

  Future<GroupEntity?> _hydrate() async {
    final groupRepository = ref.read(groupRepositoryProvider);
    final groupsApi = ref.read(groupApiProvider);
    final userGroups = await ref.read(userGroupServiceProvider.future);
    final isUserGroup = userGroups.any((group) => group.groupId == groupId);
    final metadata = await _fetchMetadataIfMissing(consume: true);
    final group = await groupRepository.get(groupId);

    if (group != null && !group.onlySession && !_metadataOnly) {
      return group;
    }

    final groupDto = metadata.fetched
        ? metadata.dto
        : await groupsApi.getGroup(groupId);
    if (groupDto == null) return null;

    final groupEntity = GroupEntity.fromGroupDto(
      groupDto,
      !isUserGroup,
      isUserGroup,
      keepAlive: isUserGroup,
      isActivated: isUserGroup,
    );
    await groupRepository.put(groupEntity);

    if (groupDto.visibility == 0 || isUserGroup) {
      await _syncGroupPins(
        ref.read(pinRepositoryProvider),
        ref.read(pinApiProvider),
        groupId,
        onlySession: !isUserGroup,
        keepAlive: isUserGroup,
      );
      await _cacheGroupImages(
        ref,
        groupId,
        groupDto,
        keepAlive: isUserGroup,
        ignoreErrors: !isUserGroup,
      );
    }

    _metadataOnly = false;
    return groupEntity;
  }

  Future<_MetadataLoad> _fetchMetadataIfMissing({required bool consume}) async {
    final activeRequest = _metadataRequest;
    if (activeRequest != null) {
      if (!consume) return activeRequest;
      try {
        return await activeRequest;
      } finally {
        if (identical(_metadataRequest, activeRequest)) {
          _metadataRequest = null;
        }
      }
    }

    final request = _loadMetadataIfMissing();
    _metadataRequest = request;
    if (!consume) return request;
    try {
      return await request;
    } finally {
      if (identical(_metadataRequest, request)) _metadataRequest = null;
    }
  }

  Future<_MetadataLoad> _loadMetadataIfMissing() async {
    final groupRepository = ref.read(groupRepositoryProvider);
    final userGroups = await ref.read(userGroupServiceProvider.future);
    final isUserGroup = userGroups.any((group) => group.groupId == groupId);
    final group = await groupRepository.get(groupId);
    if (group != null) return const _MetadataLoad(dto: null, fetched: false);

    final groupDto = await ref.read(groupApiProvider).getGroup(groupId);
    if (groupDto == null) return const _MetadataLoad(dto: null, fetched: true);

    _metadataOnly = true;
    await groupRepository.put(
      GroupEntity.fromGroupDto(
        groupDto,
        !isUserGroup,
        isUserGroup,
        keepAlive: isUserGroup,
        isActivated: isUserGroup,
      ),
    );
    return _MetadataLoad(dto: groupDto, fetched: true);
  }
}

final groupDetailsReadyProvider = FutureProvider.autoDispose
    .family<GroupEntity?, String>((ref, groupId) {
      final groupService = ref.watch(groupServiceProvider(groupId).notifier);
      return groupService.hydrate();
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

    // update group pictures
    await _cacheGroupImages(ref, groupId, groupDto, keepAlive: true);
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

        await _cacheGroupImages(ref, groupId, result, keepAlive: true);
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

Future<void> _cacheGroupImages(
  Ref ref,
  String groupId,
  GroupDto groupDto, {
  required bool keepAlive,
  bool ignoreErrors = false,
}) async {
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

  if (ignoreErrors) {
    await Future.wait(
      cacheWrites.map((write) async {
        try {
          await write;
        } catch (_) {
          // The image providers retry failed public image downloads.
        }
      }),
    );
  } else {
    await Future.wait(cacheWrites);
  }
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
    groupServiceProvider(groupId).selectAsync((group) => group!.isActivated),
  );
}
