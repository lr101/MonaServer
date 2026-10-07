import 'dart:typed_data';

import 'package:buff_lisa/data/config/openapi_config.dart';
import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/image_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/entity/user_entity.dart';
import 'package:buff_lisa/data/repository/image_repository.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/like_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/achievement/data/achievement_provider.dart';
import 'package:buff_lisa/features/navigation/data/navigation_provider.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/features/profile/presentation/user_profile.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets(
    'profile counts contributed locations once and hides update text',
    (tester) async {
      final pin = PinEntity(
        pinId: 'location',
        latitude: 48.1,
        longitude: 11.6,
        creationDate: DateTime.utc(2026),
        creator: 'alice',
        groupId: 'group',
        ttl: DateTime.utc(2027),
        onlySession: false,
      );
      final update = pin.withPhotoUpdate(
        PinPhotoDto(
          id: 'update-photo',
          pinId: 'location',
          contributorId: 'alice',
          contributorUsername: 'Alice',
          observedAt: DateTime.utc(2026, 2),
          isOriginal: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userIdProvider.overrideWithValue('alice'),
            userXpProvider('alice').overrideWith((ref) => null),
            userByIdSelectedBatchProvider('alice').overrideWith((ref) => null),
            currentUserProvider.overrideWith(
              (ref) => UserEntity(
                userId: 'alice',
                username: 'Alice',
                ttl: DateTime(2025),
                onlySession: false,
              ),
            ),
            userPinEntriesProvider('alice')
                .overrideWith((ref) => Stream.value([pin, update])),
            userLikeServiceProvider('alice')
                .overrideWith(_EmptyUserLikeService.new),
            getUserProfileProvider('alice')
                .overrideWith((ref) => Stream.value(null)),
            userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
            pinImageRepositoryProvider.overrideWithValue(
              _ProfilePinImageRepository(),
            ),
            achievementsProvider.overrideWith(_TestAchievements.new),
            defaultErrorImageProvider.overrideWithValue(kTransparentImage),
          ],
          child: const MaterialApp(home: UserProfile()),
        ),
      );
      await tester.pumpAndSettle();

      final sticksStat = find
          .ancestor(of: find.text('Sticks'), matching: find.byType(Column))
          .first;
      expect(
        find.descendant(of: sticksStat, matching: find.text('1')),
        findsOneWidget,
      );
      expect(find.text('UPDATE'), findsNothing);
      expect(find.text('Update'), findsNothing);
    },
  );

  testWidgets('shows achievements in a separate signed-in profile tab', (
    tester,
  ) async {
    final usersApi = _RecordingUsersApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userApiProvider.overrideWithValue(usersApi),
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
          userPinEntriesProvider('alice')
              .overrideWith((ref) => Stream.value([])),
          userLikeServiceProvider('alice')
              .overrideWith(_EmptyUserLikeService.new),
          getUserProfileProgressiveProvider('alice')
              .overrideWith((ref) => Stream.value(null)),
          userGroupServiceProvider.overrideWith(_EmptyUserGroupService.new),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const UserProfile(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('Creator'), findsNothing);

    await tester.tap(find.text('Achievements'));
    await tester.pumpAndSettle();

    expect(find.text('Photo updates'), findsOneWidget);
    expect(find.text('Gone pins'), findsOneWidget);
    expect(find.text('Fresh perspective'), findsOneWidget);
    expect(find.text('Good catch'), findsOneWidget);
    expect(find.text('0/3 earned'), findsNothing);
    expect(find.text('Creator'), findsOneWidget);
    expect(find.text('Claim 20 XP'), findsNothing);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.text('Creator'));
    await tester.pumpAndSettle();
    expect(usersApi.claimedId, 3);

    // Claiming the first milestone advances this track to its next unclaimed
    // tier without moving through other achievement categories.
    expect(find.text('Collector'), findsOneWidget);
    expect(find.text('3/40'), findsOneWidget);
    expect(find.text('Keep going to unlock this reward'), findsNothing);

    await tester.fling(find.text('Collector'), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Veteran').first, findsOneWidget);
    expect(find.text('Restore badge'), findsNothing);
  });
}

class _RecordingUsersApi extends UsersApi {
  int? claimedId;

  @override
  Future<void> claimUserAchievement(String userId, int achievementId) async {
    claimedId = achievementId;
  }
}

class _TestAchievements extends Achievements {
  @override
  Future<List<UserAchievementsDtoInner>> build() => Future.value([
    UserAchievementsDtoInner(
      achievementId: 3,
      name: 'Creator',
      description: 'Add two sticks.',
      track: 'sticks',
      difficulty: 'easy',
      rewardType: UserAchievementsDtoInnerRewardTypeEnum.xp,
      rewardXp: 20,
      claimable: true,
      definitionVersion: 6,
      claimed: false,
      thresholdValue: 2,
      currentValue: 2,
      thresholdUp: true,
    ),
    UserAchievementsDtoInner(
      achievementId: 9,
      name: 'Collector',
      description: 'Add forty sticks.',
      claimed: false,
      track: 'sticks',
      difficulty: 'medium',
      rewardType: UserAchievementsDtoInnerRewardTypeEnum.color,
      rewardColor: '#FF26A69A',
      thresholdValue: 40,
      currentValue: 3,
      thresholdUp: true,
    ),
    UserAchievementsDtoInner(
      achievementId: 12,
      name: 'Veteran',
      description: 'Add two hundred sticks.',
      track: 'sticks',
      difficulty: 'hard',
      rewardType: UserAchievementsDtoInnerRewardTypeEnum.badge,
      claimable: true,
      rewardAvailable: false,
      definitionVersion: 6,
      claimed: false,
      thresholdValue: 200,
      currentValue: 200,
      thresholdUp: true,
    ),
    UserAchievementsDtoInner(
      achievementId: 24,
      name: 'Fresh perspective',
      description: 'Add a photo update to a stick.',
      track: 'updates',
      difficulty: 'easy',
      rewardType: UserAchievementsDtoInnerRewardTypeEnum.xp,
      claimed: false,
      rewardXp: 20,
      claimable: true,
      thresholdValue: 1,
      currentValue: 1,
      thresholdUp: true,
    ),
    UserAchievementsDtoInner(
      achievementId: 27,
      name: 'Good catch',
      description: 'Mark a stick as gone.',
      track: 'gone_pins',
      difficulty: 'easy',
      rewardType: UserAchievementsDtoInnerRewardTypeEnum.xp,
      claimed: false,
      rewardXp: 20,
      thresholdValue: 1,
      currentValue: 0,
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
  Future<UserLikesDto> build(String userId) async => UserLikesDto(likeCount: 0);
}

class _EmptyUserGroupService extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}

class _ProfilePinImageRepository implements IImageRepository {
  @override
  ImageType get type => ImageType.pin;

  @override
  Future<Uint8List?> fetchImage(
    String id,
    bool keepAlive, {
    ImageRequestPriority priority = ImageRequestPriority.foreground,
    ImageRequestCancellation? cancellation,
  }) async => Uint8List.fromList(kTransparentImage);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
