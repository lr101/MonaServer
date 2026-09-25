import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/data/service/user_service.dart';
import 'package:buff_lisa/features/achievement/data/achievement_provider.dart';
import 'package:buff_lisa/features/achievement/presentation/achievement_page.dart';
import 'package:buff_lisa/features/progression/data/user_xp_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  testWidgets('groups milestones and falls back for an older server response', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userIdProvider.overrideWithValue('alice'),
          userXpProvider('alice').overrideWith((ref) => null),
          userByIdSelectedBatchProvider('alice').overrideWith((ref) => null),
          achievementsProvider.overrideWith(_TestAchievements.new),
        ],
        child: const MaterialApp(home: AchievementsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sticks'), findsOneWidget);
    expect(find.text('0/2 earned'), findsOneWidget);
    expect(find.text('First stick'), findsOneWidget);
    expect(find.text('Easy · 20 XP'), findsNWidgets(2));
    expect(find.text('Claim 20 XP'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Stick collector'),
      250,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Stick collector'), findsOneWidget);
    expect(find.text('3/10'), findsOneWidget);
    expect(find.text('Keep going to unlock this reward'), findsOneWidget);
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
  ]);
}
