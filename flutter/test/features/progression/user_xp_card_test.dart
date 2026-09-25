import 'package:buff_lisa/features/progression/presentation/user_xp_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  testWidgets('shows level, total XP, and progress to the next level', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserXpCard(
            xp: UserXpDto(
              totalXp: 900,
              currentLevel: 7,
              currentLevelXp: 700,
              nextLevelXp: 1050,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Level 7'), findsOneWidget);
    expect(find.text('900 XP'), findsOneWidget);
    expect(find.text('150 XP to next level'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('shows a complete bar at the level cap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserXpCard(
            xp: UserXpDto(
              totalXp: 14000,
              currentLevel: 15,
              currentLevelXp: 14000,
              nextLevelXp: 14000,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Maximum level'), findsOneWidget);
    expect(find.text('14,000 XP'), findsOneWidget);
  });

  testWidgets('animates the level bar when new XP arrives', (tester) async {
    var xp = UserXpDto(
      totalXp: 900,
      currentLevel: 7,
      currentLevelXp: 700,
      nextLevelXp: 1050,
    );
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return UserXpCard(xp: xp);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;

    update(() {
      xp = UserXpDto(
        totalXp: 1000,
        currentLevel: 7,
        currentLevelXp: 700,
        nextLevelXp: 1050,
      );
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 225));

    final during = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;
    expect(during, greaterThan(before));
    expect(during, lessThan(300 / 350));
  });

  testWidgets('compact indicator shows the level and progress bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompactUserLevelIndicator(
            xp: UserXpDto(
              totalXp: 900,
              currentLevel: 7,
              currentLevelXp: 700,
              nextLevelXp: 1050,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Lv 7'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('skips XP bar motion when reduced motion is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: UserXpCard(
              xp: UserXpDto(
                totalXp: 900,
                currentLevel: 7,
                currentLevelXp: 700,
                nextLevelXp: 1050,
              ),
            ),
          ),
        ),
      ),
    );

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(200 / 350, 0.0001));
  });
}
