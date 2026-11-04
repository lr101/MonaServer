import 'package:buff_lisa/features/achievement/presentation/achievement_track_browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Tier = ({String name, bool claimed, bool ready, double progress});

void main() {
  testWidgets(
    'ready and closest goals lead; full catalog retains future and collected tiers',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AchievementTrackBrowser<Tier>(
                tracks: const [
                  AchievementTrackData(
                    id: 'pins',
                    title: 'Pins',
                    tiers: [
                      (
                        name: 'Old pin tier',
                        claimed: true,
                        ready: false,
                        progress: 1,
                      ),
                      (
                        name: 'Next pin tier',
                        claimed: false,
                        ready: false,
                        progress: .8,
                      ),
                      (
                        name: 'Future pin tier',
                        claimed: false,
                        ready: true,
                        progress: .1,
                      ),
                    ],
                  ),
                  AchievementTrackData(
                    id: 'photos',
                    title: 'Photos',
                    tiers: [
                      (
                        name: 'Photo reward',
                        claimed: false,
                        ready: true,
                        progress: 1,
                      ),
                    ],
                  ),
                  AchievementTrackData(
                    id: 'members',
                    title: 'Members',
                    tiers: [
                      (
                        name: 'Distant goal',
                        claimed: false,
                        ready: false,
                        progress: .2,
                      ),
                    ],
                  ),
                  AchievementTrackData(
                    id: 'places',
                    title: 'Countries',
                    tiers: [
                      (
                        name: 'Collected goal',
                        claimed: true,
                        ready: false,
                        progress: 1,
                      ),
                    ],
                  ),
                ],
                isClaimed: (t) => t.claimed,
                isReady: (t) => t.ready,
                progress: (t) => t.progress,
                tierBuilder: (_, t) => Center(child: Text(t.name)),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.text('Photo reward')).dy,
        lessThan(tester.getTopLeft(find.text('Next pin tier')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Next pin tier')).dy,
        lessThan(tester.getTopLeft(find.text('Distant goal')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Distant goal')).dy,
        lessThan(tester.getTopLeft(find.text('Collected goal')).dy),
      );
      expect(find.text('Future pin tier'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Next up')).dy,
        lessThan(tester.getTopLeft(find.text('Next pin tier')).dy),
      );
      await tester.tap(find.text('All tiers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pins').last);
      await tester.pumpAndSettle();
      expect(find.text('Old pin tier'), findsOneWidget);
      expect(find.text('Future pin tier'), findsOneWidget);
      await tester.tap(find.byTooltip('All achievement tracks'));
      await tester.pumpAndSettle();
      expect(find.text('Future pin tier'), findsNothing);
      expect(find.text('Photo reward'), findsOneWidget);
    },
  );
}
