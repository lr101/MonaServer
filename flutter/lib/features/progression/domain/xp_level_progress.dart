import 'package:flutter/foundation.dart';
import 'package:openapi/api.dart';

@immutable
class XpLevelProgress {
  const XpLevelProgress({
    required this.level,
    required this.totalXp,
    required this.xpIntoLevel,
    required this.xpToNextLevel,
    required this.fraction,
  });

  factory XpLevelProgress.fromDto(UserXpDto dto) {
    final levelSpan = dto.nextLevelXp - dto.currentLevelXp;
    final rawIntoLevel = dto.totalXp - dto.currentLevelXp;
    final xpIntoLevel = levelSpan <= 0 ? 0 : rawIntoLevel.clamp(0, levelSpan);
    final fraction = levelSpan <= 0 ? 1.0 : xpIntoLevel / levelSpan;
    final rawToNextLevel = dto.nextLevelXp - dto.totalXp;

    return XpLevelProgress(
      level: dto.currentLevel,
      totalXp: dto.totalXp,
      xpIntoLevel: xpIntoLevel,
      xpToNextLevel: rawToNextLevel <= 0 ? 0 : rawToNextLevel,
      fraction: fraction,
    );
  }

  final int level;
  final int totalXp;
  final int xpIntoLevel;
  final int xpToNextLevel;
  final double fraction;
}
