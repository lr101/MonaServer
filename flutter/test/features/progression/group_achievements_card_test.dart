import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/features/progression/data/group_achievement_provider.dart';
import 'package:buff_lisa/features/progression/presentation/group_achievements_card.dart';
import 'package:buff_lisa/features/progression/presentation/group_achievements_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
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
    expect(find.text('10 / 10 active pins'), findsOneWidget);
    expect(find.text('Moss frame reward'), findsOneWidget);
    expect(find.text('Claim'), findsOneWidget);

    await tester.tap(find.text('Claim'));
    await tester.pump();
    expect(claimedId, 1);
  });

  testWidgets('admins can choose only pin frames the group has unlocked', (
    tester,
  ) async {
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

    expect(find.text('Pin appearance'), findsOneWidget);
    expect(find.text('Moss'), findsOneWidget);
    expect(find.text('Sunset'), findsNothing);

    await tester.tap(find.text('Moss'));
    await tester.pump();
    expect(selectedStyle, 'moss');
  });

  testWidgets('public progress does not let a non-member claim a reward', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupAchievementsCard(
            achievements: [_achievement()],
            group: _group(member: false),
            currentUserId: 'visitor',
            onClaimAchievement: (_) async {},
            onPinStyleSelected: (_) => Future<String?>.value(),
          ),
        ),
      ),
    );

    expect(find.text('Join to claim'), findsOneWidget);
    expect(find.text('Claim'), findsNothing);
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

    expect(find.text('Checking membership'), findsOneWidget);
    expect(find.text('Claim'), findsNothing);
  });

  testWidgets('panel claims a reward and saves the shared pin frame', (
    tester,
  ) async {
    final groupsApi = _RecordingGroupsApi();
    final groupServiceCalls = _UserGroupServiceCalls();
    var fetches = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userIdProvider.overrideWithValue('member-1'),
          groupApiProvider.overrideWithValue(groupsApi),
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

    await tester.tap(find.text('Claim'));
    await tester.pumpAndSettle();
    expect(groupsApi.claimedAchievementId, 1);
    expect(fetches, 2);
    expect(find.byKey(const ValueKey('claimed-achievement')), findsOneWidget);

    await tester.tap(find.text('Moss'));
    await tester.pumpAndSettle();
    expect(groupServiceCalls.updatedStyle, UpdateGroupDtoPinStyleEnum.moss);
    expect(groupServiceCalls.updatedGroupId, 'group-1');
  });
}

GroupAchievementsDtoInner _achievement({
  int achievementId = 1,
  bool claimed = false,
  bool claimable = true,
  int currentValue = 10,
  GroupAchievementsDtoInnerRewardPinStyleEnum rewardPinStyle =
      GroupAchievementsDtoInnerRewardPinStyleEnum.moss,
}) => GroupAchievementsDtoInner(
  achievementId: achievementId,
  name: 'Pins $achievementId',
  description: 'Add active pins to your group',
  track: 'active_pins',
  difficulty: GroupAchievementsDtoInnerDifficultyEnum.easy,
  claimed: claimed,
  claimable: claimable,
  thresholdValue: achievementId == 1 ? 10 : 25,
  currentValue: currentValue,
  thresholdUp: true,
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
