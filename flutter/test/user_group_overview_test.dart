import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/group_overview.dart';
import 'package:buff_lisa/features/group_overview/presentation/user_group_overview.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transparent_image/transparent_image.dart';

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
          groupDetailsReadyProvider('group-id').overrideWith((ref) async* {
            yield await ready.future;
          }),
          groupProfilePictureByIdProvider('group-id')
              .overrideWith((ref) => Stream<Uint8List?>.value(null)),
          memberServiceProvider('group-id')
              .overrideWith(_EmptyMemberService.new),
          sortedGroupPinsProvider('group-id')
              .overrideWith((ref) => Future<List<PinEntity>?>.value([])),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
          defaultGroupPinImageProvider.overrideWithValue(kTransparentImage),
        ],
        child: const MaterialApp(home: UserGroupOverview(groupId: 'group-id')),
      ),
    );
    await tester.pump();

    expect(find.byType(GroupOverview), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    ready.complete(group);
    await tester.pump();

    expect(find.byType(GroupOverview), findsOneWidget);
  });

  testWidgets('uses refreshed visibility when the cached row is stale', (
    tester,
  ) async {
    final cachedGroup = GroupEntity(
      groupId: 'group-id',
      name: 'Cached public group',
      visibility: 0,
      userIsMember: false,
      ttl: DateTime.now(),
      onlySession: true,
    );
    final refreshedGroup = GroupEntity(
      groupId: 'group-id',
      name: 'Private group',
      visibility: 1,
      userIsMember: false,
      ttl: DateTime.now(),
      onlySession: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupServiceProvider('group-id')
              .overrideWith(() => _FakeGroupService(cachedGroup)),
          groupDetailsReadyProvider('group-id')
              .overrideWith((ref) => Stream.value(refreshedGroup)),
          groupProfilePictureByIdProvider('group-id')
              .overrideWith((ref) => Stream<Uint8List?>.value(null)),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
          defaultGroupPinImageProvider.overrideWithValue(kTransparentImage),
        ],
        child: const MaterialApp(home: UserGroupOverview(groupId: 'group-id')),
      ),
    );
    await tester.pump();

    expect(find.byType(GroupOverview), findsNothing);
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets('updates the overview when group details change', (tester) async {
    final publicGroup = GroupEntity(
      groupId: 'group-id',
      name: 'Public group',
      visibility: 0,
      userIsMember: false,
      ttl: DateTime.now(),
      onlySession: true,
    );
    final privateGroup = GroupEntity(
      groupId: 'group-id',
      name: 'Private group',
      visibility: 1,
      userIsMember: false,
      ttl: DateTime.now(),
      onlySession: true,
    );
    final memberGroup = GroupEntity(
      groupId: 'group-id',
      name: 'Member group',
      visibility: 0,
      userIsMember: true,
      ttl: DateTime.now(),
      onlySession: false,
    );
    final details = StreamController<GroupEntity?>();
    addTearDown(details.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'user-id',
              refreshToken: null,
              cameras: [],
            ),
          ),
          groupServiceProvider('group-id')
              .overrideWith(() => _FakeGroupService(publicGroup)),
          groupDetailsReadyProvider('group-id')
              .overrideWith((ref) => details.stream),
          groupProfilePictureByIdProvider('group-id')
              .overrideWith((ref) => Stream<Uint8List?>.value(null)),
          memberServiceProvider('group-id')
              .overrideWith(_EmptyMemberService.new),
          sortedGroupPinsProvider('group-id')
              .overrideWith((ref) => Future<List<PinEntity>?>.value([])),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
          defaultGroupPinImageProvider.overrideWithValue(kTransparentImage),
        ],
        child: const MaterialApp(home: UserGroupOverview(groupId: 'group-id')),
      ),
    );

    details.add(publicGroup);
    await tester.pump();
    expect(find.byType(GroupOverview), findsOneWidget);

    details.add(privateGroup);
    await tester.pump();
    expect(find.byType(GroupOverview), findsNothing);
    expect(find.byIcon(Icons.lock), findsOneWidget);

    details.add(memberGroup);
    await tester.pump();
    expect(find.byType(GroupOverview), findsOneWidget);
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

class _EmptyMemberService extends MemberService {
  @override
  Stream<List<MemberEntity>> build(String groupId) => Stream.value([]);
}
