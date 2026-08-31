import 'dart:async';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/group_overview.dart';
import 'package:buff_lisa/features/group_overview/presentation/user_group_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('waits for public group hydration before rendering details', (
    tester,
  ) async {
    final group = GroupEntity(
      groupId: 'group-id',
      name: 'Public group',
      visibility: 0,
      userIsMember: false,
      ttl: DateTime.now(),
      onlySession: true,
    );
    final ready = Completer<GroupEntity?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupServiceProvider('group-id')
              .overrideWith(() => _FakeGroupService(group)),
          groupDetailsReadyProvider('group-id')
              .overrideWith((ref) => ready.future),
        ],
        child: const MaterialApp(home: UserGroupOverview(groupId: 'group-id')),
      ),
    );
    await tester.pump();

    expect(find.byType(GroupOverview), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    ready.complete(group);
  });
}

class _EmptyUserGroupService extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}

class _FakeGroupService extends GroupService {
  _FakeGroupService(this.group);

  final GroupEntity group;

  @override
  Stream<GroupEntity?> build(String groupId) => Stream.value(group);

  @override
  Future<GroupEntity?> hydrate() async => group;
}
