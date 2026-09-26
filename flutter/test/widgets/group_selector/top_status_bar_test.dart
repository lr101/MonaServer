import 'dart:convert';

import 'package:buff_lisa/data/entity/user_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:buff_lisa/features/progression/presentation/user_xp_card.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/group_selector/presentation/top_status_bar.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  testWidgets('status bar wraps the profile image with level progress', (
    tester,
  ) async {
    final avatarBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7+8l8AAAAASUVORK5CYII=',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userIdProvider.overrideWithValue('user-1'),
          currentUserProvider.overrideWith(
            (ref) => UserEntity(
              userId: 'user-1',
              username: 'Explorer',
              ttl: DateTime.utc(2026),
              onlySession: true,
            ),
          ),
          getUserProfileSmallProvider('user-1')
              .overrideWith((ref) => Stream.value(avatarBytes)),
          userXpProvider('user-1').overrideWith(
            (ref) => UserXpDto(
              totalXp: 900,
              currentLevel: 7,
              currentLevelXp: 700,
              nextLevelXp: 1050,
            ),
          ),
          groupActiveServiceProvider.overrideWithValue([]),
          defaultErrorImageProvider.overrideWithValue(avatarBytes),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 360, height: 56, child: TopStatusBar()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Lv 7'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, closeTo(200 / 350, 0.0001));

    final avatarBounds = tester.getRect(find.byType(UserXpAvatarIndicator));
    final levelBounds = tester.getRect(find.text('7'));
    expect(levelBounds.center.dx, lessThan(avatarBounds.center.dx));
    expect(levelBounds.center.dy, greaterThan(avatarBounds.center.dy));
  });
}
