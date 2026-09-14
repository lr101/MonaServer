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
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/pop_up_menu_leave.dart';
import 'package:buff_lisa/features/group_overview/presentation/user_group_overview.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('successful leave returns to the previous route', (tester) async {
    final group = GroupEntity(
      groupId: 'group-id',
      name: 'Group',
      visibility: 0,
      userIsMember: true,
      groupAdmin: 'another-user',
      ttl: DateTime.now(),
      onlySession: false,
    );

    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'user-id',
              refreshToken: null,
              cameras: [],
            ),
          ),
          memberServiceProvider('group-id')
              .overrideWith(_EmptyMemberService.new),
          userGroupServiceProvider.overrideWith(
            () => _RemovingLeaveUserGroupService(
              onLeave: () => visible.value = false,
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/home',
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => ElevatedButton(
                  onPressed: () => context.push('/group'),
                  child: const Text('Open group'),
                ),
              ),
              GoRoute(
                path: '/group',
                builder: (context, state) => ValueListenableBuilder<bool>(
                  valueListenable: visible,
                  builder: (context, isVisible, child) => Scaffold(
                    appBar: isVisible
                        ? AppBar(actions: [PopUpMenuLeave(groupDto: group)])
                        : null,
                    body: isVisible ? null : const Text('Group not found'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Open group'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Leave Group'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Leave'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Open group'), findsOneWidget);
  });

  testWidgets('pending leave does not pop a newer route', (tester) async {
    final group = GroupEntity(
      groupId: 'group-id',
      name: 'Group',
      visibility: 0,
      userIsMember: true,
      groupAdmin: 'another-user',
      ttl: DateTime.now(),
      onlySession: false,
    );
    final leaveResult = Completer<String?>();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => ElevatedButton(
            onPressed: () => context.push('/group'),
            child: const Text('Open group'),
          ),
        ),
        GoRoute(
          path: '/group',
          builder: (context, state) => Scaffold(
            appBar: AppBar(actions: [PopUpMenuLeave(groupDto: group)]),
          ),
        ),
        GoRoute(
          path: '/other',
          builder: (context, state) => const Text('Other route'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalDataOnceProvider.overrideWithValue(
            const GlobalDataDto(
              userId: 'user-id',
              refreshToken: null,
              cameras: [],
            ),
          ),
          memberServiceProvider('group-id')
              .overrideWith(_EmptyMemberService.new),
          userGroupServiceProvider.overrideWith(
            () => _PendingLeaveUserGroupService(leaveResult.future),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Open group'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Leave Group'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Leave'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    router.go('/other');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    leaveResult.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Other route'), findsOneWidget);
  });

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

class _RemovingLeaveUserGroupService extends UserGroupService {
  _RemovingLeaveUserGroupService({required this.onLeave});

  final VoidCallback onLeave;

  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);

  @override
  Future<String?> leaveGroup(String groupId) async {
    onLeave();
    await Future<void>.delayed(Duration.zero);
    return null;
  }
}

class _PendingLeaveUserGroupService extends UserGroupService {
  _PendingLeaveUserGroupService(this.leaveResult);

  final Future<String?> leaveResult;

  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);

  @override
  Future<String?> leaveGroup(String groupId) => leaveResult;
}
