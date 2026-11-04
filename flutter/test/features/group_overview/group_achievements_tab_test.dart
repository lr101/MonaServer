import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/group_overview.dart';
import 'package:buff_lisa/features/progression/data/group_achievement_provider.dart';
import 'package:buff_lisa/features/progression/data/group_xp_provider.dart';
import 'package:buff_lisa/features/progression/presentation/small_profile_picture.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

import '../../support/pin_image_test_cache.dart';

void main() {
  testWidgets('keeps XP in the profile header while achievements change tabs', (
    tester,
  ) async {
    final group = GroupEntity(
      groupId: 'group-id',
      name:
          'Northern Quarter Street Art Collective with a very long group name',
      visibility: 0,
      userIsMember: true,
      groupAdmin: 'alice',
      ttl: DateTime(2025),
      onlySession: false,
    );

    final groupState = ValueNotifier(group);
    addTearDown(groupState.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinImageSourcesProvider.overrideWithValue(createTestImageSources()),
          userIdProvider.overrideWithValue('alice'),
          memberServiceProvider('group-id')
              .overrideWith(_EmptyMemberService.new),
          groupAchievementsProvider('group-id').overrideWith(
            (ref) => [
              GroupAchievementsDtoInner(
                achievementId: 1,
                name: 'Gatherer',
                description: 'Add group pins.',
                track: 'active_pins',
                claimed: false,
                claimable: false,
                thresholdValue: 40,
                currentValue: 2,
                thresholdUp: true,
                difficulty: GroupAchievementsDtoInnerDifficultyEnum.easy,
                rewardType: GroupAchievementsDtoInnerRewardTypeEnum.xp,
                rewardXp: 50,
                rewardPinStyle:
                    GroupAchievementsDtoInnerRewardPinStyleEnum.moss,
              ),
            ],
          ),
          groupProgressionProvider('group-id').overrideWith(
            (ref) => GroupProgressionDto(
              groupId: 'group-id',
              totalXp: 70,
              currentLevel: 2,
              currentLevelXp: 40,
              nextLevelXp: 100,
            ),
          ),
          groupDetailsPinsProvider('group-id').overrideWith(
            (ref) => AsyncData<List<PinEntity>?>([
              PinEntity(
                pinId: 'place',
                latitude: 48.1,
                longitude: 11.6,
                creationDate: DateTime.utc(2026),
                creator: 'alice',
                groupId: 'group-id',
                ttl: DateTime.utc(2027),
                onlySession: false,
              ),
            ]),
          ),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
        ],
        child: MaterialApp(
          home: ValueListenableBuilder<GroupEntity>(
            valueListenable: groupState,
            builder: (_, currentGroup, _) => GroupOverview(
              groupId: 'group-id',
              details: GroupDetailsState(
                group: currentGroup,
                pins: const AsyncData<List<PinEntity>>([]),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gatherer'), findsNothing);
    expect(find.text('Group level 2 · 70 XP'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Achievements'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(UserXpAvatarIndicator)).dx, 17);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      0.5,
    );
    expect(
      find.byTooltip(
        'Level 2, 70 total XP, 30 of 60 XP into this level, '
        '30 XP to next level',
      ),
      findsOneWidget,
    );
    expect(find.text('Sticks'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byTooltip('Achievements'));
    await tester.pumpAndSettle();

    expect(find.text('Gatherer'), findsOneWidget);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Group level 2 · 70 XP'), findsNothing);
    expect(find.byTooltip('Group settings'), findsOneWidget);
    expect(find.byTooltip('Share group'), findsNothing);
    expect(tester.widget<TabBar>(find.byType(TabBar)).tabs.length, 3);
    groupState.value = (group.copyWith()..userIsMember = false);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Group settings'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 2);
  });
}

class _EmptyMemberService extends MemberService {
  @override
  Stream<List<MemberEntity>> build(String groupId) => Stream.value([]);
}
