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
    return XpLevelProgress.fromValues(
      level: dto.currentLevel,
      totalXp: dto.totalXp,
      currentLevelXp: dto.currentLevelXp,
      nextLevelXp: dto.nextLevelXp,
    );
  }

  factory XpLevelProgress.fromGroupDto(GroupProgressionDto dto) {
    return XpLevelProgress.fromValues(
      level: dto.currentLevel,
      totalXp: dto.totalXp,
      currentLevelXp: dto.currentLevelXp,
      nextLevelXp: dto.nextLevelXp,
    );
  }

  factory XpLevelProgress.fromValues({
    required int level,
    required int totalXp,
    required int currentLevelXp,
    required int nextLevelXp,
  }) {
    final levelSpan = nextLevelXp - currentLevelXp;
    final rawIntoLevel = totalXp - currentLevelXp;
    final xpIntoLevel = levelSpan <= 0 ? 0 : rawIntoLevel.clamp(0, levelSpan);
    final fraction = levelSpan <= 0 ? 1.0 : xpIntoLevel / levelSpan;
    final rawToNextLevel = nextLevelXp - totalXp;

    return XpLevelProgress(
      level: level,
      totalXp: totalXp,
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
