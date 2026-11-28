import 'dart:typed_data';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/features/achievement/presentation/achievement_card.dart';
import 'package:buff_lisa/features/progression/data/group_achievement_provider.dart';
import 'package:buff_lisa/features/progression/data/group_xp_provider.dart';
import 'package:buff_lisa/features/progression/presentation/group_achievements_card.dart';
import 'package:buff_lisa/features/progression/presentation/group_achievements_panel.dart';
import 'package:buff_lisa/widgets/custom_marker/data/group_pin_design_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  testWidgets('shows photo update and gone pin achievement tracks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupAchievementsCard(
            achievements: [
              _achievement(achievementId: 13, track: 'photo_updates'),
              _achievement(achievementId: 16, track: 'gone_pins'),
            ],
            group: _group(),
            currentUserId: 'member-1',
            onClaimAchievement: (_) async {},
            onPinStyleSelected: (_) async => null,
          ),
        ),
      ),
    );

    expect(find.textContaining('Photo updates ·'), findsOneWidget);
    expect(find.textContaining('Gone pins ·'), findsOneWidget);
  });

  testWidgets('group hard achievement rewards describe geometric shapes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupAchievementsCard(
            achievements: [
              _achievement(
                achievementId: 18,
                track: 'gone_pins',
                name: 'Steward',
                difficulty: GroupAchievementsDtoInnerDifficultyEnum.hard,
                rewardType: GroupAchievementsDtoInnerRewardTypeEnum.badge,
                thresholdValue: 50,
                currentValue: 0,
                claimable: false,
              ),
            ],
            group: _group(),
            currentUserId: 'member-1',
            onClaimAchievement: (_) async {},
            onPinStyleSelected: (_) async => null,
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(AchievementCard));
    expect(semantics.label, contains('unlocks teardrop shape'));
  });

  testWidgets('shows progress and claims a ready group achievement', (
    tester,
  ) async {
    int? claimedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupAchievementsCard(
            achievements: [_achievement()],
            group: _group(),
            currentUserId: 'member-1',
            onClaimAchievement: (id) async => claimedId = id,
            onPinStyleSelected: (_) async => null,
          ),
        ),
      ),
    );

    expect(find.text('Group achievements'), findsOneWidget);
    expect(find.textContaining('Pins · 10 / 40'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Claim'), findsNothing);

    await tester.tap(find.text('Pins 1'));
    await tester.pumpAndSettle();
    expect(claimedId, isNull);
    await tester.tap(find.text('Collect reward'));
    await tester.pumpAndSettle();
    expect(claimedId, 1);
  });

  testWidgets('pin editing lives in group settings', (tester) async {
    String? selectedStyle;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupAchievementsCard(
            achievements: [
              _achievement(claimed: true, claimable: false),
              _achievement(
                achievementId: 2,
                rewardPinStyle:
                    GroupAchievementsDtoInnerRewardPinStyleEnum.sunset,
                claimable: false,
                currentValue: 14,
              ),
            ],
            group: _group(admin: 'member-1'),
            currentUserId: 'member-1',
            onClaimAchievement: (_) async {},
            onPinStyleSelected: (style) {
              selectedStyle = style;
              return Future<String?>.value();
            },
          ),
        ),
      ),
    );

    expect(find.text('Pin appearance'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(selectedStyle, isNull);
  });

  testWidgets('a half-finished milestone fills half its card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupAchievementsCard(
            achievements: [_achievement(currentValue: 20, claimable: false)],
            group: _group(),
            currentUserId: 'member-1',
            onClaimAchievement: (_) async {},
            onPinStyleSelected: (_) async => null,
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
    );
  });

  testWidgets('public progress does not let a non-member claim a reward', (
    tester,
  ) async {
    var claims = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupAchievementsCard(
            achievements: [_achievement()],
            group: _group(member: false),
            currentUserId: 'visitor',
            onClaimAchievement: (_) async => claims++,
            onPinStyleSelected: (_) => Future<String?>.value(),
          ),
        ),
      ),
    );

    expect(find.text('Claim'), findsNothing);
    await tester.tap(find.text('Pins 1'));
    await tester.pump();
    expect(claims, 0);
  });

  testWidgets('unknown membership shows a pending state and disables claim', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupAchievementsCard(
            achievements: [_achievement()],
            group: null,
            currentUserId: 'member-1',
            onClaimAchievement: (_) async {},
            onPinStyleSelected: (_) => Future<String?>.value(),
          ),
        ),
      ),
    );

    expect(find.text('Claim'), findsNothing);
  });

  testWidgets('panel claims a reward and leaves pin editing to settings', (
    tester,
  ) async {
    final groupsApi = _RecordingGroupsApi();
    final groupServiceCalls = _UserGroupServiceCalls();
    var fetches = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountSessionProvider.overrideWithValue(AccountSession(true)),
          groupProgressionProvider('group-1').overrideWith((ref) => null),
          userIdProvider.overrideWithValue('member-1'),
          groupApiProvider.overrideWithValue(groupsApi),
          groupProfilePictureSmallByIdProvider('group-1')
              .overrideWith((ref) => const Stream<Uint8List?>.empty()),
          groupPinDesignCatalogProvider('group-1').overrideWith((ref) => null),
          userGroupServiceProvider.overrideWith(
            () => _RecordingUserGroupService(groupServiceCalls),
          ),
          groupAchievementsProvider('group-1').overrideWith((ref) {
            fetches++;
            return Future.value([
              _achievement(claimed: fetches > 1, claimable: fetches == 1),
            ]);
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: GroupAchievementsPanel(
              groupId: 'group-1',
              group: _group(admin: 'member-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pins 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collect reward'));
    await tester.pumpAndSettle();
    expect(groupsApi.claimedAchievementId, 1);
    expect(fetches, 2);
    expect(find.text('Pins 1'), findsOneWidget);

    expect(find.byType(ChoiceChip), findsNothing);
    expect(groupServiceCalls.updatedStyle, isNull);
  });
}

GroupAchievementsDtoInner _achievement({
  int achievementId = 1,
  String track = 'active_pins',
  String? name,
  GroupAchievementsDtoInnerDifficultyEnum difficulty =
      GroupAchievementsDtoInnerDifficultyEnum.easy,
  GroupAchievementsDtoInnerRewardTypeEnum? rewardType =
      GroupAchievementsDtoInnerRewardTypeEnum.xp,
  int? rewardXp,
  int? thresholdValue,
  bool claimed = false,
  bool claimable = true,
  int currentValue = 10,
  GroupAchievementsDtoInnerRewardPinStyleEnum rewardPinStyle =
      GroupAchievementsDtoInnerRewardPinStyleEnum.moss,
}) => GroupAchievementsDtoInner(
  achievementId: achievementId,
  name: name ?? 'Pins $achievementId',
  description: 'Add active pins to your group',
  track: track,
  difficulty: difficulty,
  claimed: claimed,
  claimable: claimable,
  thresholdValue:
      thresholdValue ??
      switch (achievementId) {
        1 => 40,
        2 => 100,
        3 => 200,
        4 => 2,
        5 => 400,
        6 => 1000,
        7 => 2,
        8 => 20,
        9 => 60,
        10 => 10,
        11 => 60,
        12 => 200,
        _ => 2,
      },
  currentValue: currentValue,
  thresholdUp: true,
  rewardType: rewardType,
  rewardXp: rewardXp,
  rewardPinStyle: rewardPinStyle,
);

GroupEntity _group({String admin = 'another-member', bool member = true}) =>
    GroupEntity(
      groupId: 'group-1',
      name: 'Trail Friends',
      visibility: 0,
      userIsMember: member,
      groupAdmin: admin,
      ttl: DateTime.now(),
      onlySession: false,
    );

class _RecordingGroupsApi extends GroupsApi {
  int? claimedAchievementId;

  @override
  Future<void> claimGroupAchievement(String groupId, int achievementId) async {
    claimedAchievementId = achievementId;
  }
}

class _RecordingUserGroupService extends UserGroupService {
  _RecordingUserGroupService(this.calls);

  final _UserGroupServiceCalls calls;

  @override
  Stream<List<GroupEntity>> build() => const Stream.empty();

  @override
  Future<String?> updateGroup(UpdateGroupDto data, String groupId) async {
    calls.updatedStyle = data.pinStyle;
    calls.updatedGroupId = groupId;
    return null;
  }
}

class _UserGroupServiceCalls {
  UpdateGroupDtoPinStyleEnum? updatedStyle;
  String? updatedGroupId;
}
