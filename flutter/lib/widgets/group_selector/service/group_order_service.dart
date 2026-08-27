import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/shared_preferences_service.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_order_service.g.dart';

@riverpod
class GroupOrderService extends _$GroupOrderService {
  @override
  List<String> build() {
    final userGroupList = ref.watch(
      userGroupServiceProvider.select((e) => e.value?.map((e) => e.groupId).toList() ?? [],),
    );
    if (userGroupList.isEmpty) {
      return [];
    } else {
      return _syncGroupsWithUserList(userGroupList);
    }
  }

  List<String> _syncGroupsWithUserList(List<String> userGroupList) {
    final sharedPrefs = ref.watch(sharedPreferencesProvider);
    final orderedGroups = sharedPrefs.getStringList('groupOrder') ?? [];
    final userGroupSet = Set<String>.from(userGroupList);
    final List<String> updatedGroups = orderedGroups.where(userGroupSet.contains).toList();
    updatedGroups.addAll(userGroupList.where((id) => !updatedGroups.contains(id)));
    sharedPrefs.setStringList('groupOrder', updatedGroups);
    return updatedGroups;
  }

  void setList(List<String> groupIds) {
    final sharedPrefs = ref.watch(sharedPreferencesProvider);
    sharedPrefs.setStringList('groupOrder', groupIds);
    state = groupIds;
  }
}

@riverpod
String roundGroupId(Ref ref) => throw UnimplementedError();

@riverpod
class GroupActiveService extends _$GroupActiveService {
  
  @override
  List<String> build() {
    final userGroups = ref.read(userGroupServiceProvider).value ?? [];
    final orderedIds = ref.watch(groupOrderServiceProvider);

    final backendActiveIds = <String>[];
    for (final id in orderedIds) {
      final group = userGroups.firstWhereOrNull(
        (g) => g.groupId == id
      );
      if (group != null && group.isActivated) {
        backendActiveIds.add(id);
      }
    }
    return backendActiveIds;
  }

  /// Toggles the activation state INSTANTLY locally, then calls the backend.
  void toggle(String groupId, bool isActive) {
    final orderedIds = ref.read(groupOrderServiceProvider);
    final currentActiveSet = state.toSet();

    if (!isActive && currentActiveSet.contains(groupId)) {
      currentActiveSet.remove(groupId);
    } else if (isActive && !currentActiveSet.contains(groupId)) {
      currentActiveSet.add(groupId);
    }

    state = orderedIds.where((id) => currentActiveSet.contains(id)).toList();
    ref.read(userGroupServiceProvider.notifier).setIsActive(groupId, isActive);
  }
}
