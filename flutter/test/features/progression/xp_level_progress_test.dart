import 'package:buff_lisa/features/progression/domain/xp_level_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openapi/api.dart';

void main() {
  group('XpLevelProgress', () {
    test('calculates progress within the current level', () {
      final progress = XpLevelProgress.fromDto(
        UserXpDto(
          totalXp: 900,
          currentLevel: 7,
          currentLevelXp: 700,
          nextLevelXp: 1050,
        ),
      );

      expect(progress.level, 7);
      expect(progress.totalXp, 900);
      expect(progress.xpIntoLevel, 200);
      expect(progress.xpToNextLevel, 150);
      expect(progress.fraction, closeTo(200 / 350, 0.0001));
    });

    test('treats the maximum level as complete', () {
      final progress = XpLevelProgress.fromDto(
        UserXpDto(
          totalXp: 14000,
          currentLevel: 15,
          currentLevelXp: 14000,
          nextLevelXp: 14000,
        ),
      );

      expect(progress.fraction, 1);
      expect(progress.xpToNextLevel, 0);
    });

    test('clamps inconsistent server progress to a safe range', () {
      final progress = XpLevelProgress.fromDto(
        UserXpDto(
          totalXp: 100,
          currentLevel: 2,
          currentLevelXp: 200,
          nextLevelXp: 300,
        ),
      );

      expect(progress.fraction, 0);
      expect(progress.xpIntoLevel, 0);
    });
  });
}
