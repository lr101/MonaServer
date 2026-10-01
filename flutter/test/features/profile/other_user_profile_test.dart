import 'package:buff_lisa/data/database/account_session.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/like_service.dart';
import 'package:buff_lisa/data/service/pin_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/achievement/data/achievement_provider.dart';
import 'package:buff_lisa/features/profile/presentation/other_user_profile.dart';
import 'package:buff_lisa/features/progression/data/public_user_progression_provider.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

void main() {
  testWidgets('shows a public level ring and earned achievements', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountSessionProvider.overrideWithValue(AccountSession(true)),
          userIdProvider.overrideWithValue('viewer'),
          pinUserServiceProvider('alice').overrideWith(_EmptyPins.new),
          userLikeServiceProvider('alice').overrideWith(_EmptyLikes.new),
          userByIdUsernameProvider('alice')
              .overrideWith((ref) async => 'alice'),
          userByIdSelectedBatchProvider('alice')
              .overrideWith((ref) async => null),
          userByIdDescriptionProvider('alice')
              .overrideWith((ref) async => null),
          userByIdBestSeasonProvider('alice').overrideWith((ref) async => null),
          getUserProfileProvider('alice')
              .overrideWith((ref) => Stream.value(null)),
          publicUserProgressionProvider('alice').overrideWith(
            (ref) async => ProfileProgressionDto(level: 4, fraction: 0.6),
          ),
          publicUserAchievementsProvider('alice').overrideWith(
            (ref) async => [
              UserAchievementsDtoInner(
                achievementId: 4,
                name: 'Earned explorer',
                description: 'Add sticks in ten countries.',
                claimed: true,
                thresholdValue: 10,
                currentValue: 10,
                thresholdUp: true,
              ),
              UserAchievementsDtoInner(
                achievementId: 5,
                name: 'In progress',
                description: 'This progress stays private.',
                claimed: false,
                thresholdValue: 25,
                currentValue: 3,
                thresholdUp: true,
              ),
            ],
          ),
          defaultErrorImageProvider.overrideWithValue(kTransparentImage),
        ],
        child: const MaterialApp(home: OtherUserProfile(userId: 'alice')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lv 4'), findsOneWidget);
    expect(
      find.byTooltip('Level 4, 60% progress to next level'),
      findsOneWidget,
    );
    expect(find.text('Achievements'), findsOneWidget);

    await tester.tap(find.text('Achievements'));
    await tester.pumpAndSettle();

    expect(find.text('Earned explorer'), findsOneWidget);
    expect(find.text('In progress'), findsNothing);
    expect(find.text('Claim'), findsNothing);
  });
}

class _EmptyPins extends PinUserService {
  @override
  Stream<List<PinEntity>> build(String userId) => Stream.value([]);
}

class _EmptyLikes extends UserLikeService {
  @override
  Future<UserLikesDto> build(String userId) async => UserLikesDto(
    likeCount: 0,
    likeArtCount: 0,
    likeLocationCount: 0,
    likePhotographyCount: 0,
  );
}
