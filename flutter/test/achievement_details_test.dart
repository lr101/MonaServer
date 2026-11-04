import 'package:buff_lisa/features/achievement/presentation/achievement_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'compact milestone keeps description and collection available in details',
    (tester) async {
      var collected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementCard(
              title: 'Spark',
              description: 'Add two pins to your group.',
              currentValue: 2,
              thresholdValue: 2,
              progress: 1,
              claimed: false,
              claimable: true,
              rewardDescription: '10 group XP',
              onTap: () => collected++,
            ),
          ),
        ),
      );
      expect(find.text('Add two pins to your group.'), findsNothing);
      await tester.tap(find.byTooltip('About Spark'));
      await tester.pumpAndSettle();
      expect(find.text('Add two pins to your group.'), findsOneWidget);
      expect(find.text('Reward: 10 group XP'), findsOneWidget);
      await tester.tap(find.text('Collect reward'));
      await tester.pumpAndSettle();
      expect(collected, 1);
      expect(find.text('Add two pins to your group.'), findsNothing);
    },
  );
  testWidgets(
    'goal row opens details before collecting and explains its category',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var claims = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AchievementTrackScope(
              icon: Icons.photo_library_outlined,
              title: 'Photos',
              child: AchievementCard(
                title: 'Storyteller',
                description: 'Add ten photographs.',
                currentValue: 10,
                thresholdValue: 10,
                progress: 1,
                claimed: false,
                claimable: true,
                rewardDescription: '20 XP',
                onTap: () => claims++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Photos · 10 / 10'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSemantics(find.byType(AchievementCard))
            .getSemanticsData()
            .flagsCollection
            .isButton,
        true,
      );
      await tester.tap(find.text('Storyteller'));
      await tester.pumpAndSettle();
      expect(claims, 0);
      expect(find.text('Add ten photographs.'), findsOneWidget);
      await tester.tap(find.text('Collect reward'));
      await tester.pumpAndSettle();
      expect(claims, 1);
      semantics.dispose();
    },
  );
}
