import 'dart:async';
import 'dart:typed_data';

import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/repository/global_data_repository.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
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
    final ready = Completer<GroupDetailsState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          groupDetailsProvider('group-id').overrideWith((ref) async* {
            yield await ready.future;
          }),
          memberServiceProvider('group-id')
              .overrideWith(_EmptyMemberService.new),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
          defaultGroupPinImageProvider.overrideWithValue(kTransparentImage),
        ],
        child: const MaterialApp(home: UserGroupOverview(groupId: 'group-id')),
      ),
    );
    await tester.pump();

    expect(find.byType(GroupOverview), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    ready.complete(_details(group));
    await tester.pump();

    expect(find.byType(GroupOverview), findsOneWidget);
  });

  testWidgets('uses refreshed visibility when the cached row is stale', (
    tester,
  ) async {
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
          groupDetailsProvider('group-id')
              .overrideWith((ref) => Stream.value(_details(refreshedGroup))),
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
    final details = StreamController<GroupDetailsState>();
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
          groupDetailsProvider('group-id')
              .overrideWith((ref) => details.stream),
          memberServiceProvider('group-id')
              .overrideWith(_EmptyMemberService.new),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
          defaultGroupPinImageProvider.overrideWithValue(kTransparentImage),
        ],
        child: const MaterialApp(home: UserGroupOverview(groupId: 'group-id')),
      ),
    );

    details.add(_details(publicGroup));
    await tester.pump();
    expect(find.byType(GroupOverview), findsOneWidget);

    details.add(_details(privateGroup));
    await tester.pump();
    expect(find.byType(GroupOverview), findsNothing);
    expect(find.byIcon(Icons.lock), findsOneWidget);

    details.add(_details(memberGroup));
    await tester.pump();
    expect(find.byType(GroupOverview), findsOneWidget);
  });

  testWidgets('renders a terminal state when a group is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupDetailsProvider('group-id').overrideWith(
            (ref) => Stream.value(
              const GroupDetailsState(
                group: null,
                pins: AsyncData<List<PinEntity>>([]),
                profileImage: AsyncData<Uint8List?>(null),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: UserGroupOverview(groupId: 'group-id')),
      ),
    );
    await tester.pump();

    expect(find.text('Group not found'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

GroupDetailsState _details(GroupEntity group) => GroupDetailsState(
  group: group,
  pins: const AsyncData<List<PinEntity>>([]),
  profileImage: const AsyncData<Uint8List?>(null),
);

class _EmptyUserGroupService extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}

class _EmptyMemberService extends MemberService {
  @override
  Stream<List<MemberEntity>> build(String groupId) => Stream.value([]);
}
