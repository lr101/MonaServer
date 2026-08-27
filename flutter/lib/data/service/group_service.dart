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


@riverpod
class GroupService extends _$GroupService {
  
  @override
  Stream<GroupEntity?> build(String groupId) {
    final userGroups = ref.watch(userGroupServiceProvider).value ?? [];

    _remoteFetchIfNotExist(userGroups);
    return ref.watch(groupRepositoryProvider).watchById(groupId);
  }

  Future<void> _remoteFetchIfNotExist(List<GroupEntity> userGroups) async {
    final groupRepository = ref.read(groupRepositoryProvider);
    final groupsApi = ref.read(groupApiProvider);

    final group = await groupRepository.get(groupId);
    final isUserGroup = userGroups.any((e) => e.groupId == groupId);
    
    if (group == null) {
      final groupDto = await groupsApi.getGroup(groupId);
      if (groupDto != null) {
        await groupRepository.put(
          GroupEntity.fromGroupDto(groupDto, !isUserGroup, isUserGroup)
        );
      }
    }
  }
}


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
    final remoteGroups = await _groupsApi.getGroupsByIds(userId: _userId, withUser: true, withImages: true, updatedAfter: lastSeen);
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
    final groupEntity = GroupEntity.fromGroupDto(groupDto, false, true, keepAlive: true, isActivated: true);
    await _groupRepository.put(groupEntity);

    // update group pins
    final pins = await _pinsApi.getPinImagesByIds(groupId: groupId, withImage: false);
    final pinEntities = pins?.items.map((e) => PinEntity.fromDto(e, false)).toList() ?? [];
    await _pinRepository.putMultiple(pinEntities);

    // update group pictures
    ref.read(groupProfileRepoProvider).overrideUrl(groupId, groupDto.profileImage!, true);
    ref.read(groupProfileSmallRepoProvider).overrideUrl(groupId, groupDto.profileImageSmall!, true);
    ref.read(groupPinImageRepoProvider).overrideUrl(groupId, groupDto.pinImage!, true);
    

    // sync pins
    final remotePins = await _pinsApi.getPinImagesByIds(groupId: groupId, withImage: false);
    if (remotePins != null) {
      final pins = remotePins.items.map((e) => PinEntity.fromDto(e, false)).toList();
      await _pinRepository.putMultiple(pins);
    }
  }

  Future<void> _syncLeave(String groupId) async {
      await _groupRepository.delete(groupId);
      // make group pins not keepAlive and onlySession
      await _pinRepository.updateKeepAlive(groupId, false, true);
  }

  Future<String?> joinGroup(String groupId, {String? inviteUrl}) async {
    try {
      final result = await _membersApi.joinGroup(groupId, _userId, inviteUrl: inviteUrl);
      if (result != null) {
        await _syncJoin(result);
      } else {
        return "Failed to join group remotely";
      }
    } on ApiException catch (e) {
      return e.message;
    }
    return null;
  }

  Future<String?> leaveGroup(String groupId) async {
    try {
      await _membersApi.deleteMemberFromGroup(groupId, _userId);
      await _syncLeave(groupId);
    } on ApiException catch(_) {
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
        final entity = GroupEntity.fromGroupDto(result,/* onlySession */ false,/* userIsMember */ true,isActivated: true,keepAlive: true,);
        await _groupRepository.put(entity);
        
        ref.read(groupProfileRepoProvider).overrideUrl(groupId, result.profileImage!, true);
        ref.read(groupProfileSmallRepoProvider).overrideUrl(groupId, result.profileImageSmall!, true);
        ref.read(groupPinImageRepoProvider).overrideUrl(groupId, result.pinImage!, true);
      } else {
        return "Failed to update group remotely";
      }
    } catch (e) {
      return e.toString();
    }
    return null;
  }


}


@riverpod
Future<Set<GroupEntity>> activeGroups(Ref ref) async {
  return await ref.watch(userGroupServiceProvider.selectAsync(
      (groups) => groups.where((t) => t.isActivated == true).toSet(),),);
}

@riverpod
Future<List<GroupEntity>> orderedGroups(Ref ref) async {
  final groupOrder = ref.watch(groupOrderServiceProvider);
  final groups = await ref.watch(userGroupServiceProvider.future);
  final groupList = groups.toList();
  groupList.sort((a,b) => groupOrder.indexOf(a.groupId) - groupOrder.indexOf(b.groupId));
  return groupList;
}

@riverpod
Future<bool> groupByIdActivated(Ref ref, String groupId) async {
  return await ref.watch(groupServiceProvider(groupId).selectAsync((group) => group!.isActivated));
}
