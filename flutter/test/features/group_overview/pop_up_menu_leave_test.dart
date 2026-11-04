import 'dart:async';

import 'package:buff_lisa/data/dto/global_data_dto.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/features/group_edit/presentation/group_edit.dart';
import 'package:buff_lisa/features/group_overview/presentation/group_settings_page.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart' as api;
import 'package:transparent_image/transparent_image.dart';

import '../../support/pin_image_test_cache.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(
      envString: 'API_HOST=https://preview-api.example.test',
    );
  });
  tearDown(dotenv.clean);

  testWidgets(
    'group settings shares its invite link and preserves clipboard fallback',
    (tester) async {
      final group = _memberGroup(inviteUrl: 'a1b2c3');
      String? clipboardText;
      Map<String, dynamic>? sharedContent;
      var shareUnavailable = false;
      const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map<String, dynamic>)['text'] as String;
          }
          return null;
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        shareChannel,
        (call) async {
          if (call.method == 'share') {
            if (shareUnavailable) {
              throw PlatformException(code: 'share_unavailable');
            }
            sharedContent = Map<String, dynamic>.from(
              call.arguments as Map<Object?, Object?>,
            );
          }
          return 'dev.fluttercommunity.plus/share/unavailable';
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          shareChannel,
          null,
        );
      });

      await _pumpGroupOverview(tester, group);

      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Save changes'), findsNothing);
      final shareButton = find.text('Share group');
      expect(shareButton, findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(
        find.text('Full group description available in settings.'),
        findsOneWidget,
      );
      expect(find.text('Group settings'), findsOneWidget);
      expect(find.byType(PopupMenuButton<int>), findsNothing);

      await tester.tap(shareButton);
      await tester.pumpAndSettle();

      expect(sharedContent?['title'], 'Join Public group');
      expect(
        sharedContent?['text'],
        'Join Public group on Stick-It: '
        'https://preview-api.example.test/#/groups/group-id?invite=a1b2c3',
      );
      expect(clipboardText, isNull);

      shareUnavailable = true;
      await tester.tap(shareButton);
      await tester.pumpAndSettle();

      expect(
        clipboardText,
        'https://preview-api.example.test/#/groups/group-id?invite=a1b2c3',
      );
      expect(find.text('Share unavailable. Link copied.'), findsOneWidget);
    },
  );

  testWidgets('member group without an invite link hides the share action', (
    tester,
  ) async {
    await _pumpGroupOverview(tester, _memberGroup());
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }

    expect(find.text('Share group'), findsNothing);
    expect(find.text('Group settings'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('admin edits and saves directly on group settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final events = StreamController<GroupDetailsState>();
    addTearDown(events.close);
    final group = _memberGroup(inviteUrl: 'invite');
    final calls = _EditCalls();
    calls.onUpdate = (data) => events.add(
      _details(
        GroupEntity(
          groupId: group.groupId,
          name: data.name ?? group.name,
          description: data.description ?? group.description,
          inviteUrl: group.inviteUrl,
          visibility: data.visibility ?? group.visibility,
          userIsMember: true,
          groupAdmin: data.groupAdmin ?? group.groupAdmin,
          ttl: group.ttl,
          onlySession: false,
        ),
      ),
    );
    await _pumpGroupOverview(
      tester,
      group,
      admin: true,
      calls: calls,
      updates: events.stream,
    );
    events.add(_details(group));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('Edit group'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, 'Updated group');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(calls.update?.name, 'Updated group');
    expect(calls.update?.groupAdmin, 'alice');
    expect(find.text('Group settings'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bob').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(calls.update?.groupAdmin, 'bob');
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Save changes'), findsNothing);
    expect(find.text('Group settings'), findsOneWidget);
  });

  testWidgets(
    'switching groups does not reuse the selected admin or another group draft',
    (tester) async {
      final first = _memberGroup();
      final second = GroupEntity(
        groupId: 'second',
        name: 'Second group',
        description: 'Other description',
        visibility: 0,
        userIsMember: true,
        groupAdmin: 'alice',
        ttl: DateTime(2027),
        onlySession: false,
      );
      final selected = ValueNotifier(first);
      addTearDown(selected.dispose);
      final calls = _EditCalls();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            globalDataServiceProvider.overrideWithValue(
              const GlobalDataDto(
                userId: 'alice',
                refreshToken: null,
                cameras: [],
              ),
            ),
            userGroupServiceProvider.overrideWith(
              () => _EmptyUserGroupService(calls),
            ),
            for (final group in [first, second]) ...[
              memberServiceProvider(group.groupId)
                  .overrideWith(_EmptyMemberService.new),
              groupProfilePictureByIdProvider(group.groupId)
                  .overrideWith((ref) => Stream.value(kTransparentImage)),
            ],
            defaultErrorImageProvider.overrideWithValue(kTransparentImage),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<GroupEntity>(
                valueListenable: selected,
                builder: (_, group, _) => GroupEdit(
                  groupid: group.groupId,
                  group: group,
                  embedded: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bob').last);
      await tester.pumpAndSettle();
      selected.value = second;
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(calls.update?.name, 'Second group');
      expect(calls.update?.groupAdmin, 'alice');
    },
  );

  for (final visibility in [0, 1]) {
    testWidgets(
      'settings do not expose information to non-members (visibility $visibility)',
      (tester) async {
        final group = _memberGroup(inviteUrl: 'a1b2c3', visibility: visibility)
          ..userIsMember = false;
        await _pumpGroupOverview(tester, group);
        await tester.pumpAndSettle();
        expect(
          find.text('Join this group to access its settings.'),
          findsOneWidget,
        );
        expect(
          find.text('Full group description available in settings.'),
          findsNothing,
        );
        expect(find.text('Public group'), findsNothing);
        for (final label in [
          'Share group',
          'Edit group',
          'Report group',
          'Leave group',
        ]) {
          expect(find.text(label), findsNothing);
        }
      },
    );
  }
}

GroupEntity _memberGroup({String? inviteUrl, int visibility = 0}) =>
    GroupEntity(
      groupId: 'group-id',
      name: 'Public group',
      description: 'Full group description available in settings.',
      visibility: visibility,
      userIsMember: true,
      inviteUrl: inviteUrl,
      groupAdmin: 'alice',
      ttl: DateTime(2025),
      onlySession: false,
    );

Future<void> _pumpGroupOverview(
  WidgetTester tester,
  GroupEntity group, {
  bool admin = false,
  _EditCalls? calls,
  Stream<GroupDetailsState>? updates,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pinImageSourcesProvider.overrideWithValue(createTestImageSources()),
        globalDataServiceProvider.overrideWithValue(
          GlobalDataDto(
            userId: admin ? 'alice' : 'member',
            refreshToken: null,
            cameras: const [],
          ),
        ),
        userGroupServiceProvider.overrideWith(
          () => _EmptyUserGroupService(calls),
        ),
        groupProfilePictureByIdProvider(group.groupId)
            .overrideWith((ref) => Stream.value(kTransparentImage)),
        groupDetailsProvider(group.groupId)
            .overrideWith((ref) => updates ?? Stream.value(_details(group))),
        memberServiceProvider(group.groupId)
            .overrideWith(_EmptyMemberService.new),
        defaultErrorImageProvider.overrideWithValue(kTransparentImage),
        defaultGroupPinImageProvider.overrideWithValue(kTransparentImage),
      ],
      child: MaterialApp(home: GroupSettingsPage(groupId: group.groupId)),
    ),
  );
  await tester.pump();
}

GroupDetailsState _details(GroupEntity group) =>
    GroupDetailsState(group: group, pins: const AsyncData<List<PinEntity>>([]));

class _EditCalls {
  api.UpdateGroupDto? update;
  void Function(api.UpdateGroupDto)? onUpdate;
}

class _EmptyUserGroupService extends UserGroupService {
  _EmptyUserGroupService(this.calls);
  final _EditCalls? calls;
  @override
  Future<String?> updateGroup(api.UpdateGroupDto data, String groupId) async {
    calls?.update = data;
    calls?.onUpdate?.call(data);
    return null;
  }

  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}

class _EmptyMemberService extends MemberService {
  @override
  Stream<List<MemberEntity>> build(String groupId) => Stream.value([
    MemberEntity(userId: 'alice', username: 'Alice'),
    MemberEntity(userId: 'bob', username: 'Bob'),
  ]);
}
