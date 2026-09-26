import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:buff_lisa/data/entity/user_entity.dart';
import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/image_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:buff_lisa/features/progression/domain/xp_level_progress.dart';
import 'package:buff_lisa/features/progression/presentation/user_xp_card.dart';
import 'package:buff_lisa/widgets/custom_marker/data/default_group_image.dart';
import 'package:buff_lisa/widgets/group_selector/presentation/top_status_bar.dart';
import 'package:buff_lisa/widgets/group_selector/service/group_order_service.dart';
import 'package:buff_lisa/widgets/round_image/presentation/round_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

final Uint8List _avatarBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7+8l8AAAAASUVORK5CYII=',
);

void main() {
  testWidgets('status bar wraps the profile image with level progress', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(_statusBar());
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

    try {
      final levelProgressSemantics = find.semantics.byLabel(
        RegExp('Level 7, 200 XP into this level, 150 XP to next level'),
      );
      expect(levelProgressSemantics, findsOneWidget);
      expect(
        levelProgressSemantics.evaluate().single.getSemanticsData().hasAction(
          SemanticsAction.tap,
        ),
        isTrue,
      );
      expect(find.semantics.byLabel('Level 7 · 900 XP'), findsNothing);
      expect(find.semantics.byValue('57'), findsNothing);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('feed status bar keeps the compact XP indicator', (tester) async {
    await tester.pumpWidget(_statusBar(showProfileProgression: false));
    await tester.pumpAndSettle();

    expect(find.text('Lv 7'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('keeps the avatar visible while XP is loading', (tester) async {
    final pendingXp = Completer<UserXpDto?>();
    await tester.pumpWidget(
      _userXpAvatarPanel(loadProgression: () => pendingXp.future),
    );
    await tester.pump();

    expect(find.byType(RoundImage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    pendingXp.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(RoundImage), findsOneWidget);
  });

  testWidgets('keeps the avatar visible when no XP is returned', (
    tester,
  ) async {
    await tester.pumpWidget(
      _userXpAvatarPanel(loadProgression: () => Future<UserXpDto?>.value()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RoundImage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('keeps the avatar visible when the XP request fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _userXpAvatarPanel(
        loadProgression: () => Future.error(StateError('XP unavailable')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RoundImage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('skips ring animation when reduced motion is enabled', (
    tester,
  ) async {
    var progress = XpLevelProgress.fromValues(
      level: 1,
      totalXp: 20,
      currentLevelXp: 0,
      nextLevelXp: 100,
    );
    late StateSetter updateProgress;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: StatefulBuilder(
              builder: (context, setState) {
                updateProgress = setState;
                return UserXpAvatarIndicator(
                  progress: progress,
                  avatar: const CircleAvatar(radius: 17),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    updateProgress(() {
      progress = XpLevelProgress.fromValues(
        level: 1,
        totalXp: 80,
        currentLevelXp: 0,
        nextLevelXp: 100,
      );
    });
    await tester.pump();

    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, closeTo(0.8, 0.0001));
  });
}

Widget _statusBar({
  bool showProfileProgression = true,
  FutureOr<UserXpDto?> Function()? loadProgression,
}) {
  final getProgression =
      loadProgression ??
      () => UserXpDto(
        totalXp: 900,
        currentLevel: 7,
        currentLevelXp: 700,
        nextLevelXp: 1050,
      );

  return ProviderScope(
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
          .overrideWith((ref) => Stream.value(_avatarBytes)),
      userXpProvider('user-1').overrideWith((ref) => getProgression()),
      groupActiveServiceProvider.overrideWithValue([]),
      defaultErrorImageProvider.overrideWithValue(_avatarBytes),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 56,
            child: TopStatusBar(showProfileProgression: showProfileProgression),
          ),
        ),
      ),
    ),
  );
}

Widget _userXpAvatarPanel({
  required FutureOr<UserXpDto?> Function() loadProgression,
}) {
  return ProviderScope(
    overrides: [
      userIdProvider.overrideWithValue('user-1'),
      userXpProvider('user-1').overrideWith((ref) => loadProgression()),
      defaultErrorImageProvider.overrideWithValue(_avatarBytes),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: UserXpAvatarPanel(
          userId: 'user-1',
          imageCallback: AsyncValue.data(_avatarBytes),
        ),
      ),
    ),
  );
}
