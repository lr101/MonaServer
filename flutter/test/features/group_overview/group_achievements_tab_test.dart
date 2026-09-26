import 'dart:typed_data';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/member_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_details_service.dart';
import 'package:buff_lisa/data/service/member_service.dart';
import 'package:buff_lisa/features/group_overview/presentation/sub_widgets/group_overview.dart';
import 'package:buff_lisa/features/progression/data/group_achievement_provider.dart';
import 'package:buff_lisa/features/progression/data/group_xp_provider.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('keeps group progression in its own profile tab', (tester) async {
    final group = GroupEntity(
      groupId: 'group-id',
      name: 'Group',
      visibility: 0,
      userIsMember: true,
      groupAdmin: 'alice',
      ttl: DateTime(2025),
      onlySession: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userIdProvider.overrideWithValue('alice'),
          memberServiceProvider('group-id')
              .overrideWith(_EmptyMemberService.new),
          groupAchievementsProvider('group-id').overrideWith(
            (ref) => [
              GroupAchievementsDtoInner(
                achievementId: 1,
                name: 'First group milestone',
                description: 'Add group pins.',
                track: 'pins',
                claimed: false,
                claimable: false,
                thresholdValue: 5,
                currentValue: 2,
                thresholdUp: true,
                rewardPinStyle:
                    GroupAchievementsDtoInnerRewardPinStyleEnum.moss,
              ),
            ],
          ),
          groupProgressionProvider('group-id').overrideWith(
            (ref) => GroupProgressionDto(
              groupId: 'group-id',
              totalXp: 140,
              currentLevel: 2,
              currentLevelXp: 40,
              nextLevelXp: 100,
            ),
          ),
          groupDetailsPinsProvider('group-id')
              .overrideWith((ref) => const AsyncData<List<PinEntity>?>([])),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
        ],
        child: MaterialApp(
          home: GroupOverview(
            groupId: 'group-id',
            details: GroupDetailsState(
              group: group,
              pins: const AsyncData<List<PinEntity>>([]),
              profileImage: const AsyncData<Uint8List?>(null),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First group milestone'), findsNothing);
    expect(find.text('Group level 2'), findsNothing);
    expect(find.text('Achievements'), findsOneWidget);

    await tester.tap(find.text('Achievements'));
    await tester.pumpAndSettle();

    expect(find.text('First group milestone'), findsOneWidget);
    expect(find.text('Group level 2'), findsOneWidget);
  });
}

class _EmptyMemberService extends MemberService {
  @override
  Stream<List<MemberEntity>> build(String groupId) => Stream.value([]);
}
