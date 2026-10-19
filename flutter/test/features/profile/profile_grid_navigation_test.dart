import 'dart:async';

import 'package:buff_lisa/data/entity/group_entity.dart';
import 'package:buff_lisa/data/entity/pin_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/group_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/like_service.dart';
import 'package:buff_lisa/data/service/pin_image_source.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/pin/data/pin_entries.dart';
import 'package:buff_lisa/features/profile/presentation/other_user_profile.dart';
import 'package:buff_lisa/features/profile/presentation/user_profile.dart';
import 'package:buff_lisa/features/progression/data/public_user_progression_provider.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/image_grid/presentation/square_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openapi/api.dart';
import 'package:transparent_image/transparent_image.dart';

import '../../support/pin_image_test_cache.dart';

void main() {
  late PinImageTestCache cache;
  setUp(() {
    cache = PinImageTestCache()..install();
  });
  tearDown(() async {
    await cache.dispose();
  });
  for (final ownProfile in [true, false]) {
    for (final kind in ['loading', 'thumbnail', 'photo thumbnail']) {
      testWidgets(
        '${ownProfile ? 'own' : 'other'} profile opens details for a $kind tile',
        (tester) async {
          final userId = ownProfile ? 'viewer' : 'alice';
          final photoId = kind == 'photo thumbnail' ? 'update-photo' : null;
          final entry = PinEntity(
            pinId: 'pin',
            latitude: 0,
            longitude: 0,
            creator: userId,
            creationDate: DateTime(2026),
            groupId: 'group',
            photoId: photoId,
            ttl: DateTime(2026),
            onlySession: true,
          );
          final router = GoRouter(
            initialLocation: '/profile',
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => ownProfile
                    ? const UserProfile()
                    : const OtherUserProfile(userId: 'alice'),
              ),
              GoRoute(
                name: 'viewImage',
                path: '/details/:id',
                builder: (context, state) => Scaffold(
                  body: Text(
                    'Details ${state.pathParameters['id']} ${state.uri.queryParameters['photo'] ?? 'original'}',
                  ),
                ),
              ),
              GoRoute(
                name: 'userImageFeed',
                path: '/feed/:id/:index',
                builder: (context, state) =>
                    const Scaffold(body: Text('User feed')),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                userIdProvider.overrideWithValue('viewer'),
                userPinEntriesProvider(userId)
                    .overrideWith((ref) => Stream.value([entry])),
                userLikeServiceProvider(userId).overrideWith(_EmptyLikes.new),
                userGroupServiceProvider.overrideWith(_EmptyGroups.new),
                currentUserProvider.overrideWith((ref) => null),
                userXpProvider('viewer').overrideWith((ref) => null),
                userByIdUsernameProvider(userId).overrideWith((ref) => userId),
                userByIdSelectedBatchProvider(userId)
                    .overrideWith((ref) => null),
                userByIdDescriptionProvider(userId).overrideWith((ref) => null),
                userByIdBestSeasonProvider(userId).overrideWith((ref) => null),
                publicUserProgressionProvider(userId)
                    .overrideWith((ref) => null),
                getUserProfileProgressiveProvider(userId)
                    .overrideWith((ref) => Stream.value(null)),
                pinImageSourceProvider.overrideWith(
                  (ref, request) => kind == 'loading'
                      ? Completer<PinImageSource?>().future
                      : const PinImageSource(
                          url: 'https://images.test/photo.png',
                          cacheKey: 'profile-photo',
                        ),
                ),
                defaultErrorImageProvider.overrideWithValue(kTransparentImage),
              ],
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          for (var i = 0; i < 10; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 200));
          }
          await tester.pump(const Duration(seconds: 11));
          await tester.tap(find.byType(SquareImage));
          await tester.pumpAndSettle();
          expect(
            find.text('Details pin ${photoId ?? 'original'}'),
            findsOneWidget,
          );
          expect(find.text('User feed'), findsNothing);
        },
      );
    }
  }
}

class _EmptyLikes extends UserLikeService {
  @override
  Future<UserLikesDto> build(String userId) async => UserLikesDto(likeCount: 0);
}

class _EmptyGroups extends UserGroupService {
  @override
  Stream<List<GroupEntity>> build() => Stream.value([]);
}
