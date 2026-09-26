import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/entity/user_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/like_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/achievement/data/achievement_provider.dart';
import 'package:buff_lisa/features/achievement/presentation/user_achievements_tab.dart';
import 'package:buff_lisa/features/profile/presentation/user_profile.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('shows achievements in a separate signed-in profile tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userIdProvider.overrideWithValue('alice'),
          userXpProvider('alice').overrideWith((ref) => null),
          userByIdSelectedBatchProvider('alice').overrideWith((ref) => null),
          achievementsProvider.overrideWith(_TestAchievements.new),
          currentUserProvider.overrideWith(
            (ref) => UserEntity(
              userId: 'alice',
              username: 'Alice',
              ttl: DateTime(2025),
              onlySession: false,
            ),
          ),
          pinUserServiceProvider('alice')
              .overrideWith(_EmptyPinUserService.new),
          userLikeServiceProvider('alice')
              .overrideWith(_EmptyUserLikeService.new),
          getUserProfileProvider('alice')
              .overrideWith((ref) => Stream.value(null)),
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
        ],
        child: const MaterialApp(home: UserProfile()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('First stick'), findsNothing);

    await tester.tap(find.text('Achievements'));
    await tester.pumpAndSettle();

    expect(find.text('Sticks'), findsNWidgets(2));
    expect(find.text('0/3 earned'), findsOneWidget);
    expect(find.text('First stick'), findsOneWidget);
    expect(find.text('Easy · 20 XP'), findsNWidgets(2));
    expect(find.text('Claim 20 XP'), findsOneWidget);

    final achievementScrollables = find.descendant(
      of: find.byType(UserAchievementsTab),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Stick collector'),
      250,
      scrollable: achievementScrollables.first,
    );
    expect(find.text('Stick collector'), findsOneWidget);
    expect(find.text('3/10'), findsOneWidget);
    expect(find.text('Keep going to unlock this reward'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Dedicated collector'),
      250,
      scrollable: achievementScrollables.first,
    );
    expect(find.text('XP already earned'), findsOneWidget);
    expect(find.text('Restore badge'), findsOneWidget);
  });
}

class _TestAchievements extends Achievements {
  @override
  Future<List<UserAchievementsDtoInner>> build() => Future.value([
    UserAchievementsDtoInner(
      achievementId: 3,
      name: 'First stick',
      description: 'Add your first stick.',
      track: 'sticks',
      difficulty: 'easy',
      rewardXp: 20,
      claimable: true,
      definitionVersion: 2,
      claimed: false,
      thresholdValue: 1,
      currentValue: 1,
      thresholdUp: true,
    ),
    UserAchievementsDtoInner(
      achievementId: 9,
      claimed: false,
      thresholdValue: 10,
      currentValue: 3,
      thresholdUp: true,
    ),
    UserAchievementsDtoInner(
      achievementId: 12,
      name: 'Dedicated collector',
      description: 'Add fifty sticks.',
      track: 'sticks',
      difficulty: 'hard',
      rewardXp: 100,
      claimable: true,
      rewardAvailable: false,
      definitionVersion: 2,
      claimed: false,
      thresholdValue: 50,
      currentValue: 50,
      thresholdUp: true,
    ),
  ]);
}

class _EmptyPinUserService extends PinUserService {
  @override
  Stream<List<PinEntity>> build(String userId) => Stream.value([]);
}

class _EmptyUserLikeService extends UserLikeService {
  @override
  Future<UserLikesDto> build(String userId) async => UserLikesDto(
    likeCount: 0,
    likeArtCount: 0,
    likeLocationCount: 0,
    likePhotographyCount: 0,
  );
}

class _EmptyUserGroupService extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}
